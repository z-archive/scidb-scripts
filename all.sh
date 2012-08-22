#!/bin/sh

export suite=checkin.newaql

exec > >(tee output.log)
exec 2>&1

for tile_size in 10000; do
    for branch in my_master repart_preserving_fix; do
	for node in 1 2; do
	    for mode in 0 1; do
		source ./test.sh ${branch} ${node} ${suite} ${tile_mode} {$tile_size}
	    done;
	done;
    done;
done;
