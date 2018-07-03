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
bootstrap_name=${NAME:='pks'}
varsfile="../packer/vars/vsphere-template.json"
destroy=false
verbose=true
ova=xenial-server-cloudimg-amd64.ova
user=vmware
deployroot=/deployroot

# bootstrap vm traits
cpus="1"
memory="4096"
disk="40G"

while getopts d:v:n:a:u:q flag
do
  case $flag in
    d)
      # root directory of files to be coppied into the bootstrap box
      deployroot=$OPTARG
      ;;
    v)
      # vm name to use for the bootstrap box in vcenter
      vm=$OPTARG
      unset destroy
      ;;
    n)
      # network to connect the boostrap box to
      network=$OPTARG
      unset destroy
      ;;
    a)
      # address of an existing machine.
      # Setting this indicates that we should not create a new vm in vcenter.
      # This machine will only work if it is based on Ubuntu 16.04.
      ip=$OPTARG
      ;;
    u)
      # user name used to ssh into an existing machine
      # Setting this indicates that we should not create a new vm in vcenter.
      user=$OPTARG
      ;;
    q)
      # disable verbose output, don't prompt for input
      verbose=false
      ;;
    *)
      echo "unknown option" 1>&2
      exit 1
      ;;
  esac
done

# connectivity options
keyfile=~/.ssh/id_rsa.${vm}
opts=(-i $keyfile -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -o "LogLevel=ERROR")
rsyncopts=(-ra --delete -e 'ssh -i '$keyfile' -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -o "LogLevel=ERROR"')

# ansible extra vars
export ANSIBLE_HOST_KEY_CHECKING=False
exvars=(-e pivnet_api_token=$PIVNET_API_TOKEN -e my_vmware_user=$MY_VMWARE_USER -e "my_vmware_password='$MY_VMWARE_PASSWORD'")
exvars+=(-e ansible_ssh_private_key_file=$keyfile -e ansible_ssh_user=$user -e do_download=true)

if [ ! -f $keyfile ]; then
  echo "Optional $keyfile not found."
  echo "Generate and use a temporary key for ssh..."
  ssh-keygen -f $keyfile -t rsa -N ''
fi

function createvm
{
  echo "Creating a VM \"$vm\" to serve as bootstrap box."

  if [ "$verbose" == "true" ] ; then 
    echo "Ok to continue (ctl-c to quit)?"
    read answer
  fi

  key=`cat ${keyfile}.pub`
  sed -e "s:%%GENERATED_KEY%%:$key\n:" user-data.yml > user-data.edited.yml
  userdata=`base64 user-data.edited.yml`

  if [ ! -e bootstrap.ova ] ; then
      echo "Downloading ${ova}..."
      curl https://cloud-images.ubuntu.com/xenial/current/$ova -o bootstrap.ova

      # use this to get the json spec for the ova, if it changes
      # govc import.spec $ova > ${ova}.json
  else
    echo "${ova} already exists, skipping download"
  fi

  vm_path="$(govc find / -type m -name "$vm")"

  if [ -z "$vm_path" ] ; then
    echo "Creating VM ${vm}..."
    jq -n --arg userdata "$userdata" --arg network "$network" -f bootstrap-spec.json > bootstrap-spec.edited.json
    govc import.ova -options=bootstrap-spec.edited.json -name=$vm bootstrap.ova
    govc vm.change -vm $vm -nested-hv-enabled=true
    govc vm.change -vm $vm -m=${memory}
    govc vm.change -vm $vm -c=${cpus}
    govc vm.disk.change -vm $vm -size ${disk}
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

  echo -n "Wait until cloud-init finishes"
  until ssh "${opts[@]}" vmware@$ip "grep -q 'runcmd done' /etc/cmds"; do
    echo -n "."
    sleep 5
  done
  echo "Done"
}

if [ -z "$ip" ]; then
  createvm
fi

if [ -z "$ip" ]; then
  echo "Unable to get the vm's IP.  Unknown error."
fi

echo -n "Copy code to the bootstrap box..."
rsync "${rsyncopts[@]}" ${deployroot}/* ${user}@${ip}:deployroot
echo "Done"

# Allow additional customizations, anthing extra*.sh in this directory
for extra in extra*.sh; do
  [ -e "$extra" ] || continue
  echo -n "Performing extra host prep $extra..."
  source "./${extra}"
  echo "Done"
done

exvars+=("-e" "bootstrap_box_ip=$ip")

echo "Provisioning bootstrap box $vm at $ip."
cd provision
ansible-galaxy install -r external_roles.yml

retry=3
until [ $retry -le 0 ]; do 
  $verbose && echo ansible-playbook -i inventory ${exvars[@]} site.yml
  ansible-playbook -i inventory ${exvars[@]} site.yml && break
  retry=$(( retry - 1 ))
done

echo "Completed configuration of $vm with IP $ip"
