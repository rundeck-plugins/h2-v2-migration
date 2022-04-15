
# ID of canned job in test-job.xml
JOBID=4cb8f9f9-2a1c-48b6-aca0-018169d2f7c8

assert_json(){
  local FILE=$1
  local Q=$2
  local EXPECT=$3
  local MSG=$4
  VAL=$(jq -r "$Q" "$FILE")
  [ "$EXPECT" == "$VAL" ] || die "Result for $MSG was not correct: $VAL"
  echo "√ $MSG"
}
assert_json_notnull(){
  local FILE=$1
  local Q=$2
  local MSG=$3
  VAL=$(jq -r "$Q" "$FILE")
  [ -n "$VAL" ] && [ "null" != "$VAL" ] || die "Result for $MSG was null: $VAL"
  echo "√ $MSG"
}


api_get() {
  curl -s -S -q -H "x-rundeck-auth-token:${TOKEN}" -H "accept:application/json" "http://localhost:4441/api/40/$1" | jq .
}

api_post() {
  curl -s -S -X POST -H "x-rundeck-auth-token:${TOKEN}" -H "accept:application/json" -H "content-type:application/json" \
  --data-binary "$2" "http://localhost:4441/api/40/$1" | jq .
}
api_jobxml_create() {
  curl -s -S -X POST -H "x-rundeck-auth-token:${TOKEN}" -H "accept:application/json" \
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
  curl -s -S  -X POST \
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
  curl -s -S -X POST \
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