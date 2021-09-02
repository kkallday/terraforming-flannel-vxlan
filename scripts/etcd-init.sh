#!/bin/bash -exu

function check_correct_machine() {
	echo "checking instance name..."
	if [ "$(hostname)" -ne "etcd" ]
		then echo "This script must be run on the etcd instance"
		exit 1
	fi
}

function check_sudo() {
	echo "checking sudo..."
        if [ "$EUID" -ne 0 ]
          then echo "Please run script as root"
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

function create_etcd_user() {
	echo "creating etcd user..."
        if id "etcd" &>/dev/null; then
                echo "etcd user already exists"
        else
                useradd etcd
        fi
}

function chown_data_dir() {
	echo "changing data dir owner to etcd user..."
	mkdir /var/lib/etcd
        chown etcd:etcd -R /var/lib/etcd
}

function write_etcd_systemd_service() {
	echo "writing etcd systemd service..."
        cat > /etc/systemd/system/etcd.service <<EOL
[Unit]
Description=etcd key-value store
Documentation=https://github.com/etcd-io/etcd
After=network-online.target local-fs.target remote-fs.target time-sync.target
Wants=network-online.target local-fs.target remote-fs.target time-sync.target

[Service]
User=etcd
Type=notify
Environment=ETCD_DATA_DIR=/var/lib/etcd
Environment=ETCD_NAME=node-1
Environment=ETCD_LISTEN_CLIENT_URLS=http://10.0.1.2:2379
Environment=ETCD_ADVERTISE_CLIENT_URLS=http://10.0.1.2:2379
Environment=ETCD_ENABLE_V2=true
ExecStart=/usr/local/bin/etcd
Restart=always
RestartSec=10s
LimitNOFILE=40000

[Install]
WantedBy=multi-user.target
EOL
        systemctl daemon-reload
}

function start_etcd_systemd_service() {
	echo "starting etcd..."
        systemctl restart etcd.service
}

function test_etcdctl() {
	echo "testing etcd..."
        ETCDCTL_API=2 etcdctl --endpoints=http://10.0.1.2:2379 set foo bar
        ETCDCTL_API=2 etcdctl --endpoints=http://10.0.1.2:2379 get foo
}

function main () {
	check_correct_machine
        check_sudo
        install_etcd
        create_etcd_user
        chown_data_dir
        write_etcd_systemd_service
        start_etcd_systemd_service
        test_etcdctl
}

main
