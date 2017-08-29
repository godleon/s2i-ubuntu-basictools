#!/bin/bash -e
#
# The 'run' performs a simple test that verifies that STI image.
# The main focus is that the image prints out the base-usage properly.
#
# IMAGE_NAME specifies a name of the candidate image used for testing.
# The image has to be available before this script is executed.
#
IMAGE_NAME=${IMAGE_NAME-openshift/s2i-ubuntu-basetools:16.04}

# Determining system utility executables (darwin compatibility check)
READLINK_EXEC="readlink"
MKTEMP_EXEC="mktemp"
if [[ "$OSTYPE" =~ 'darwin' ]]; then
  ! type -a "greadlink" &>"/dev/null" || READLINK_EXEC="greadlink"
  ! type -a "gmktemp" &>"/dev/null" || MKTEMP_EXEC="gmktemp"
fi

test_dir="$($READLINK_EXEC -zf $(dirname "${BASH_SOURCE[0]}"))"
image_dir=$($READLINK_EXEC -zf ${test_dir}/..)
scripts_url="file://${image_dir}/.s2i/bin"
cid_file=$($MKTEMP_EXEC -u --suffix=.cid)

# Since we built the candidate image locally, we don't want S2I to attempt to pull
# it from Docker hub
s2i_args="--pull-policy=never --loglevel=2"


image_exists() {
  docker inspect $1 &>/dev/null
}

container_exists() {
  image_exists $(cat $cid_file)
}

run_s2i_build() {
  s2i build --incremental=true ${s2i_args} file://${test_dir} ${IMAGE_NAME} ${IMAGE_NAME}-testapp
}

test_usage() {
  echo "Testing 's2i usage'..."
  s2i usage ${s2i_args} ${IMAGE_NAME} &>/dev/null
}

cleanup() {
  if [ -f $cid_file ]; then
    if container_exists; then
      docker stop $(cat $cid_file)
    fi
  fi
  if image_exists ${IMAGE_NAME}-testapp; then
    docker rmi ${IMAGE_NAME}-testapp
  fi
}

run_test_application() {
  docker run --rm --cidfile=${cid_file} ${IMAGE_NAME}-testapp
}

wait_for_cid() {
  local max_attempts=10
  local sleep_time=1
  local attempt=1
  local result=1
  while [ $attempt -le $max_attempts ]; do
    [ -f $cid_file ] && break
    echo "Waiting for container to start..."
    attempt=$(( $attempt + 1 ))
    sleep $sleep_time
  done
}

test_docker_run_usage() {
    echo "Testing 'docker run' usage..."
    docker run --rm ${IMAGE_NAME}
}

check_result() {
    local result="$1"
    if [[ "$result" != "0" ]]; then
        echo "-----------------------> STI image '${IMAGE_NAME}' test FAILED (exit code: ${result})"
        echo "------------------------------------------------> TEST STOPPED!"
        exit $result
    fi

    echo "-----------------------> TEST SUCCEED!"
}

run_s2i_build
check_result $?

# Verify the 'usage' script is working properly
test_usage
check_result $?

# Verify that the HTTP connection can be established to test application container
run_test_application &

# Wait for the container to write its CID file
wait_for_cid

# Verify the 'usage' script is working properly when running the base image with 'docker run ...'
#test_docker_run_usage
check_result $?

cleanup
echo "------------------------------------------------> TEST ENDED!"