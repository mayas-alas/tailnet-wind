# Stage 1: Build podlet from source
FROM rust:bookworm AS builder
WORKDIR /build

# Install podlet (generates Quadlet files from Podman commands)
RUN cargo install podlet

# Stage 2: Runtime DevContainer
FROM mcr.microsoft.com/devcontainers/base:bookworm

# Install Podman natively via apt (much faster and more stable than Homebrew on Linux)
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y podman \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Copy the compiled podlet binary from the builder stage
COPY --from=builder /usr/local/cargo/bin/podlet /usr/local/bin/podlet
