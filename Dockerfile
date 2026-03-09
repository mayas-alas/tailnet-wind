# Stage 1: Build tools (podlet and quad-ops)
FROM rust:1.76-bullseye AS builder
WORKDIR /build

# Build podlet
RUN cargo install podlet

# Install Go for quad-ops
RUN wget https://go.dev/dl/go1.22.1.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.22.1.linux-amd64.tar.gz
ENV PATH=$PATH:/usr/local/go/bin

# Build quad-ops
RUN git clone https://github.com/trly/quad-ops.git && \
    cd quad-ops && \
    go build -o quad-ops .

# Stage 2: Runtime DevContainer
FROM mcr.microsoft.com/devcontainers/base:bullseye

# Explicitly set PATH so devpod agent can find git and other tools when systemd is PID 1
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Install Podman, systemd, git, and Tailscale
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y podman systemd systemd-sysv git curl sudo \
    && curl -fsSL https://tailscale.com/install.sh | sh \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Copy binaries from builder
COPY --from=builder /usr/local/cargo/bin/podlet /usr/local/bin/podlet
COPY --from=builder /build/quad-ops/quad-ops /usr/local/bin/quad-ops

# Create directory for system-wide Quadlets
RUN mkdir -p /etc/containers/systemd/

# Copy the Quadlet container file so systemd can generate the service
COPY hello-world.container /etc/containers/systemd/hello-world.container

# Copy quad-ops config
RUN mkdir -p /etc/quad-ops
COPY config.yaml /etc/quad-ops/config.yaml

# Enable systemd to run inside the container (required for Quadlets)
ENV container=docker
STOPSIGNAL SIGRTMIN+3

# Create a wrapper script to start systemd with a populated PATH
RUN echo '#!/bin/sh\nexport PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\nexec /lib/systemd/systemd "$@"' > /sbin/init-wrapper && \
    chmod +x /sbin/init-wrapper

# Also ensure /etc/environment has the path for any pam_env sessions
RUN echo 'PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' > /etc/environment

CMD ["/sbin/init-wrapper"]
