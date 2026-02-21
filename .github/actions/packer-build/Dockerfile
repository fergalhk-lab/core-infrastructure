FROM ubuntu:24.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        software-properties-common \
        python3 \
        python3-pip \
        openssh-client \
        git && \
    rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://apt.releases.hashicorp.com/gpg \
        | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
        https://apt.releases.hashicorp.com \
        $(lsb_release -cs) main" \
        > /etc/apt/sources.list.d/hashicorp.list

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        packer \
        ansible && \
    rm -rf /var/lib/apt/lists/*


COPY entrypoint.sh /entrypoint.sh

WORKDIR /workspace

ENTRYPOINT ["/entrypoint.sh"]
CMD []
