#!/bin/bash

# Create the machines
array=( manager1 worker1 worker2 worker3 )
for machine in "${array[@]}"
do
  docker-machine create -d virtualbox --engine-storage-driver overlay2   --virtualbox-memory "1024" --virtualbox-hostonly-nictype Am79C973 --virtualbox-cpu-count "1" $machine
done

# Get the IP address of the Manager node
MANAGER_IP="$(docker-machine ip manager1)"

# Initialize the swarm on the manager
docker-machine ssh manager1 docker swarm init --advertise-addr $MANAGER_IP:2377

# Get the join token from the manager
WORKER_JOIN_TOKEN=$(docker-machine ssh manager1 docker swarm  join-token worker -q)

# Join each worker to the swarm
array=( worker1 worker2 worker3 )
for machine in "${array[@]}"
do
  docker-machine ssh $machine docker swarm join --token $WORKER_JOIN_TOKEN $MANAGER_IP:2377
 $machine
done

# Prepare to send a docker command to the manager from the local CLI
eval $(docker-machine env manager1)

# Deploy the vault stack
docker stack deploy vault
