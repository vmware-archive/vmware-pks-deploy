docker run  -v $PWD:/vmwfiles apnex/myvmw
docker run -v ${PWD}:/vmwfiles apnex/myvmw "VMware Pivotal Container Service"
docker run -v ${PWD}:/vmwfiles apnex/myvmw get nsx-unified-appliance-2.1.0.0.0.7395503.ova
docker run -v ${PWD}:/vmwfiles apnex/myvmw get nsx-controller-2.1.0.0.0.7395493.ova
docker run -v ${PWD}:/vmwfiles apnex/myvmw get nsx-edge-2.1.0.0.0.7395502.ova 
