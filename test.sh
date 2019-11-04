#!/bin/bash

set -e

function failure
{
	kill "$REG"
	kill "$REG_AUTH"

	echo "FAILURE!"
}

trap failure EXIT

docker rm -fv registry-auth registry 2>/dev/null || true

make run_registry >&/dev/null &
REG=$!

sleep 2

make run_registry_auth >&/dev/null &
REG_AUTH=$!

sleep 2

make test_curl

make set_read_only

if make test_curl ; then
	echo "FAILED: test_curl in read-only mode!"
	exit 1
fi

make unset_read_only

make test_curl

kill "$REG"
kill "$REG_AUTH"

trap - EXIT
