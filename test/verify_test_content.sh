#!/bin/bash

set -euo pipefail
IFS=$'\n\t'
SRC_DIR=$(cd "$(dirname "$0")" && pwd)
source "${SRC_DIR}/common.sh"

main() {
  local DATADIR=$1
  echo "Authenticate"
  TOKEN=$(authenticate $DATADIR)
  [ -n "$TOKEN" ] && [ "null" != "$TOKEN" ] || die "Could not get auth TOKEN"
  echo "Test API with token $TOKEN"

  api_get "system/info" > "$DATADIR/system-info.json"
  [ 0 == $? ] || die "API test failed"
  assert_json_notnull "$DATADIR/system-info.json" ".system.rundeck.version" "System Info Version"

  api_get "projects" >"$DATADIR/get-projects.out"
  [ 0 == $? ] || die "Get projects failed"

  assert_json "$DATADIR/get-projects.out" "length" "1" "Project List: 1 Result"
  assert_json "$DATADIR/get-projects.out" ".[0].name" "test" "Project List: Project name"

  api_get "project/test/jobs" >"$DATADIR/get-jobs.out"
  [ 0 == $? ] || die "Get Jobs failed"

  assert_json "$DATADIR/get-jobs.out" "length" "1" "Jobs List: 1 Result"
  assert_json "$DATADIR/get-jobs.out" ".[0].id" "$JOBID" "Jobs List: Job ID Value"

  api_get "execution/1" >"$DATADIR/get-exec.out"
  [ 0 == $? ] || die "Get Execution failed"

  assert_json "$DATADIR/get-exec.out" ".job.id" "$JOBID" "Execution Job ID Value"
  assert_json "$DATADIR/get-exec.out" ".status" "succeeded" "Execution Status"
}

main "${@}"