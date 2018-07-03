#!/bin/sh -e

NAME=${NAME:='pks'}
if [ -f solution-name ]; then
  NAME=$(cat solution-name)
fi
export NAME
export VM_NAME=${VM_NAME:="${NAME}-bootstrapper"}
export GOVC_NETWORK=${GOVC_NETWORK:='VM Network'}
export GOVC_PASSWORD=${GOVC_PASSWORD:='VMware1!'}
export GOVC_INSECURE=${GOVC_INSECURE:='1'}
export GOVC_URL=${GOVC_URL:='vcenter.home.local'}
export GOVC_DATACENTER=${GOVC_DATACENTER:='Goddard'}
export GOVC_DATASTORE=${GOVC_DATASTORE:='vms'}
export GOVC_USERNAME=${GOVC_USERNAME:='administrator@vsphere.local'}
export GOVC_RESOURCE_POOL=${GOVC_RESOURCE_POOL:=''}
export MY_VMWARE_USER=${MY_VMWARE_USER:'none'}
export MY_VMWARE_PASSWORD=${MY_VMWARE_PASSWORD:'none'}
export PIVNET_API_TOKEN=${PIVNET_API_TOKEN:'none'}

exec "./bootstrap-vm.sh" "-q" $@
