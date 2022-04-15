#!/bin/bash

#/ Test the changelog migration using docker and Rundeck version 3.4.10, 4.0.1, migrating to 4.1.0
#/ Usage: test.sh [-t] [-w ID]

set -euo pipefail
IFS=$'\n\t'
SRC_DIR=$(cd "$(dirname "$0")" && pwd)
TOKEN=letmein

usage() {
  grep '^#/' <"$0" | cut -c4- # prints the #/ lines above as usage info
}
die() {
  echo >&2 "$@"
  exit 2
}

declare -a FROM_VERS=(3.4.10)
MIGRATE=SNAPSHOT
REPO=${REPO:-rundeck/rundeck}

wait_for_server_start() {
  local ID=$1
  local DATADIR=$2
  local timeout=20
  local count=0
  #  echo "Waiting for container $ID..."
  set +eo pipefail
  while ! docker logs "$ID" 2>&1 | grep -q 'Grails application running'; do
    ((count++))
    if [ "$count" -gt $timeout ]; then
      if docker logs "$ID" 2>&1 | grep -q 'Exception'; then
        echo "Startup failed, some exception was caused"
        docker logs "$ID" >"$DATADIR/logs/rundeck.log"
      fi
      exit 1
    fi
    sleep 5
    #    echo "not found..."
  done
  #  echo "Done."
  if docker logs "$ID" 2>&1 | grep -q 'Exception'; then
    echo "Startup failed, some exception was caused"
    docker logs "$ID" >"$DATADIR/logs/rundeck.log"
    exit 1
  fi
  set -eo pipefail
}
start_docker() {
  local IMAGE=$1
  local DATADIR=$2
  local ID=$(
    docker run -d -P -p 4441:4440 \
      -e RUNDECK_SERVER_ADDRESS=0.0.0.0 \
      -e RUNDECK_GRAILS_URL=http://localhost:4441 \
      -v "${DATADIR}/data:/home/rundeck/server/data" \
      -v "${SRC_DIR}/etc:/home/rundeck/etc" \
      "${IMAGE}"
  )

  wait_for_server_start "$ID" "$DATADIR"
  echo "$ID"
}

api_get() {
  curl -H "x-rundeck-auth-token:${TOKEN}" -H "accept:application/json" "http://localhost:4441/api/40/$1" | jq .
}

api_post() {
  curl -X POST -H "x-rundeck-auth-token:${TOKEN}" -H "accept:application/json" -H "content-type:application/json" --data-binary "$2" "http://localhost:4441/api/40/$1" | jq .
}
api_jobxml_create() {
  curl -X POST -H "x-rundeck-auth-token:${TOKEN}" -H "accept:application/json" \
    -H "content-type:application/xml" \
    --data-binary "$1" \
    "http://localhost:4441/api/40/project/test/jobs/import?dupeOption=skip" | jq .
}
authenticate() {
  local DATADIR=$1
  set +e
  if [ -f "${DATADIR}/token.out" ]; then
    jq -r .token <"${DATADIR}/token.out"
    exit 0
  fi
  curl -X POST \
    -s -S -L -c cookies -b cookies \
    -d j_username=admin -d j_password=admin \
    "http://localhost:4441/j_security_check" >login.out
  if [ 0 != $? ]; then
    die "login failure"
  fi

  if grep -q 'j_security_check' login.out; then
    die "login was not successful"
  fi
  # request API token
  curl -X POST \
    -s -S -L -c cookies -b cookies \
    -H "content-type:application/json" \
    -H "accept:application/json" \
    --data-binary '{"roles":"*"}' \
    "http://localhost:4441/api/40/tokens/admin" >"${DATADIR}/token.out"
  if [ 0 != $? ]; then
    die "Token creation failed"
  fi

  jq -r .token <token.out
  set -e
}

load_test_data() {
  local DATADIR=$1
  echo "Authenticate"
  TOKEN=$(authenticate $DATADIR)
  [ -n "$TOKEN" ] && [ "null" != "$TOKEN" ] || die "Could not get auth TOKEN"
  echo "Test API with token $TOKEN"

  VAL=$(api_get "system/info" | jq -r .system.rundeck.version)
  [ 0 == $? ] || die "API test failed"
  [ -n "$VAL" ] && [ "null" != "$VAL" ] || die "Could not get sys info: $VAL"

  api_post "projects" '{"name":"test"}' > "$DATADIR/create-project.out"
  [ 0 == $? ] || die "Create project failed"
  VAL=$(jq -r .url "$DATADIR/create-project.out" )
  VAL2=$(jq -r .errorCode "$DATADIR/create-project.out")
  [ -n "$VAL" ] && [ "null" != "$VAL" ] ||
    [ -n "$VAL2" ] && [ "api.error.item.alreadyexists" == "$VAL2" ] ||
     die "Could not get create project: $VAL"

  VAL=$(api_jobxml_create "@${SRC_DIR}/test-job.xml" | jq -r ".succeeded[0].message + \"/\" + .skipped[0].error")
  [ 0 == $? ] || die "Create job failed"
  [ -n "$VAL" ] && [ "null" != "$VAL" ] || die "Could not get value: $VAL"

  api_post 'job/4cb8f9f9-2a1c-48b6-aca0-018169d2f7c8/executions' '{}' > "$DATADIR/run1.out"
  [ 0 == $? ] || die "Execute job failed"

  execid=$(jq -r .id "$DATADIR/run1.out")
  [ -n "$execid" ] && [ "null" != "$execid" ] || die "Could not get execution id"

  echo "Execid: $execid"
}

