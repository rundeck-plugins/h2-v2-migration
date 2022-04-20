#!/bin/bash

#/ Use Rundeck API to add add license and enable executions

set -euo pipefail
IFS=$'\n\t'
SRC_DIR=$(cd "$(dirname "$0")" && pwd)
source "${SRC_DIR}/common.sh"
ENDPOINT=api/41/enterprise/license
ENDPOINT34=api/40/incubating/enterprise/license

api_post_license(){
  curl -s -S -X POST -H "x-rundeck-auth-token:${TOKEN}" -H "accept:application/json" -H "content-type:application/x-rundeck-license" \
      --data-binary "@$1" "http://localhost:4441/$ENDPOINT?license_agreement=$2" | jq .
}
main(){
  local DATADIR=$1
  local LFILE=$2
  local AGREE=$3
  local VERS=$4

  TOKEN=$(authenticate $DATADIR)
  # set license
  if [[ "$VERS" =~ ^3.4. ]] ; then
    ENDPOINT=$ENDPOINT34
  fi
  api_post_license "$LFILE" "$AGREE" >"$DATADIR/set-license.json"
  [ 0 == $? ] || die "API set license failed"
  assert_json "$DATADIR/set-license.json" ".message" "OK" "Set Enterprise License $VERS"

  # enable execution mode
  api_post "system/executions/enable" '{}' >"$DATADIR/executions_enable.json"
  [ 0 == $? ] || die "API set execution mode failed"
  assert_json "$DATADIR/executions_enable.json" ".executionMode" "active" "Set ExecutionMode Active"

  # allow heartbeat warmup time
  sleep 15
}

main "${@}"