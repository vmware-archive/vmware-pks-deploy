#!/bin/bash

# first arg is the directory to put files
cd $1

# Where is the default minio config-folder
MINIO_CONFIG="~minio/.minio"

if [[ -z "$PIVNET_API_TOKEN" ]]; then
    echo "Must provide a Pivotal Network API_TOKEN in environment" 1>&2
    exit 1
fi

# This file is required to enable automatic download for vmware binaries
if [ -n "$MY_VMWARE_USER" ] && [ -n "$MY_VMWARE_PASSWORD" ]; then
  echo "Setup downloader config"
  echo '{ "username": "'$MY_VMWARE_USER'", "password": "'$MY_VMWARE_PASSWORD'"}' > config.json
fi

curl -L  -o VMware-ovftool-4.3.0-7948156-lin.x86_64.bundle "https://www.dropbox.com/s/n5pepfatetp55q2/VMware-ovftool-4.3.0-7948156-lin.x86_64.bundle?dl=1"

docker run -v ${PWD}:/vmwfiles apnex/myvmw
docker run -v ${PWD}:/vmwfiles apnex/myvmw "VMware Pivotal Container Service"
docker run -v ${PWD}:/vmwfiles apnex/myvmw get nsx-unified-appliance-2.1.0.0.0.7395503.ova
docker run -v ${PWD}:/vmwfiles apnex/myvmw get nsx-controller-2.1.0.0.0.7395493.ova
docker run -v ${PWD}:/vmwfiles apnex/myvmw get nsx-edge-2.1.0.0.0.7395502.ova

pivnet-cli login --api-token $PIVNET_API_TOKEN
pivnet-cli download-product-files -p ops-manager -r 2.1.5 -g '*vsphere*'
pivnet-cli download-product-files -p pivotal-container-service -r 1.0.4 -g '*pks-linux*'

# Set download permisions on the download directory
# This gyration is needed to to overcome testing problems with minio
# not getting set with the right credentials.
tmpdir=/tmp/$(mktemp -u XXXXXXXX)
mkdir -p ${tmpdir}
chmod 0755 ${tmpdir}
sudo su -c "cat ~minio/.minio/config.json >${tmpdir}/config.json.tmp"
sudo su -c "chmod 644 ${tmpdir}/config.json.tmp"
minio_accessKey=$(sudo su -c "jq -r .credential.accessKey ${tmpdir}/config.json.tmp")
minio_secretKey=$(sudo su -c "jq -r .credential.secretKey ${tmpdir}/config.json.tmp")
set | grep minio
mc --config-folder ${tmpdir} config host add local 'http://localhost:9091' "${minio_accessKey}" "${minio_secretKey}" S3v4
sudo su -c "chmod 0644 ${tmpdir}/config.json"
sudo su -c "chmod 0755 ${tmpdir}/certs"
mc --config-folder ${tmpdir} policy download local/${PWD##*/}
rm -rf ${tmpdir}
