#!/usr/bin/env bash

yarn run ganache-cli -d > /dev/null &
pid=$!
yarn run test
kill $pid
exit 0

