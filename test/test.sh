#!/bin/bash

#/ Test the changelog migration using docker and Rundeck
#/
#/ Usage: test.sh -f from [-t to] [-r repo] -T # test upgrade fully for image $repo:$from to $repo:$to, default rundeck/rundeck to SNAPSHOT
#/
#/ Other utilty actions:
#/
#/ Usage: test.sh -d dir -f version -r repo -s # start docker image for $repo:$vers and workdir $dir
#/ Usage: test.sh -d dir -w ID # wait for rundeck docker container $ID startup success
#/ Usage: test.sh -d dir -a  # authenticate to rundeck and store token in workdir $dir
#/ Usage: test.sh -d dir -l  # load test content to rundeck api
#/ Usage: test.sh -d dir -u  # upgrade h2 db for workdir
#/ Usage: test.sh -d dir -v  # verify test content via rundeck api
#/ Usage: test.sh -h # usage help

set -euo pipefail
IFS=$'\n\t'
SRC_DIR=$(cd "$(dirname "$0")" && pwd)
WORKDIR="${SRC_DIR}/work"
TOKEN=letmein

usage() {
  grep '^#/' <"$0" | cut -c4- # prints the #/ lines above as usage info
}
die() {
  echo >&2 "$@"
  exit 2
}

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
        echo "Startup failed, an exception was encountered, stored in $DATADIR/logs/rundeck.stdout.log and $DATADIR/logs/rundeck.stderr.log"
        docker logs "$ID"  >"$DATADIR/logs/rundeck.stdout.log"  2>"$DATADIR/logs/rundeck.stderr.log"
        echo "Stopping...$ID"
        docker stop $ID
      fi
      exit 1
    fi
    sleep 5
    #    echo "not found..."
  done
  #  echo "Done."
  if docker logs "$ID" 2>&1 | grep -q 'Exception'; then
      echo "Startup failed, an exception was encountered, stored in $DATADIR/logs/rundeck.stdout.log and $DATADIR/logs/rundeck.stderr.log"
      docker logs "$ID"  >"$DATADIR/logs/rundeck.stdout.log"  2>"$DATADIR/logs/rundeck.stderr.log"
      echo "Stopping...$ID"
      docker stop $ID
    exit 1
  fi
  set -eo pipefail
}

