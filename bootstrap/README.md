# Bootstrap a control host

We want to stand up a simple VM on which to

* run ansible playbooks
* install and run Concourse
* download and host binaries to install into vSphere and other VMs

We'll enable standing this VM up, and capturing it as an OFV for a pre-packaged VM

## Requirements

* A machine that you control that has:
  * bash
  * docker
  * a vCenter to which this machine can connect
  * ovftool (optional: only needed if you need to capture an OVF after bootstrapping)
* DHCP for the network the bootstrap VM will be created on
* a default resource pool into which we will install the bootstrap VM

## Preparation

You may be able to run the ```prep.sh``` script to get ready to build the
bootstrap docker container.

``` bash
./prep.sh
```

### user-data (optional)

Edit [user-data.yml](./user-data.yml) to add your ssh key if desired.  There is a default
user/password set in case you don't do this step.

Your local ssh key should already be registered with your github account. Grab your ssh key from:

``` bash
cat ~/.ssh/id_rsa.pub
```

Put that key text in [user-data.yml](./user-data.yml) under the `ssh-authorized-keys` with a leading `- ` just like the other line in that section.

### Create a conainer image with needed tools

This step allows you to avoid needing to install a bunch of tools locally to get going.  Just have docker.

``` bash
docker build -t bootstrap .
```

## Deploy the Bootstrap host

In the bootstrap image, there exists a script that will create a VM in vCenter, and run some provisioning in the VM.
We will later use this VM to run the full PKS and NSX-T deploy.  The command below will result in this VM configured and running in vCenter.

There are several parameters you can pass in to this provisioning step:

* `VM_NAME`: this is what the bootstrap VM will be named (default is 'pks-bootstrapper')
* `GOVC_NETWORK`: What network the VM should be placed on (default is 'VM Network')
* `GOVC_PASSWORD`: administrator password
* `GOVC_INSECURE`: allow skipping SSL verification (default is '1' for true)
* `GOVC_URL`: the url used to connect to vcenter
* `GOVC_DATACENTER`: datacenter in which to place the VM (default is 'Goddard')
* `GOVC_DATASTORE`: datastore in which to place the VM (default is 'vms')
* `GOVC_USERNAME`: administrator username (default is 'administrator@vsphere.local')
* `GOVC_RESOURCE_POOL`: resource pool in which to place the VM (default is none)
* `MY_VMWARE_USER`: Username used to log into my.vmware.com when downloading binaries, no default
* `MY_VMWARE_PASSWORD`: Password used to log into my.vmware.com when downloading bin, no default
* `PIVNET_API_TOKEN`: API token for network.pivotal.io for downloading binaries, no default

You can edit [docker-env](./docker-env) in this directory to reflect your environment.  This is passed in to the provisioning process in the following command:

``` bash
# for debugging purposes, this may be better:
docker run -it --env-file docker-env -v $PWD/../..:/deployroot --entrypoint /bin/bash bootstrap
bash-4.4# ./entrypoint.sh
# and if failures happen... you can re-run
bash-4.4# ./entrypoint.sh

# For a one-shot run, try:
docker run -it --env-file docker-env -v $PWD/../..:/deployroot bootstrap
```

After this completes, you should have a VM in the vCenter named after your `$VM_NAME`.

``` bash
# Debugging note: you can pass additional arguments to the entrypoint.sh to
# target an existing VM for more interactive debugging.
# -a <address> for existing VM, -u <user>, -d <deployroot>
# E.g.
./entrypoint.sh -a concourse-bootstrapper -u gardnerj -d ../../my_deployroot
```


## Capture an ovf

You can capture an ovf from the bootstrapped VM for future deploys without waiting for the bootstrap process to download and configure everything.

``` bash
govc vm.power -off pks-bootstrapper
govc export.ovf -vm pks-bootstrapper .
ovftool pks-bootstrapper/pks-bootstrapper.ovf baked-pks-deploy.ova
```

## Destroy the Bootstrap host

This will power off and remove the VM from vCenter.

`govc vm.destroy pks-bootstrapper`
