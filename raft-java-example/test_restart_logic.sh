#!/bin/bash
current_leader="node1"
port=8051

example_dir=$(echo "$current_leader" | sed 's/node/example/')
echo "Example dir: $example_dir"

stress_type="none"
case "$current_leader" in
    "node2") stress_type="cpu" ;;
    "node5") stress_type="memory" ;;
esac

echo "Stress type: $stress_type"
echo "Current node: 127.0.0.1:$port:${current_leader#node}"
echo "Command: ./bin/run_server.sh ./data \"127.0.0.1:8051:1,127.0.0.1:8052:2,127.0.0.1:8053:3,127.0.0.1:8054:4,127.0.0.1:8055:5\" \"127.0.0.1:$port:${current_leader#node}\" $stress_type"