# Build toolchain for this Geode mod inside the Base44 sandbox.
#
# This image contains build tooling only - the mod's source is bind-mounted at
# runtime, so edits are picked up without rebuilding the image.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Geode 5.x refuses to configure with Clang < 19 and Ubuntu 24.04's default
# `clang` is 18, so Clang/LLVM 19 is installed explicitly. The cross-toolchain
# looks for the *unversioned* llvm-ar / llvm-nm / llvm-mt / llvm-rc / lld-link
# names, which is why /usr/lib/llvm-19/bin is prepended to PATH below.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        clang-19 \
        cmake \
        curl \
        git \
        jq \
        lld-19 \
        llvm-19 \
        make \
        unzip \
    && rm -rf /var/lib/apt/lists/*

# Geode CLI: Linux binary published with every CLI release. CMake finds the
# build system through it, so it must be on PATH.
ARG GEODE_CLI_VERSION=v3.9.0
RUN mkdir -p /opt/geode/cli \
    && curl -fsSL "https://github.com/geode-sdk/cli/releases/download/${GEODE_CLI_VERSION}/geode-cli-${GEODE_CLI_VERSION}-linux.zip" -o /tmp/geode-cli.zip \
    && unzip -q /tmp/geode-cli.zip -d /opt/geode/cli \
    && rm /tmp/geode-cli.zip

ENV PATH="/usr/lib/llvm-19/bin:/opt/geode/cli:${PATH}"

# The CLI refuses to install SDK binaries until at least one GD profile exists.
RUN mkdir -p /opt/geode/profile/geode/mods \
    && geode profile add --name base44 /opt/geode/profile/GeometryDash.exe win

# Geode SDK, its prebuilt binaries, and the Linux -> Windows cross-compilation
# toolchain (xwin + Windows SDK), which is how mods are built in this sandbox.
ENV GEODE_SDK=/opt/geode/sdk
RUN geode sdk install /opt/geode/sdk \
    && geode sdk install-binaries -p win \
    && geode sdk install-linux

COPY .base44/scripts/build-mod.sh /opt/base44/build-mod.sh
RUN chmod +x /opt/base44/build-mod.sh

WORKDIR /work
