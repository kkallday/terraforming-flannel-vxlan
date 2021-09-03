#!/bin/bash -exu

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
	echo "running http servers in namespaces..."
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

	ip netns exec $ns_1_name nohup python3 -m http.server 8000 &
	ip netns exec $ns_2_name nohup python3 -m http.server 8000 &
}

function main() {
	create_bridge_and_namespaces
	run_http_server_in_namespaces
}

main
