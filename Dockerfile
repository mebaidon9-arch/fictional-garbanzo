# Build environment for the aliaspider/ppsspp "wiiu" branch.
# The branch README says it was tested with devkitPPC r38. The default image
# below is the newest one; if the build fails with compiler errors, pin an
# older tag from https://hub.docker.com/r/devkitpro/devkitppc/tags
#   docker build --build-arg DEVKITPPC_IMAGE=devkitpro/devkitppc:<tag> -t ppsspp-wiiu .
ARG DEVKITPPC_IMAGE=devkitpro/devkitppc:latest
FROM ${DEVKITPPC_IMAGE}

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      cmake git make build-essential zlib1g-dev ca-certificates zip unzip \
 && rm -rf /var/lib/apt/lists/*

ENV DEVKITPRO=/opt/devkitpro \
    DEVKITPPC=/opt/devkitpro/devkitPPC

WORKDIR /kit
COPY . /kit
RUN chmod +x /kit/build.sh /kit/package.sh

# Output lands in /kit/out (mount it: -v "$PWD/out:/kit/out")
ENTRYPOINT ["/kit/build.sh"]
