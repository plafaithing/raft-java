#!/bin/bash
cd /mnt/d/workplace/java/raft1/raft-java-master/raft-java-example
sed -i 's/\${port#8050}/$((port-8050))/g' test_leader_preference1.sh start_raft.sh start_raft_no_stress.sh test_get_leader.sh test_get_leader_simple.sh test_get_leader_timeout.sh test_step_by_step.sh test_leader_debug.sh test_simple_leader.sh test_single_port.sh test_getleader_all.sh test_leader_preference.sh start_raft_with_stress.sh
echo "Done"