start_docker() {
  local IMAGE=$1
  local DATADIR=$2
  mkdir -p "${DATADIR}/etc"
  cp -r "${SRC_DIR}/etc/" "${DATADIR}/etc"
  local ID=$(
    docker run -d -P -p 4441:4440 \
      -e RUNDECK_SERVER_ADDRESS=0.0.0.0 \
      -e RUNDECK_GRAILS_URL=http://localhost:4441 \
      -v "${DATADIR}/data:/home/rundeck/server/data" \
      -v "${DATADIR}/etc:/home/rundeck/etc" \
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
  local LOGIN="${DATADIR}/login.out"
  local TFILE="${DATADIR}/token.out"
  local CFILE="${DATADIR}/cookies"
  set +e
  if [ -f "${TFILE}" ]; then
    jq -r .token <"${TFILE}"
    exit 0
  fi
  curl -X POST \
    -s -S -L -c "${CFILE}" -b "${CFILE}" \
    -d j_username=admin -d j_password=admin \
    "http://localhost:4441/j_security_check" >"${LOGIN}"
  if [ 0 != $? ]; then
    die "login failure"
  fi

  if grep -q 'j_security_check' "${LOGIN}"; then
    die "login was not successful"
  fi
  # request API token
  curl -X POST \
    -s -S -L -c "${CFILE}" -b "${CFILE}" \
    -H "content-type:application/json" \
    -H "accept:application/json" \
    --data-binary '{"roles":"*"}' \
    "http://localhost:4441/api/40/tokens/admin" >"${TFILE}"
  if [ 0 != $? ]; then
    die "Token creation failed"
  fi

  jq -r .token <"${TFILE}"
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

  api_post "projects" '{"name":"test"}' >"$DATADIR/create-project.out"
  [ 0 == $? ] || die "Create project failed"
  VAL=$(jq -r .url "$DATADIR/create-project.out")
  VAL2=$(jq -r .errorCode "$DATADIR/create-project.out")
  { [ -z "$VAL" ] || [ "null" == "$VAL" ] ; } &&
    { [ -z "$VAL2" ] || [ "api.error.item.alreadyexists" == "$VAL2" ] ; } ||
    die "Could not get create project: $VAL"

  VAL=$(api_jobxml_create "@${SRC_DIR}/test-job.xml" | jq -r ".succeeded[0].message + \"/\" + .skipped[0].error")
  [ 0 == $? ] || die "Create job failed"
  [ -n "$VAL" ] && [ "null" != "$VAL" ] || die "Could not get value: $VAL"

  api_post 'job/4cb8f9f9-2a1c-48b6-aca0-018169d2f7c8/executions' '{}' >"$DATADIR/run1.out"
  [ 0 == $? ] || die "Execute job failed"

  execid=$(jq -r .id "$DATADIR/run1.out")
  [ -n "$execid" ] && [ "null" != "$execid" ] || die "Could not get execution id"

  echo "Created execution: $execid"
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

  api_get "projects" >"$DATADIR/get-projects.out"
  [ 0 == $? ] || die "Get projects failed"

  VAL=$(jq -r length "$DATADIR/get-projects.out")
  [ "1" == "$VAL" ] || die "Expected 1 result: $VAL"

  VAL=$(jq -r .[0].name "$DATADIR/get-projects.out")
  [ "test" == "$VAL" ] || die "Expected test project: $VAL"

}

backup_db() {
  local DATADIR=$1
  mkdir -p "$DATADIR/backup"
  if [ -f "$DATADIR/backup/grailsdb.mv.db" ] ; then
    echo "not performing backup: contents already exist in $DATADIR/backup/"
    return 0
  fi
  cp $DATADIR/data/grailsdb* "$DATADIR/backup/"
}

migrate_db() {
  local DATADIR=$1
  local username=$2
  local password=$3
  sh "$SRC_DIR/../migration.sh" -f "${DATADIR}/backup/grailsdb" -u "${username}" -p "${password}"
}

copy_db() {
  local DATADIR=$1
  cp "$SRC_DIR/../output/v2/data/grailsdb.mv.db" "$DATADIR/data/"
}

upgrade_db() {
  local DATADIR=$1
  backup_db "$DATADIR"
  migrate_db "$DATADIR" "" ""
  copy_db "$DATADIR"
}

test_upgrade() {
  local FROMVERS=$1
  local TOVERS=$2
  local REPO=$3
  local DATADIR="${WORKDIR}/test-$FROMVERS"
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

main() {
  local ddir
  local fromvers
  local repo
  local tovers
  while getopts Tt:w:aluvd:f:r:sh flag; do
    case "${flag}" in
    T)
      test_upgrade "${fromvers:?-f fromvers required}" "${tovers:-SNAPSHOT}" "${repo:-rundeck/rundeck}"
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
    t)
      tovers=${OPTARG}
      ;;
    s)
      start_docker "${repo:-rundeck/rundeck}:${fromvers:?-f version required}" "${ddir:?-d dir required}"
      exit 0
      ;;
    w)
      wait_for_server_start "${OPTARG}" "${ddir:?-d dir required}"
      exit 0
      ;;
    a)
      authenticate "${ddir:?-d dir required}"
      exit 0
      ;;
    l)
      load_test_data "${ddir:?-d dir required}"
      exit 0
      ;;
    u)
      upgrade_db "${ddir:?-d dir required}"
      exit 0
      ;;
    v)
      verify_test_data "${ddir:?-d dir required}"
      exit 0
      ;;
    h)
      usage
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
  usage
  exit 2
}

if [ ${#@} -gt 0 ]; then
  main "${@}"
else
  main
fi
