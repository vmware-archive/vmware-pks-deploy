#!/bin/bash -e
# Copyright 2017 VMware, Inc. All Rights Reserved.
#
#
# Create (or reuse) a bootstrap ubuntu VM
# Requires ESX to be configured with:
# govc host.esxcli system settings advanced set -o /Net/GuestIPHack -i 1

set -o pipefail

vm="$VM_NAME"
network="$GOVC_NETWORK"
varsfile="../packer/vars/vsphere-template.json"
destroy=false
verbose=true
ova=xenial-server-cloudimg-amd64.ova

while getopts v:n:q flag
do
  case $flag in
    v)
      vm=$OPTARG
      unset destroy
      ;;
    n)
      network=$OPTARG
      unset destroy
      ;;
    q)
      verbose=false # you want this if generating lots of traffic, such as large file transfers
      ;;
    *)
      echo "unknown option" 1>&2
      exit 1
      ;;
  esac
done

keyfile=~/.ssh/id_rsa.pks-bootstrapper
if [ ! -f $keyfile ]; then
  echo "Generate and use a temporary key ssh..."
  ssh-keygen -f $keyfile -t rsa -N ''
fi
key=`cat ${keyfile}.pub`
sed -e "s:%%GENERATED_KEY%%:$key\n:" user-data.yml > user-data.edited.yml
userdata=`base64 user-data.edited.yml`

echo "Downloading ${ova}..."
if [ ! -e bootstrap.ova ] ; then
    curl https://cloud-images.ubuntu.com/xenial/current/$ova -o bootstrap.ova

    # use this to get the json spec for the ova, if it changes
    # govc import.spec $ova > ${ova}.json
fi

vm_path="$(govc find / -type m -name "$vm")"

if [ -z "$vm_path" ] ; then
  echo "Creating VM ${vm}..."
  jq -n --arg userdata "$userdata" --arg network "$network" -f bootstrap-spec.json > bootstrap-spec.edited.json
  govc import.ova -options=bootstrap-spec.edited.json -name=$vm bootstrap.ova
  govc vm.change -vm $vm -nested-hv-enabled=true
  govc vm.change -vm $vm -m=4096
  govc vm.disk.change -vm $vm -size 40G
  vm_path="$(govc find / -type m -name "$vm")"
else
  echo "VM ${vm} already exists"
fi

if [ -z "$vm_path" ] ; then
  echo "Failed to find the vm."
  exit 1
fi

state=$(govc object.collect -s "$vm_path" runtime.powerState)
if [ "$state" != "poweredOn" ]; then
    echo "Power on the VM"
    govc vm.power -on "$vm"
fi

echo -n "Waiting for ${vm} ip..."
ip=$(govc vm.ip "$vm")

echo "Got ip $ip"

opts=(-i $keyfile -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -o "LogLevel=ERROR")
rsyncopts=(-ra --delete -e 'ssh -i '$keyfile' -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -o "LogLevel=ERROR"')

echo -n "Wait until cloud-init finishes"
until ssh "${opts[@]}" vmware@$ip "grep 'runcmd done' /etc/cmds"; do
  echo -n "."
  sleep 5
done
echo "Done"

echo "Provision extras in the VM, may run several times to get convergence"
rsync "${rsyncopts[@]}" provision vmware@${ip}:
until ssh -t "${opts[@]}" vmware@$ip "cd provision; ansible-galaxy install -r external_roles.yml; ansible-playbook  -i inventory site.yml || (sudo shutdown -r +1 && false);" ; do
  echo -n "."
  sleep 5
done
echo "Done"

if [ -n "$MY_VMWARE_USER" ] && [ -n "$MY_VMWARE_PASSWORD" ]; then
  echo "Setup downloader config"
  echo '{ "username": "'$MY_VMWARE_USER'", "password": "'$MY_VMWARE_PASSWORD'"}' > /deployroot/pks-deploy/downloads/config.json
fi

echo "Copy code to the jumpbox"
rsync "${rsyncopts[@]}" /deployroot vmware@${ip}:
