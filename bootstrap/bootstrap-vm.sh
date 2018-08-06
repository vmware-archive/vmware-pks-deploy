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
bootstrap_name=${NAME:='concourse'}
varsfile="../packer-ova-${bootstrap_name}/vars/vsphere-template.json"
destroy=false
verbose=true
ova=xenial-server-cloudimg-amd64.ova
user=vmware
deployroot=/deployroot
use_packer=0

# bootstrap vm traits
cpus="1"
memory="4096"
disk="40G"

function usage {
  echo "usage: $0 [-qh] [-d deployroot] [-a address] [-u user]"
  echo "  -a address     address of hostname of bootstrap box (VM won't be created)"
  echo "  -d deployroot  base directory to copy to the bootstrap box"
  echo "  -n network     network to which to connect the boostrap box"
  echo "  -u user        user to connect to the bootstrap box"
  echo "  -v vmname      name to assign to the VM"
  echo "  -c             copy files only, no provision (for refreshing pipeline)"
  echo "  -h             display help"
  echo "  -q             quiet mode, less output and no prompting"
  exit 1
}

while getopts :d:v:n:a:u:pqch flag
do
  case $flag in
    c)
      # Only copy files, no provision.
      copyonly=true
      ;;
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
    p)
      # use packer for provisioning
      use_packer=1
      ;;
    u)
      # user name used to ssh into an existing machine
      # Setting this indicates that we should not create a new vm in vcenter.
      user=$OPTARG
      ;;
    q)
      # disable verbose output, don't prompt for input
      unset verbose
      ;;
    h)
      usage
      exit 0
      ;;
    \? )
      echo "Unexpected argument."
      usage
      exit 1
      ;;
  esac
done

if [ -z "${use_packer}" -o ${use_packer} -ne 0 ]; then
  go build -o ../../packer-ova-concourse/software/parse-ova-linux ../../parse-ova-vm-setting/main.go
  if [ $? -ne 0 ]; then
    echo "ERROR: failed to build parse-ova-linux"
    exit 1
  fi
  docker run --env-file docker-env -v $PWD/../..:/deployroot bootstrap
else
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

  if [ $copyonly ]; then
    [ -z ${verbose+x} ] && echo "Skipping provision steps, all done."
    exit 0
  fi

  exvars+=(-e bootstrap_box_ip=${ip} -e solution_name=${bootstrap_name})
  exvars+=(-e deploy_user=${user} -e minio_group=${user})
  exvars+=(-e deployroot=${deployroot})

  echo "Provisioning bootstrap box $vm at $ip."
  cd provision
  ansible-galaxy install -r external_roles.yml
  if [ -f "additional_roles.yml" ]; then
    ansible-galaxy install -r additional_roles.yml
  fi

  retry=3
  until [ $retry -le 0 ]; do
    vees=""
    [ $verbose ] && vees="-vv"
    [ $verbose ] && echo ansible-playbook -i inventory ${exvars[@]} site.yml $vees
    ansible-playbook -i inventory ${exvars[@]} site.yml $vees && break
    retry=$(( retry - 1 ))
  done
fi

echo "Completed configuration of $vm with IP $ip"
