#!/bin/bash -exu

function check_correct_machine() {
        echo "checking instance name..."
        local host="$(hostname)"
        if [[ "${host}" != "cell-1" ]] && [[ "${host}" != "cell-2" ]]; then
                echo "ERROR: This script must be run on either the cell-1 or cell-2 instance"
                exit 1
        fi
}

function check_sudo() {
        echo "checking sudo..."
        if [ "$EUID" -ne 0 ]
          then echo "ERROR: Please run script as root"
          exit 1
        fi
}

function install_etcd () {
	local bin_dir=/usr/local/bin/
	if [[ ! -f ${bin_dir}/etcd || ! -f ${bin_dir}/etcdctl ]]; then
		echo "installing etcd..."
		local etcd_ver=v3.5.0

		local download_url=https://storage.googleapis.com/etcd

		rm -f /tmp/etcd-${etcd_ver}-linux-amd64.tar.gz
		rm -rf /tmp/etcd-download-test && mkdir -p /tmp/etcd-download-test

		curl -L ${download_url}/${etcd_ver}/etcd-${etcd_ver}-linux-amd64.tar.gz -o /tmp/etcd-${etcd_ver}-linux-amd64.tar.gz
		tar xzvf /tmp/etcd-${etcd_ver}-linux-amd64.tar.gz -C /tmp/etcd-download-test --strip-components=1
		rm -f /tmp/etcd-${etcd_ver}-linux-amd64.tar.gz


		mv /tmp/etcd-download-test/etcd ${bin_dir}/etcd
		mv /tmp/etcd-download-test/etcdctl ${bin_dir}etcdctl
		mv /tmp/etcd-download-test/etcdutl ${bin_dir}/etcdutl

		chmod u+x ${bin_dir}/etcd
		chmod u+x ${bin_dir}/etcdctl
		chmod u+x ${bin_dir}/etcdutl


		echo "etcd binaries versions..."
		etcd --version
		etcdctl version
		etcdutl version
	elif
		echo "etcd found. skipping installation..."
	fi
}

function install_flannel () {
        echo "installing flannel..."
        wget https://github.com/flannel-io/flannel/releases/download/v0.14.0/flanneld-amd64
        mv flanneld-amd64 /usr/local/bin/flanneld
        chmod u+x /usr/local/bin/flanneld
}

function write_flanneld_systemd_service() {
        echo "writing flanneld systemd service..."
        local instance_name="$(hostname)"

        cat > /etc/systemd/system/flanneld.service <<EOL
[Unit]
Description=flannel

[Service]
Type=notify
Environment=FLANNELD_ETCD_ENDPOINTS=http://10.0.1.2:2379
Environment=FLANNELD_V=1
Environment=FLANNELD_HEALTHZ_PORT=8090
ExecStart=/usr/local/bin/flanneld
LimitNOFILE=40000
EOL
        if [[ "${instance_name}" = "cell-1" ]]; then
                echo "Environment=FLANNELD_PUBLIC_IP=10.0.1.3" >> /etc/systemd/system/flanneld.service
        elif [[ "${instance_name}" = "cell-2" ]]; then
                echo "Environment=FLANNELD_PUBLIC_IP=10.0.2.3" >> /etc/systemd/system/flanneld.service
        else
                echo "ERROR: Could not determine which node in order to write flanneld systemd unit"
                exit 1
        fi

        systemctl daemon-reload
}

function write_flanneld_subnet_config_to_etcd() {
        echo "writing flanneld config to etcd..."
	cat << EOF > /flanneld-config.json
{
        "Network": "172.16.0.0/16",
        "SubnetLen": 24,
        "SubnetMin": "172.16.10.0",
        "SubnetMax": "172.16.99.0",
        "Backend": {
                "Type": "vxlan",
                "Port": 8472
        }
}
EOF

	ETCDCTL_API=2 etcdctl --endpoints=http://10.0.1.2:2379 set /coreos.com/network/config "$(cat /flanneld-config.json)"
}

function start_flanneld_systemd_service() {
        echo "starting flanneld..."
        systemctl restart flanneld.service
}

