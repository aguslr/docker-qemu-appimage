ARG BASE_IMAGE=library/ubuntu:focal

FROM docker.io/${BASE_IMAGE}

ENV QEMU_VER=8.0.2

RUN \
  apt-get update && \
  env DEBIAN_FRONTEND=noninteractive \
  apt-get install -y wget imagemagick build-essential bison flex \
  libglib2.0-dev libfdt-dev libpixman-1-dev zlib1g-dev ninja-build valgrind \
  libaio-dev libbluetooth-dev libcapstone-dev libbrlapi-dev libbz2-dev \
  libcap-ng-dev libcurl4-gnutls-dev \
  libibverbs-dev libjpeg-dev libnuma-dev \
  libsasl2-dev libsdl2-dev libseccomp-dev libsnappy-dev \
  libvde-dev libvdeplug-dev libxen-dev liblzo2-dev \
  xfslibs-dev libnfs-dev libiscsi-dev libslirp-dev \
  libmount-dev libunistring-dev libp11-kit-dev libxkbcommon-dev \
  -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
  && apt-get clean && rm -rf /var/lib/apt/lists/* /var/lib/apt/lists/*

WORKDIR /opt/qemu

COPY entrypoint.sh /entrypoint.sh

VOLUME /opt/qemu /input /output

ENTRYPOINT ["/entrypoint.sh"]
