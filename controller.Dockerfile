ARG RYU_VERSION=latest
FROM ghcr.io/scc365/ryu:${RYU_VERSION}

WORKDIR /controller
COPY controller.py .

CMD [ "--ofp-tcp-listen-port", "6633", "./controller.py" ]
