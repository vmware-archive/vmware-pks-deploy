# pks-deploy

This is a project intended to document and automate the process required for a PKS + NSX-T deployment on vSphere.

Read
[Niran's step-by-step](https://onevmw-my.sharepoint.com/:w:/r/personal/nevenchen_vmware_com/_layouts/15/Doc.aspx?sourcedoc=%7B06F3406E-D0A2-42AE-9F5C-F35583D92EDF%7D&file=Deploy%20NSX-T%20with%20Concourse%20V1%2004-27-2018.docx&action=default&mobileredirect=true)
for a step-by-step manual deploy using some automation.

***Do not clone this repository.***
Instead, [install Google Repo](https://source.android.com/source/downloading#installing-repo).

Once you've installed Google Repo, you will use it to download and assemble all the component git repositories.

This process is as follows:

* create and/or change into a directory where you'd like to place all source relevant to this PKS deployment
* then execute the following

`repo init -u git@gitlab.eng.vmware.com:ps-emerging/pks-deploy-meta.git`

...followed by...

`repo sync`

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
  * deploy opsman
  * deploy PKS

## Bootstraping

### Bootstrap a VM into vSphere for running the deployment

We'll create a VM in vCenter that can be used to host Concourse, ansible, and any other tools needed to
run this deployment automation.

You can use an existing OVA for this vm or you can go into the [bootstrap directory](bootstrap/)
to create the VM directly in vCenter.
Continue to the [bootstrap directory](bootstrap/) and follow the README there.

## Ssh into the jumpbox

You should have the ip from the bootstrap step above.
If you set up ssh keys, you can ssh right now, otherwise use:

Username: `vmware`

Password: `VMware1!`

## Development

For development, you will clone this repository and submit MRs back to upstream.
This is intended to be used as a sub project pulled together by a meta-project.
You can get the full set of repositories by follow the prep section below.

## License

Copyright © 2018 VMware, Inc. All Rights Reserved.
SPDX-License-Identifier: MIT