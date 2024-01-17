#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace
fi

TOPOLOGY_FILE="./topology.py"

function becho {
    echo -e "\033[1m$1\033[0m"
}

if [ -f "$TOPOLOGY_FILE" ]; then
    (docker rm -f topology &> /dev/null) | true
    becho "🐳\t Starting Mininet Topology"
    docker run --rm -it --privileged --network host \
      --cap-add NET_ADMIN --cap-add SYS_ADMIN --cap-add NET_RAW \
      --name topology --label scc365=topology \
      -v "$(pwd)"/topology.py:/workspace/topology.py:ro \
      ghcr.io/scc365/mininet:latest \
      python3 topology.py
    becho "👋\tDone"
else
    becho "🆘\Topology file not found"
    echo "run this script from the same directory as the topology.py file"
fi