function create_bridge_and_namespaces() {
        echo "creating bridge and namespaces..."
        local instance_name="$(hostname)"
        if [[ "${instance_name}" = "cell-1" ]]; then
                local node_ip="10.0.1.3"
                local ns_1_name="con_a"
                local ns_2_name="con_b"
        elif [[ "${instance_name}" = "cell-2" ]]; then
                local node_ip="10.0.2.3"
                local ns_1_name="con_c"
                local ns_2_name="con_d"
        else
                echo "ERROR: Could not determine which node in order to create bridge and namespaces"
                exit 1
        fi

        local subnet=$(cat /run/flannel/subnet.env | grep FLANNEL_SUBNET= | sed 's/FLANNEL_SUBNET=//g')
        local bridge_ip="$(echo ${subnet} | sed 's/\/24//g')"
        local ns_1_ip="$(echo ${subnet} | sed 's/1\/24/2/g')"
        local ns_2_ip="$(echo ${subnet} | sed 's/1\/24/3/g')"


        # Adapted from https://github.com/kristenjacobs/container-networking/tree/master/4-overlay-network

        echo "Creating the namespaces"
        sudo ip netns add $ns_1_name
        sudo ip netns add $ns_2_name

        echo "Creating the veth pairs"
        sudo ip link add veth10 type veth peer name veth11
        sudo ip link add veth20 type veth peer name veth21

        echo "Adding the veth pairs to the namespaces"
        sudo ip link set veth11 netns $ns_1_name
        sudo ip link set veth21 netns $ns_2_name

        echo "Configuring the interfaces in the network namespaces with IP address"
        sudo ip netns exec $ns_1_name ip addr add $ns_1_ip/24 dev veth11
        sudo ip netns exec $ns_2_name ip addr add $ns_2_ip/24 dev veth21

        echo "Enabling the interfaces inside the network namespaces"
        sudo ip netns exec $ns_1_name ip link set dev veth11 up
        sudo ip netns exec $ns_2_name ip link set dev veth21 up

        echo "Creating the bridge"
        sudo ip link add name br0 type bridge

        echo "Adding the network namespaces interfaces to the bridge"
        sudo ip link set dev veth10 master br0
        sudo ip link set dev veth20 master br0

        echo "Assigning the IP address to the bridge"
        sudo ip addr add $bridge_ip/24 dev br0

        echo "Enabling the bridge"
        sudo ip link set dev br0 up

        echo "Enabling the interfaces connected to the bridge"
        sudo ip link set dev veth10 up
        sudo ip link set dev veth20 up

        echo "Setting the loopback interfaces in the network namespaces"
        sudo ip netns exec $ns_1_name ip link set lo up
        sudo ip netns exec $ns_2_name ip link set lo up

        echo "Setting the default route in the network namespaces"
        sudo ip netns exec $ns_1_name ip route add default via $bridge_ip dev veth11
        sudo ip netns exec $ns_2_name ip route add default via $bridge_ip dev veth21

        echo "Enables IP forwarding on the node"
        sudo sysctl -w net.ipv4.ip_forward=1

        echo "Disables reverse path filtering"
        sudo bash -c 'echo 0 > /proc/sys/net/ipv4/conf/all/rp_filter'
        sudo bash -c 'echo 0 > /proc/sys/net/ipv4/conf/ens4/rp_filter'
        sudo bash -c 'echo 0 > /proc/sys/net/ipv4/conf/br0/rp_filter'

}

function run_http_server_in_namespaces() {
        local instance_name="$(hostname)"
        if [[ "${instance_name}" = "cell-1" ]]; then
                local ns_1_name="con_a"
                local ns_2_name="con_b"
        elif [[ "${instance_name}" = "cell-2" ]]; then
                local ns_1_name="con_c"
                local ns_2_name="con_d"
        else
                echo "ERROR: Could not determine which node in order to create bridge and namespaces"
                exit 1
        fi

	set +e
	ip netns exec $ns_1_name pkill python3
	ip netns exec $ns_2_name pkill python3
	set -e

	ip netns exec $ns_1_name python3 -m http.server 8000 &
	ip netns exec $ns_2_name python3 -m http.server 8000 &
}

function main () {
        check_correct_machine
        check_sudo
        install_flannel
        install_etcd
        write_flanneld_subnet_config_to_etcd
        write_flanneld_systemd_service
        start_flanneld_systemd_service
        create_bridge_and_namespaces
	run_http_server_in_namespaces
}

main
