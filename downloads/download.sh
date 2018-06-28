#!/bin/bash

curl -L  -o VMware-ovftool-4.3.0-7948156-lin.x86_64.bundle "https://www.dropbox.com/s/n5pepfatetp55q2/VMware-ovftool-4.3.0-7948156-lin.x86_64.bundle?dl=1"

docker run -v ${PWD}:/vmwfiles apnex/myvmw
docker run -v ${PWD}:/vmwfiles apnex/myvmw "VMware Pivotal Container Service"
docker run -v ${PWD}:/vmwfiles apnex/myvmw get nsx-unified-appliance-2.1.0.0.0.7395503.ova
docker run -v ${PWD}:/vmwfiles apnex/myvmw get nsx-controller-2.1.0.0.0.7395493.ova
docker run -v ${PWD}:/vmwfiles apnex/myvmw get nsx-edge-2.1.0.0.0.7395502.ova

if [[ -z "$API_TOKEN" ]]; then
    echo "Must provide a Pivotal Network API_TOKEN in environment" 1>&2
    exit 1
fi
pivnet-cli login --api-token $API_TOKEN
pivnet-cli download-product-files -p ops-manager -r 2.1.5 -g '*vsphere*'
pivnet-cli download-product-files -p pivotal-container-service -r 1.0.4 -g '*pks-linux*'
