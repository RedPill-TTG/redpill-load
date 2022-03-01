#!/bin/sh

echo "Starting ttyd, listening on port: 7681"
./ttyd login > ttyd.log 2>&1 &
