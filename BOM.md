# Bill of materials

These are all the things we must have to be able to do an NSX-T/PKS automated deployment:

* VMware binaries
  * nsx-edge-2.1.0.0.0.7395502.ova
  * nsx-unified-appliance-2.1.0.0.0.7395503.ova
  * nsx-controller-2.1.0.0.0.7395493.ova
  * VMware-ovftool-4.3.0-7948156-lin.x86_64.bundle
* Pivotal pivnet binaries
  * pcf-vsphere-2.1-build.318.ova
  * pks-linux-amd64-1.0.4-build.1
* Container images in s3
  * ???
* Services
  * S3 support on the concourse host (Minio)
  * Concourse
* tools
  * fly CLI
  * pivnet CLI
  * ovftool
  * govc
  