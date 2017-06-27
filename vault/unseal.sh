#!/bin/bash

key1=$1
key2=$2
key3=$3
key4=$4
key5=$5
root_token=$6

keys=( $key1 $key2 $key3 $key4 $key5 )
containers=( "vault1" "vault2" "vault3" )


for container in "${containers[@]}"
do
	for key in "${keys[@]}"
	do
		docker exec -it $container vault unseal $key
	done
	docker exec -it $container vault auth $root_token
done
