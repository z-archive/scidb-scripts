#!/bin/sh

set -eux

export BRANCH_NAME=${1}
export NODE_COUNT=${2}
export SUITE_NAME=${3}
export TILE_MODE=${4}
export TILE_SIZE=${5}

test SUITE_NAME && export SUITE_NAME_CMD=" --suite-id=${SUITE_NAME}"
test TILE_MODE && export REPART_ENABLE_TILE_MODE=1 || unset REPART_ENABLE_TILE_MODE
test TILE_SIZE && export TILE_SIZE=${TILE_SIZE} || unset TILE_SIZE

test -z SCIDB_PATH || export SCIDB_PATH=/storage/work/scidb
test -z P4_PATH || export P4_PATH=/storage/work/p4
test -z SCIDB_KILL_TIMEOUT || export SCIDB_KILL_TIMEOUT=15
test -z WAIT_TIMEOUT || export WAIT_TIMEOUT=5

export TESTCASES=${SCIDB_PATH}/tests/harness/testcases
export IQUERY=${SCIDB_PATH}/bin/iquery
export HARNESS=${SCIDB_PATH}/bin/scidbtestharness
export WD=${SCIDB_PATH}/tests/harness

export FILENAME=${SUITE_NAME}.${BRANCH_NAME}.node-${NODE_COUNT}.tile_mode-${TILE_MODE}.tile_size-${TILE_SIZE}
export LOG=${WD}/${FILENAME}.log
export PROCESSED=${WD}/processed.{$LOG}
export ARCHIVE=${WD}/archive.${FILENAME}.tar.gz

function build()
{
    export CC="ccache gcc"
    export CXX="ccache g++"
    test -z CMAKE_BUILD_TYPE || export CMAKE_BUILD_TYPE=Debug
    export CMAKE="cmake . -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"

    git checkout ${BRANCH_NAME};
    (cd ${SCIDB_PATH} && rm -f CMakeCache.txt)
    (cd ${SCIDB_PATH} && ${CMAKE})
    (cd ${SCIDB_PATH} && make -j5)

    git checkout ${BRANCH_NAME};
    (cd ${P4_PATH} && rm -f CMakeCache.txt)
    (cd ${P4_PATH} && ${CMAKE} -DSCIDB_SOURCE_DIR=${SCIDB_PATH})
    (cd ${P4_PATH} && make -j5)
}

function restart()
{
    killall scidb && sleep ${WAIT_TIMEOUT} || true
    killall -9 scidb && sleep ${WAIT_TIMEOUT} || true
    ./runN.py ${NODE_COUNT} scidb --istart
    sleep ${SCIDB_KILL_TIMEOUT}
    ${IQUERY} -aq "load_library('system')"
    ${IQUERY} -aq "load_library('p4_msg')"
    ${IQUERY} -aq "load_library('linear_algebra')"
    ${IQUERY} -aq "load_library('timeseries')"
    sleep ${SCIDB_KILL_TIMEOUT}
}

function do_test()
{
    ${HARNESS} --root-dir=${TESTCASES}${SUITE_NAME_CMD} 2>&1 | tee ${LOG}
}

function process_result()
{
    rm -f ${LOG}
    cp ${LOG} ${TESTCASES}
    rm -f ${ARCHIVE}
    tar vfzc ${ARCHIVE} ${TESTCASES}
    tail -f ${LOG}
    sleep 1
    echo "BRANCH=${BRANCH_NAME}"    | tee ${PROCESSED}
    echo "NODE=${NODE_COUNT}"      | tee -a ${PROCESSED}
    echo "TILE_MODE=${TILE_MODE}" | tee -a ${PROCESSED}
    echo "TILE_SIZE=${TILE_SIZE}" | tee -a ${PROCESSED}
    cat ${LOG} | grep -v Executing | grep -v PASS | awk '{print $6" "$8}' | grep -v queryabort | tee -a processed.{$LOG}
}

function all()
{
    build
    restart
    do_test
    process_result
}
