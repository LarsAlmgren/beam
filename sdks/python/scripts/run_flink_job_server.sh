#!/bin/bash
#
#    Licensed to the Apache Software Foundation (ASF) under one or more
#    contributor license agreements.  See the NOTICE file distributed with
#    this work for additional information regarding copyright ownership.
#    The ASF licenses this file to You under the Apache License, Version 2.0
#    (the "License"); you may not use this file except in compliance with
#    the License.  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#

read -r -d '' USAGE <<END
Usage: run_flink_job_server.sh (start|stop) [options]
Options:
  --group_id [unique id for stop services later]
  --job_port [port for job endpoint, default 8099]
  --artifact_port [port for artifact service, default 8098]
  --flink_job_server_jar [path to Flink job server jar]
END

JOB_PORT=8099
ARTIFACT_PORT=8098

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --group_id)
      GROUP_ID="$2"
      shift
      shift
      ;;
    --job_port)
      JOB_PORT="$2"
      shift
      shift
      ;;
    --artifact_port)
      ARTIFACT_PORT="$2"
      shift
      shift
      ;;
    --flink_job_server_jar)
      FLINK_JOB_SERVER_JAR="$2"
      shift
      shift
      ;;
    start)
      STARTSTOP="$1"
      shift
      ;;
    stop)
      STARTSTOP="$1"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "$USAGE"
      exit 1
      ;;
  esac
done

FILE_BASE="beam-flink-job-server"
if [ -v GROUP_ID ]; then
  FILE_BASE="$FILE_BASE-$GROUP_ID"
fi

TEMP_DIR=/tmp
pid=$TEMP_DIR/$FILE_BASE.pid
lock=$TEMP_DIR/$FILE_BASE.lock

command -v flock >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
  exec 200>$lock
  if ! flock -n 200; then
    echo "script already running."
    exit 0
  fi
fi

case $STARTSTOP in
  start)
    if [ -f "$pid" ]; then
      echo "services already running."
      exit 0
    fi

    echo "Launching Flink job server @ $JOB_PORT ..."
    java -jar $FLINK_JOB_SERVER_JAR --flink-master=[local] --job-port=$JOB_PORT --artifact-port=$ARTIFACT_PORT --expansion-port=0 >$TEMP_DIR/$FILE_BASE.log 2>&1 </dev/null &
    mypid=$!
    if kill -0 $mypid >/dev/null 2>&1; then
      echo $mypid >> $pid
    else
      echo "Can't start Flink job server."
    fi
    ;;
  stop)
    if [ -f "$pid" ]; then
      while read stop_pid; do
        if kill -0 $stop_pid >/dev/null 2>&1; then
          echo "Stopping Flink job server pid: $stop_pid."
          kill $stop_pid
        else
          echo "Skipping invalid pid: $stop_pid."
        fi
      done < $pid
      rm $pid
    fi
    ;;
esac
flock -u 200
