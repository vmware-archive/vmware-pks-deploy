#!/bin/bash

# Pull in vars to setup various configurations
. vars

UPTODATE=
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

if [ -f /etc/os-release ]; then
    # freedesktop.org and systemd
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
    OS=$(uname -s)
    VER=$(uname -r)
fi

if [ "$OS" = "Ubuntu" ] && [ "$VER" = "16.04" ]; then
    # don't reinstall docker
    docker version >/dev/null 2>&1
    if [ $? -eq 1 ]; then
        apt-get update -qq
        apt-get install docker.io git golang-go
    fi
    UPTODATE=1
fi

# setup variables for packer-ova-concourse only if it's available
if [ -d ../../packer-ova-concourse ]; then

cat >../../packer-ova-concourse/govc_import_concourse_ova.json <<EOF
{
  "NetworkMapping": [
     {
         "Name": "Network 1",
         "Network": "${vsphere_network}"
     }
 ],
  "DiskProvisioning": "thin"
}
EOF

cat >../../packer-ova-concourse/variables.json <<EOF
{
  "bosh_stemcell_username": "${bosh_stemcell_username}",
  "bosh_stemcell_password": "${bosh_stemcell_password}",
  "vsphere_vm_name": "${vsphere_vm_name}",
  "vsphere_ip_address": "${vsphere_ip_address}",
  "vsphere_network": "${vsphere_network}",
  "vsphere_netmask": "${vsphere_netmask}",
  "vsphere_gateway": "${vsphere_gateway}",
  "vsphere_nameserver": "${vsphere_nameserver}",
  "vsphere_vcenter_server": "${vsphere_vcenter_server}",
  "vsphere_username": "${vsphere_username}",
  "vsphere_password": "${vsphere_password}",
  "vsphere_datacenter": "${vsphere_datacenter}",              
  "vsphere_cluster": "${vsphere_cluster}",
  "vsphere_datastore": "${vsphere_datastore}",
  "vsphere_resource_pool": "${vsphere_resource_pool}",
  "vsphere_folder": "${vsphere_folder}",
  "vsphere_insecure": "${vsphere_insecure}",
  "vm_username": "${vm_username}",
  "vm_password": "${vm_password}"
}
EOF

cat >../../packer-ova-concourse/govc_import_concourse_ova.json <<EOF
{
  "NetworkMapping": [
     {
         "Name": "Network 1",
         "Network": "${vsphere_network}"
     }
 ],
  "DiskProvisioning": "thin",
  "PropertyMapping": [
        {
            "Key": "ip0",
            "Value": "${vsphere_ip_address}"
        },
        {
            "Key": "netmask0",
            "Value": "${vsphere_netmask}"
        },
        {
            "Key": "gateway",
            "Value": "${vsphere_gateway}"
        },
        {
            "Key": "DNS",
            "Value": "${vsphere_nameserver}"
        },
        {
            "Key": "ntp_servers",
            "Value": "${vsphere_ntp_servers}"
        },
        {
            "Key": "admin_password",
            "Value": "${vsphere_password}"
        }
    ]
}
EOF

fi

if [ -z "${UPTODATE}" ]; then
    echo "OS not handled by this script.  Check dependencies manually"
fi
