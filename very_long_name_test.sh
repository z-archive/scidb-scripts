#!/bin/sh
set -ux
export SCIDB_KILL_TIMEOUT=30

function do_test()
{
    git checkout $1;
    export REPART_ENABLE_TILE_MODE=$3;
    export TILE_SIZE=$4;
    (cd ../..; CC="ccache gcc" CXX="ccache g++" cmake . -DCMAKE_BUILD_TYPE=Debug; make -j5)
    killall scidb
    sleep 15
    killall -9 scidb
    sleep 15
    ./runN.py $2 scidb --istart
    sleep 15
    export FILENAME=node-$2_branch-$1_repart-tile-mode-$3_tile_size-$4
    ../../bin/scidbtestharness --root-dir=testcases/ --suite-id=checkin.newaql 2>&1| tee  ${FILENAME}
    cat ${FILENAME} | grep -v Executing | grep -v PASS | awk '{print $6" "$8}' | grep -v queryabort > processed.${FILENAME}
}

for branch in master; do
    for count in 1 2; do
	for mode in 0 1; do
	    do_test $branch $count 0 10000
	done;
    done;
done;
