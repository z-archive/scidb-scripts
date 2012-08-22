#!/bin/sh

set -ux

export suite=${suite=checkin}
export branch=${branch=my_master}
for tile_size in 10000; do
    for node in 1 2; do
	for tile_mode in 1 0; do
	    source ./common.sh ${branch} ${node} ${suite} ${tile_mode} ${tile_size} 1>common.log 2>&1
	    export GENERAL=general/${LOG_FILENAME}
	    cat common.log | tee ${GENERAL}
	    rm common.log
	    run | tee -a ${GENERAL}
	done;
    done;
done;
