#!/bin/sh
set -ux
export SCIDB_KILL_TIMEOUT=30

function do_test()
{
    git checkout $1;
    export REPART_ENABLE_TILE_MODE=$3;
    export TILE_SIZE=$4;
    (cd ../..; CC="ccache gcc" CXX="ccache g++" cmake . -DCMAKE_BUILD_TYPE=Debug; make -j5)
    (cd ../../../p4; CC="ccache gcc" CXX="ccache g++" cmake . -DCMAKE_BUILD_TYPE=Debug -DSCIDB_SOURCE_DIR=/storage/work/scidb; make -j5)
    echo PWD=`pwd`
    killall scidb && sleep 5 || true
    killall -9 scidb && sleep 5 || true
    ./runN.py $2 scidb --istart
    sleep 15
    ../../bin/iquery -aq "load_library('system')"
    sleep 15
    export FILENAME=node-$2_branch-$1_repart-tile-mode-$3_tile_size-$4
    export PROCESSED=processed.${FILENAME}
    echo "BRANCH=$1"                  | tee ${PROCESSED}
    echo "NODE=$2"                    | tee -a ${PROCESSED}
    echo "REPART_ENABLE_TILE_MODE=$3" | tee -a ${PROCESSED}
    echo "TILE_SIZE=$4"               | tee -a ${PROCESSED}
    ../../bin/scidbtestharness --root-dir=testcases --suite-id=checkin.newaql 2>&1| tee ${FILENAME}
    cat ${FILENAME} | grep -v Executing | grep -v PASS | awk '{print $6" "$8}' | grep -v queryabort | tee -a ${PROCESSED}
}

for tile_size in 10000 5; do
    for branch in my_master repart_preserving_fix; do
	for count in 1 2; do
	    for mode in 0 1; do
		do_test $branch $count $mode $tile_size
	    done;
	done;
    done;
done;
