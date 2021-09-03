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
	else
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

function main () {
        check_correct_machine
        check_sudo
        install_flannel
        install_etcd
        write_flanneld_subnet_config_to_etcd
        write_flanneld_systemd_service
        start_flanneld_systemd_service
}

main
