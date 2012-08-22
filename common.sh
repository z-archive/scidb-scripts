#!/bin/sh

set -eux

export BRANCH_NAME=${1}
export NODE_COUNT=${2}
export SUITE_NAME=${3}
export TILE_MODE=${4=0}
export TILE_SIZE=${5=0}

export SUITE_NAME_CMD=" --suite-id=${SUITE_NAME}"
test TILE_MODE && unset REPART_ENABLE_TILE_MODE || export REPART_ENABLE_TILE_MODE=1
test TILE_SIZE && unset TILE_SIZE

export SCIDB_PATH=${SCIDB_PATH=/storage/work/scidb}
export P4_PATH=${P4_PATH=/storage/work/p4}
export SCIDB_KILL_TIMEOUT=${SCIDB_KILL_TIMEOUT=15}
export WAIT_TIMEOUT=${WAIT_TIMEOUT=5}

export BIN=${SCIDB_PATH}/bin
export IQUERY=${BIN}/iquery
export SCIDBTESTHARNESS=${BIN}/scidbtestharness
export HARNESS=${SCIDB_PATH}/tests/harness
export TESTCASES=${HARNESS}/testcases
export WD=`pwd`

export FILENAME=${SUITE_NAME}.${BRANCH_NAME}.node-${NODE_COUNT}.tile_mode-${TILE_MODE}.tile_size-${TILE_SIZE=default}
export LOG=${WD}/${FILENAME}.log
export PROCESSED=${WD}/processed.{$LOG}
export ARCHIVE=${WD}/archive.${FILENAME}.tar.gz

function build()
{
    export CC="/bin/ccache /bin/gcc"
    export CXX="/bin/ccache /bin/g++"
    test -z CMAKE_BUILD_TYPE || export CMAKE_BUILD_TYPE=Debug
    export CMAKE="/bin/cmake . -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"

    (cd ${SCIDB_PATH} && git checkout ${BRANCH_NAME})
    (cd ${SCIDB_PATH} && rm -f CMakeCache.txt)
    (cd ${SCIDB_PATH} && ${CMAKE})
    (cd ${SCIDB_PATH} && make -j5)

    (cd ${P4_PATH} && git checkout ${BRANCH_NAME})
    (cd ${P4_PATH} && rm -f CMakeCache.txt)
    (cd ${P4_PATH} && ${CMAKE} -DSCIDB_SOURCE_DIR=${SCIDB_PATH})
    (cd ${P4_PATH} && make -j5)
}

function restart()
{
    killall scidb && sleep ${WAIT_TIMEOUT} || true
    killall -9 scidb && sleep ${WAIT_TIMEOUT} || true
    (cd ${HARNESS} && ./runN.py ${NODE_COUNT} scidb --istart)
    sleep ${SCIDB_KILL_TIMEOUT}
    ${IQUERY} -aq "load_library('system')"
    ${IQUERY} -aq "load_library('p4_msg')"
    ${IQUERY} -aq "load_library('linear_algebra')"
    ${IQUERY} -aq "load_library('timeseries')"
    sleep ${SCIDB_KILL_TIMEOUT}
}

function do_test()
{
    ${SCIDBTESTHARNESS} --root-dir=${TESTCASES}${SUITE_NAME_CMD} 2>&1 | tee ${LOG}
}

function process_result()
{
    rm -f ${LOG}
    cp ${LOG} ${TESTCASES}
    rm -f ${ARCHIVE}
    tar vfzc ${ARCHIVE} ${TESTCASES}
    rm -f ${TESTCASES}/${FILENAME}.log
    sleep 1
    echo "BRANCH=${BRANCH_NAME}"    | tee ${PROCESSED}
    echo "NODE=${NODE_COUNT}"      | tee -a ${PROCESSED}
    echo "TILE_MODE=${TILE_MODE}" | tee -a ${PROCESSED}
    echo "TILE_SIZE=${TILE_SIZE}" | tee -a ${PROCESSED}
    cat ${LOG} | grep -v Executing | grep -v PASS | awk '{print $6" "$8}' | grep -v queryabort | tee -a processed.{$LOG}
}

function run()
{
    build
    restart
    do_test
    process_result
}
