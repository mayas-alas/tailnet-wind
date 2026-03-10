# Stage 1: Build podlet (to generate Quadlets from CLI)
FROM rust:bookworm AS builder
RUN cargo install podlet

# Stage 2: Runtime
FROM mcr.microsoft.com/devcontainers/base:bookworm

# Install Podman, Systemd, and tools
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y podman systemd systemd-container curl tar \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install OpenVSCode Server (FOSS)
RUN RELEASE_TAG=$(curl -s https://api.github.com/repos/gitpod-io/openvscode-server/releases/latest | grep -Po '"tag_name": "\K.*?(?=")') \
    && curl -fsSL "https://github.com/gitpod-io/openvscode-server/releases/download/${RELEASE_TAG}/${RELEASE_TAG}-linux-x64.tar.gz" -o server.tar.gz \
    && tar -xzf server.tar.gz --strip-components=1 -C /usr/local && rm server.tar.gz

# Copy podlet from builder
COPY --from=builder /usr/local/cargo/bin/podlet /usr/local/bin/podlet

# Create necessary directories
RUN mkdir -p /home/vscode/.config/containers/systemd/ /home/vscode/.config/systemd/user/

# Copy your specific business configs (Assuming these are in your repo root)
COPY openvscode.service /home/vscode/.config/systemd/user/
COPY todo-app.container /home/vscode/.config/containers/systemd/

# Fix permissions
RUN chown -R vscode:vscode /home/vscode/.config

# Boot systemd as PID 1 to support Quadlets
STOPSIGNAL SIGRTMIN+3
ENTRYPOINT ["/lib/systemd/systemd"]
