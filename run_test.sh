#!/usr/bin/env bash

./node_modules/.bin/ganache-cli -d > /dev/null &
pid=$!
eval "yarn run test"
test_result=$?
kill $pid
exit "$test_result"

