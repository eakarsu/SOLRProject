#!/bin/bash

set -x #echo on


host=$1
port=$2
webpath=$3

ROOT=$(cd $(dirname "$0"); pwd)

read activeCoreName < $ROOT/../webuiprod/src/ACTIVE_CORE_NAME

echo "activeCoreName = ${activeCoreName}"

