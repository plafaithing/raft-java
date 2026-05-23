#!/bin/bash
cd /mnt/d/workplace/java/raft1/raft-java-master/raft-java-example

for i in 1 2 3 4 5; do
    echo "=== example$i ==="
    head -5 env/example$i/bin/run_server.sh
done