verify_test_data() {
  local DATADIR=$1
  echo "Authenticate"
  TOKEN=$(authenticate $DATADIR)
  [ -n "$TOKEN" ] && [ "null" != "$TOKEN" ] || die "Could not get auth TOKEN"
  echo "Test API with token $TOKEN"

  VAL=$(api_get "system/info" | jq -r .system.rundeck.version)
  [ 0 == $? ] || die "API test failed"
  [ -n "$VAL" ] && [ "null" != "$VAL" ] || die "Could not get sys info: $VAL"

  api_get "projects"  > "$DATADIR/get-projects.out"
  [ 0 == $? ] || die "Get projects failed"

  VAL=$(jq -r length "$DATADIR/get-projects.out" )
  [ "1" == "$VAL" ] || die "Expected 1 result: $VAL"

  VAL=$(jq -r .[0].name "$DATADIR/get-projects.out")
  [ "test" == "$VAL" ] || die "Expected test project: $VAL"

}

backup_db(){
  local DATADIR=$1
  mkdir -p "$DATADIR/backup"
  cp $DATADIR/data/grailsdb* "$DATADIR/backup/"
}

migrate_db(){
  local DATADIR=$1
  local username=$2
  local password=$3
  sh "$SRC_DIR/../migration.sh" -f "${DATADIR}/backup/grailsdb" -u "${username}" -p "${password}"
}

copy_db(){
  local DATADIR=$1
  cp "$SRC_DIR/../output/v2/data/grailsdb.mv.db" "$DATADIR/data/"
}

upgrade_db(){
  local DATADIR=$1
  backup_db "$DATADIR"
  migrate_db "$DATADIR" "" ""
  copy_db "$DATADIR"
}

test_upgrade() {
  local FROMVERS=$1
  local TOVERS=$2
  local DATADIR="${SRC_DIR}/test-$FROMVERS-$TOVERS"
  mkdir -p "$DATADIR/data"
  mkdir -p "$DATADIR/logs"

  echo "Starting docker ${REPO}:${FROMVERS} ..."
  local ID
  ID=$(start_docker "${REPO}:${FROMVERS}" "$DATADIR")

  echo "Populating data for $ID ..."
  load_test_data "$DATADIR"

  echo "Stopping $ID ..."
  docker stop "$ID"

  echo "Upgrading H2v1 DB to H2V2 ..."
  upgrade_db "$DATADIR"

  ID=$(start_docker "${REPO}:${TOVERS}" "$DATADIR")

  echo "Testing data for $ID ..."
  verify_test_data "$DATADIR"

  echo "Stopping $ID ..."
  docker stop "$ID"


  echo "Upgrade from $FROMVERS to $TOVERS verification complete."
}

test_all_versions() {
  for VERS in "${FROM_VERS[@]}"; do
    test_upgrade "$VERS" "$MIGRATE"
  done
}

main() {
  local ddir
  local fromvers
  local repo
  while getopts tw:a:l:u:v:d:f:r:s flag; do
    case "${flag}" in
    t)
      echo "testing..."
      test_all_versions
      exit 0
      ;;
    d)
      ddir=${OPTARG}
      ;;
    f)
      fromvers=${OPTARG}
      ;;
    r)
      repo=${OPTARG}
      ;;
    s)
      start_docker "${repo:?-r repo required}:${fromvers:?-f version required}" "${ddir:?-d dir required}"
      exit 0
      ;;
    w)
      wait_for_server_start ${OPTARG}
      exit 0
      ;;
    a)
      authenticate ${OPTARG}
      exit 0
      ;;
    l)
      load_test_data ${OPTARG}
      exit 0
      ;;
    u)
      upgrade_db ${OPTARG}
      exit 0
      ;;
    v)
      verify_test_data ${OPTARG}
      exit 0
      ;;
    ?)
      echo "unknown"
      usage
      exit 1
      ;;
    *)
      usage
      exit 2
      ;;
    esac
  done
}

main "${@}"
