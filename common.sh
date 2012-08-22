#!/bin/sh

set -ux

mkdir -p general
mkdir -p result
mkdir -p archive
mkdir -p build
mkdir -p restart
mkdir -p harness

export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/lib64/openmpi/lib

export BRANCH_NAME=${1}
export NODE_COUNT=${2}
export SUITE_NAME=${3}
export TILE_MODE=${4=0}
export TILE_SIZE=${5=0}

export SUITE_NAME_CMD=" --suite-id=${SUITE_NAME}"
export REPART_ENABLE_TILE_MODE=${TILE_MODE}

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
export LOG_FILENAME=${FILENAME}.log
export LOG=${WD}/harness/${LOG_FILENAME}
export PROCESSED=${WD}/result/${LOG_FILENAME}
export ARCHIVE=${WD}/archive/${FILENAME}.tar.gz

PLUGIN_LIST="system timeseries linear_algebra"
SO_LIST="p4_msg"

function build()
{
    test -z CMAKE_BUILD_TYPE || export CMAKE_BUILD_TYPE=Debug
    export CMAKE="/bin/cmake . -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"

    (cd ${SCIDB_PATH} && git checkout ${BRANCH_NAME})
    (cd ${SCIDB_PATH} && rm -f CMakeCache.txt)
    export CC="/bin/ccache /bin/gcc"
    export CXX="/bin/ccache /bin/g++"
    (cd ${SCIDB_PATH} && ${CMAKE})
    (cd ${SCIDB_PATH} && make -j5)

    (cd ${P4_PATH} && git checkout ${BRANCH_NAME})
    (cd ${P4_PATH} && rm -f CMakeCache.txt)
    unset CC
    unset CXX
    (cd ${P4_PATH} && ${CMAKE} -DSCIDB_SOURCE_DIR=${SCIDB_PATH})
    (cd ${P4_PATH} && make -j5)
    for PLUGIN in ${PLUGIN_LIST} ${SO_LIST}; do
	SO=lib${PLUGIN}.so
	rm -f ${BIN}/plugins/${SO}
	cp ${P4_PATH}/plugins/${SO} ${BIN}/plugins
    done;
}

function stop()
{
    find ${BIN} -name "*.log" -exec rm -f {} +
    killall scidb && sleep ${WAIT_TIMEOUT} || true
    killall -9 scidb && sleep ${WAIT_TIMEOUT} || true
}

function start()
{
    (cd ${HARNESS} && ./runN.py ${NODE_COUNT} scidb --istart)
    sleep ${SCIDB_KILL_TIMEOUT}
    for PLUGIN in ${PLUGIN_LIST}; do
	${IQUERY} -aq "load_library('${PLUGIN}')";
    done;
    sleep ${SCIDB_KILL_TIMEOUT}
}

function restart()
{
    stop
    start
}

function run_harness()
{
    (cd ${HARNESS} && ${SCIDBTESTHARNESS} --root-dir=${TESTCASES}${SUITE_NAME_CMD} 2>&1 | tee ${LOG})
}

function process_result()
{
    (cd ${SCIDB_PATH}; find bin -name "*.log" | xargs tar vfzc ${TESTCASES}/scidb_log.tar.gz) || true
    cp ${LOG} ${TESTCASES}
    rm -f ${ARCHIVE}
    (cd ${HARNESS} && tar vfzc ${ARCHIVE} testcases 1>/dev/null 2>&1) || true
    rm -f ${TESTCASES}/scidb_log.tar.gz
    rm -f ${TESTCASES}/${LOG_FILENAME}.log
    echo "BRANCH=${BRANCH_NAME}"    | tee ${PROCESSED}
    echo "NODE=${NODE_COUNT}"      | tee -a ${PROCESSED}
    echo "TILE_MODE=${TILE_MODE}" | tee -a ${PROCESSED}
    echo "TILE_SIZE=${TILE_SIZE}" | tee -a ${PROCESSED}
    cat ${LOG} | grep -v Executing | grep -v PASS | awk '{print $6" "$8}' | grep -v queryabort | tee -a ${PROCESSED}
}

function run()
{
    build 2>&1   | tee build/${LOG_FILENAME}
    restart 2>&1 | tee restart/${LOG_FILENAME}
    run_harness
    stop | tee -a restart/${LOG_FILENAME}
    process_result
}
