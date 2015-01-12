#!/bin/sh
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FILES=$*
host=$1
webpath=$2
corename=$3
URL=http://${host}:8080/${webpath}/${corename}/update

for f in "${@:4}"; do
  echo Posting file $f to $URL
  curl $URL --data-binary @$f -H 'Content-type:application/xml' 
done

curl "$URL?softCommit=true"
echo
