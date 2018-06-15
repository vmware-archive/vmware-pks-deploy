# pks-deploy

This is a project intended to document and automate the process required for a PKS + NSX-T deployment on vSphere.

Read
[Niran's step-by-step NSX-T deploy](https://onevmw-my.sharepoint.com/:w:/r/personal/nevenchen_vmware_com/_layouts/15/Doc.aspx?sourcedoc=%7B06F3406E-D0A2-42AE-9F5C-F35583D92EDF%7D&file=Deploy%20NSX-T%20with%20Concourse%20V1%2004-27-2018.docx&action=default&mobileredirect=true)
for a step-by-step manual deploy using some automation.


## End-to-end PKS Deploy

The overall process for a full PKS deployment is

* Use the PoC [Planning Reference](https://vault.vmware.com/group/vault-main-library/document-preview?fileId=38127906) document to vet the planned deployment
* Use the [PKS Configuration Worksheet](https://vault.vmware.com/group/vault-main-library/document-preview?fileId=38127882) to identify and track needed configuration
* Starting with a new vcenter, or a new cluster in an existing vcenter
* Bootstrap: Deploy a jump box
  * install concourse
  * download and host needed binaries
* Use a default configuration or create a new configuration
* Apply pipelines + configuration for the following in concourse:
  * deploy nsx-t
  * deploy PKS

## Get the code

***Do not clone this repository.***
Instead, [install Google Repo](https://source.android.com/source/downloading#installing-repo).

Once you've installed Google Repo, you will use it to download and assemble all the component git repositories.

This process is as follows:

``` bash
mkdir pks-deploy-testing
cd pks-deploy-testing
repo init -u http://gitlab.eng.vmware.com/ps-emerging/pks-deploy-meta.git
# you will need to enter gitlab credentials here
repo sync
```

After pulling down all the code as described above, go into `pks-deploy-testing`
and you'll see there are several directories.  These are each a git repository.

We'll focus on the `pks-deploy` repository.

## Bootstraping

Go into `pks-deploy/bootstrap`.
This directory contains code that will create a VM in vCenter, install Concourse, ansible, and other tools into that VM.

You can use an existing OVA captured after doing this process once, or you can go into the [bootstrap directory](bootstrap/)
and follow the readme there to create the VM directly in vCenter.

This should take about 15 minutes.

## Ssh into the jumpbox

Get the ip of the vm created in the bootstrap step above.
If you set up ssh keys, you can ssh right now, otherwise use:

* Username: `vmware`
* Password: `VMware1!`

On the jumpbox, there is also a copy of the source you used to bootstrap at `/home/vmware/deployroot`.

### Download VMware bits

Go into the jumpbox directory `/home/vmware/deployroot/pks-deploy/downloads`, and follow the readme there to pull needed bits from http://my.vmware.com.
You can see an online version here: [downloads](downloads)

These files will be hosted via nginx after they download at `http://jumpbox-ip`.

**TODO** still need to pull down pivotal files

### Apply various pipelines

On the jumpbox, the pipelines exist at `/home/vmware/deployroot` and concourse is running on `http://jumpbox-ip:8080` with the same credentials as ssh to log in.
You can use fly from the jumpbox to apply the pipelines. To log in try `fly --target main login -c http://localhost:8080`

#### Install NSX-T

cd `/home/vmware/deployroot/nsx-t-gen` and follow the guide from [sparameswaran/nsx-t-gen](https://github.com/sparameswaran/nsx-t-gen).

Anther good guide is [from Sabha](http://allthingsmdw.blogspot.com/2018/05/introducing-nsx-t-gen-automating-nsx-t.html)

A sample config file is at `/home/vmware/deployroot/deploy-params/one-cloud-param.yaml` on the jumpbox, or [live here](https://github.com/NiranEC77/NSX-T-Concourse-Pipeline-Onecloud-param/blob/master/one-cloud-param.yaml).

There is also good coverage of the config file needed in Niran's guide from above starting in section 4.b.

Once you have the config file correct:

``` bash
cd /home/vmware/deployroot/nsx-t-gen
fly --target main login -c http://localhost:8080 -u vmware -p 'VMware1!'
fly -t main set-pipeline -p deploy-nsx -c pipelines/nsx-t-install.yml -l ../pks-deploy/one-cloud-nsxt-param.yaml
fly -t main unpause-pipeline -p deploy-nsx
```

#### Install PAS and/or PKS

cd `/home/vmware/deployroot/nsx-t-ci-pipeline` and follow the guide from [sparameswaran/nsx-t-ci-pipeline](https://github.com/sparameswaran/nsx-t-ci-pipeline)

In particular, [this is the pipeline](https://github.com/sparameswaran/nsx-t-ci-pipeline/blob/master/pipelines/install-pks-pipeline.yml) and here is [a sample param file](https://github.com/sparameswaran/nsx-t-ci-pipeline/blob/master/pipelines/pks-params.sample.yml).

``` bash
cd /home/vmware/deployroot/nsx-t-ci-pipeline
fly --target main login -c http://localhost:8080 -u vmware -p 'VMware1!'
fly -t main set-pipeline -p deploy-pks -c pipelines/install-pks-pipeline.yml -l ../pks-deploy/pks-params.sample.yml
fly -t main unpause-pipeline -p deploy-pks
```

## Development

For development, you will clone this repository and submit MRs back to upstream.
This is intended to be used as a sub project pulled together by a meta-project.
You can get the full set of repositories by follow the prep section below.

## License

Copyright © 2018 VMware, Inc. All Rights Reserved.
SPDX-License-Identifier: MIT