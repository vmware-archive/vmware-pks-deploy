# vmware-pks-deploy

[![Build Status](https://travis-ci.org/vmware/vmware-pks-deploy.svg?branch=master)](https://travis-ci.org/vmware/vmware-pks-deploy)

This is a project intended to document and automate the process required for a PKS + NSX-T deployment on vSphere.

## Extra documents

These documents are not public yet.  They are linked here for VMware internal users, but should be converted over time into publicly consumable documents.

* Read
[Niran's step-by-step NSX-T deploy](https://onevmw-my.sharepoint.com/:w:/r/personal/nevenchen_vmware_com/_layouts/15/Doc.aspx?sourcedoc=%7B06F3406E-D0A2-42AE-9F5C-F35583D92EDF%7D&file=Deploy%20NSX-T%20with%20Concourse%20V1%2004-27-2018.docx&action=default&mobileredirect=true)
for a step-by-step manual deploy using some automation
* Use the PoC [Planning Reference](https://vault.vmware.com/group/vault-main-library/document-preview?fileId=38127906) document to vet the planned deployment
* Use the [PKS Configuration Worksheet](https://vault.vmware.com/group/vault-main-library/document-preview?fileId=38127882) to identify and track needed configuration that must be captured as YAML for the pipelines to work properly

## High level end-to-end PKS deploment

The overall process for a PKS and NSX-T deployment is

* Start with a new vcenter, or a new cluster in an existing vcenter
* Deploy a PKS deployment server. This has Pivotal Concourse for running pipelines, and all the needed binaries and tools to do an automated deploy of PKS and NSX-T
* Use a default configuration YAML or create a new one for NSX-T and another for PKS. These describe what the final deployment will look like
* Apply the pipelines to your configuration
* Connect to the Concourse UI
* Trigger pipelines to:
  * deploy NSX-T
  * deploy PKS

To get the inital OVA, you must bootstrap.  That process looks is:

* Start with a machine with access to a vCenter
* Download this code as described below
* Create a container with tools needed to operate on vCenter
* Deploy a ubuntu 16.04 cloud image into vCenter
* Boot the stock VM using cloudinit to set usernames/passwords/ssh keys
* Run ansible playbooks against the VM to provision everything needed to make a deploy server, including:
  * install concourse
  * download and host needed binaries
  * host container images needed by concourse


At this point, you have two choices:

* export the VM as an OVA for a future deployment
* use the running VM to perform  a deploy now

Assuming you want to do these things, continue into the details of this process below:

## Get the code

***Do not clone this repository.***
Instead, [install Google Repo](https://source.android.com/source/downloading#installing-repo).

Here's a quick google repo install for the impatient.

```bash
# Validate python
python2.7 -c "print 'Python OK'" || echo 'Need python 2.7!'
python --version | grep "Python 2" || echo 'Warning: python 3 is default!'
mkdir ~/bin
PATH=~/bin:$PATH
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo
# If you get a warning that about python 3, you might run this:
# After repo is installed:
sed -ri "1s:/usr/bin/env python:/usr/bin/python2.7:" ~/bin/repo
```

Once you've installed Google Repo, you will use it to download and assemble all the component git repositories.

This process is as follows:

``` bash
mkdir pks-deploy-testing
cd pks-deploy-testing
repo init -u https://github.com/vmware/vmware-pks-deploy-meta.git
# or, with ssh: (you will have first had to register an SSH key with Github)
repo init -u git@github.com:vmware/vmware-pks-deploy-meta.git
# Then sync, which pulls down the code.
repo sync
```

After pulling down all the code as described above, go into `pks-deploy-testing`
and you'll see there are several directories.  These are each a git repository.

We'll focus on the `pks-deploy` repository.

## Bootstrapping

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

If you passed the following variables into the bootstrap process above,
the required binaries will be downloaded as part of the automation: `PIVNET_API_TOKEN`, `MY_VMWARE_USER`, and `MY_VMWARE_PASSWORD`.
If you did not pass those in, then you'll need to run this step manually as described below.

Go into the jumpbox directory `/home/vmware/deployroot/pks-deploy/downloads`,
and follow the readme there to pull needed bits from http://my.vmware.com and pivnet.
You can see an online version in [downloads](downloads).

The downloaded files will be hosted via s3 by minio and
can be accessed at `http://bootstrap-box-ip:9091`.

### Apply various pipelines

On the jumpbox, the pipelines exist at `/home/vmware/deployroot` and concourse is running on `http://jumpbox-ip:8080` with the same credentials as ssh to log in.
You can use fly from the jumpbox to apply the pipelines. To log in try `fly --target main login -c http://localhost:8080` and `fly pipelines --target main`

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

## Contributing

The vmware-pks-deploy project team welcomes contributions from the community. Before you start working with vmware-pks-deploy, please read our [Developer Certificate of Origin](https://cla.vmware.com/dco). All contributions to this repository must be signed as described on that page. Your signature certifies that you wrote the patch or have the right to pass it on as an open-source patch. For more detailed information, refer to [CONTRIBUTING.md](CONTRIBUTING.md).

### Development

For development, you will clone this repository and submit PRs back to upstream.
This is intended to be used as a sub project pulled together by a meta-project called [vmware-pks-deploy-meta](https://github.com/vmware/vmware-pks-deploy-meta).
You can get the full set of repositories by follow the prep section above.

## License

Copyright © 2018 VMware, Inc. All Rights Reserved.
SPDX-License-Identifier: MIT
