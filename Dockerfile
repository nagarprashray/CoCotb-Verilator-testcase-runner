FROM verilator/verilator:latest

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3-dev python3-pip \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /tmp/requirements.txt
RUN python3 -m pip install --break-system-packages -r /tmp/requirements.txt

WORKDIR /work
ENTRYPOINT []
CMD ["make"]
