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
LICENSEFILE=
LICENSEAGREE=false
source "${SRC_DIR}/common.sh"


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
        echo "Startup failed, an exception was encountered, stored in $DATADIR/logs/rundeck.stdout.log and $DATADIR/logs/rundeck.stderr.log">&2
        docker logs "$ID"  >"$DATADIR/logs/rundeck.stdout.log"  2>"$DATADIR/logs/rundeck.stderr.log"
        echo "Stopping...$ID">&2
        docker stop $ID
      fi
      exit 1
    fi
    sleep 5
    #    echo "not found..."
  done
  #  echo "Done."
  if docker logs "$ID" 2>&1 | grep -q 'Exception'; then
      echo "Startup failed, an exception was encountered, stored in $DATADIR/logs/rundeck.stdout.log and $DATADIR/logs/rundeck.stderr.log">&2
      docker logs "$ID"  >"$DATADIR/logs/rundeck.stdout.log"  2>"$DATADIR/logs/rundeck.stderr.log"
      echo "Stopping...$ID">&2
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

load_test_data() {
  local DATADIR=$1
  if [ -n "$LICENSEFILE" ]; then
    sh "${SRC_DIR}/load_license.sh" "${DATADIR}" "${LICENSEFILE}" "${LICENSEAGREE}"
  fi
  sh "${SRC_DIR}/create_test_content.sh" "${DATADIR}"
}

verify_test_data() {
  local DATADIR=$1
  sh "${SRC_DIR}/verify_test_content.sh" "${DATADIR}"
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
  if [ -f "$DATADIR/data/grailsdb.mv.db" ] ; then
      echo "WARNING: detected existing data in workdir $DATADIR. Likely you want to remove this before starting."
  fi
  mkdir -p "$DATADIR/data"
  mkdir -p "$DATADIR/logs"
  echo "BEGIN: Upgrade test from $FROMVERS to $TOVERS for $REPO"
  echo "Workdir: $DATADIR"


  echo "Starting docker ${REPO}:${FROMVERS} with 1m timeout..."
  local ID
  ID=$(start_docker "${REPO}:${FROMVERS}" "$DATADIR")

  echo "Populating data for $ID ..."
  load_test_data "$DATADIR"

  echo "Stopping $ID ..."
  docker stop "$ID"

  echo "Upgrading H2v1 DB to H2V2 ..."
  upgrade_db "$DATADIR"

  echo "Starting docker ${REPO}:${TOVERS} with 1m timeout..."
  ID=$(start_docker "${REPO}:${TOVERS}" "$DATADIR")

  echo "Testing data for $ID ..."
  verify_test_data "$DATADIR"

  echo "Stopping $ID ..."
  docker stop "$ID"

  echo "Upgrade from $FROMVERS to $TOVERS for $REPO verification complete."
}

main() {
  local ddir
  local fromvers
  local repo
  local tovers
  while getopts Tt:w:aluvd:f:r:shL:A: flag; do
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
    L)
      LICENSEFILE=${OPTARG}
      ;;
    A)
      LICENSEAGREE=${OPTARG}
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
