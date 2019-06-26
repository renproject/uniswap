#!/usr/bin/env bash

./node_modules/.bin/ganache-cli -d > /dev/null &
pid=$!
yarn run test
kill $pid
exit 0

