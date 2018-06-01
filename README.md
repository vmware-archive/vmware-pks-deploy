# pks-deploy

This is a project intended to document and automate the process required for a PKS + NSX-T deployment on vSphere.

## Development

For development, you will clone this repository and submit MRs back to upstream.

## Using this for a Deployment

### Preperation

** Do not clone this repository.** 

Instead, [install Git Repo](https://source.android.com/source/downloading#installing-repo).

Once you've installed Git Repo, you will use it to download and assemble all the component git repositories.

This processis as follows:

* create and/or change into a directory where you'd like to place all source relevant to this PKS deployment
* then execute the following

`repo init -u git@gitlab.eng.vmware.com:ps-emerging/pks-deploy-meta.git`

...followed by...

`repo sync`

### Configuration

### Bootstrap a VM into vSphere for running the deployment

## License

Copyright © 2018 VMware, Inc. All Rights Reserved.
SPDX-License-Identifier: MIT