#!/bin/bash

curl -L  -o VMware-ovftool-4.3.0-7948156-lin.x86_64.bundle "https://www.dropbox.com/s/n5pepfatetp55q2/VMware-ovftool-4.3.0-7948156-lin.x86_64.bundle?dl=1"

docker run  -v $PWD:/vmwfiles apnex/myvmw
docker run -v ${PWD}:/vmwfiles apnex/myvmw "VMware Pivotal Container Service"
docker run -v ${PWD}:/vmwfiles apnex/myvmw get nsx-unified-appliance-2.1.0.0.0.7395503.ova
docker run -v ${PWD}:/vmwfiles apnex/myvmw get nsx-controller-2.1.0.0.0.7395493.ova
docker run -v ${PWD}:/vmwfiles apnex/myvmw get nsx-edge-2.1.0.0.0.7395502.ova

curl -L -o /usr/local/bin/pivnet-cli https://github.com/pivotal-cf/pivnet-cli/releases/download/v0.0.51/pivnet-linux-amd64-0.0.51
chmod +x /usr/local/bin/pivnet-cli

if [[ -z "$API_TOKEN" ]]; then
    echo "Must provide a Pivotal Network API_TOKEN in environment" 1>&2
    exit 1
fi
/usr/local/bin/pivnet-cli login --api-token $API_TOKEN
/usr/local/bin/pivnet-cli download-product-files -p ops-manager -r 2.1.5 -g '*vsphere*'
