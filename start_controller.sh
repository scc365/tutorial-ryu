#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace
fi

CONTROLLER_FILE="./controller.py"

function becho {
    echo -e "\033[1m$1\033[0m"
}

if [ -f "$CONTROLLER_FILE" ]; then
    (docker rm -f controller &> /dev/null) | true
    becho "🐳\t Starting Ryu Controller"
    docker run --rm -it -p 6633:6633/tcp  \
        -v "$(pwd)"/:/workspace/ \
        --label scc365=controller --name controller \
        ghcr.io/scc365/ryu:latest \
        --ofp-tcp-listen-port 6633 controller.py
    becho "👋\tDone"
else
    becho "🆘\tController file not found"
    echo "run this script from the same directory as the controller.py file"
fi