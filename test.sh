#!/bin/sh

set -eux

export suite=${suite=checkin}
export branch=${branch=my_master}

echo "" > ${branch}.log

for tile_size in 0; do
    for node in 1 2; do
	for tile_mode in 0 1; do
	    source ./common.sh ${branch} ${node} ${suite} ${tile_mode} ${tile_size};
	    run | tee -a ${branch}.log
	done;
    done;
done;
