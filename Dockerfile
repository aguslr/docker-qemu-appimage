ARG BASE_IMAGE=library/ubuntu:focal

FROM docker.io/${BASE_IMAGE}

ENV QEMU_VER=8.0.2

RUN \
  apt-get update && \
  env DEBIAN_FRONTEND=noninteractive \
  apt-get install -y --no-install-recommends \
  wget ca-certificates file imagemagick \
  build-essential bison flex ninja-build valgrind \
  libaio-dev \
  libbluetooth-dev \
  libbpf-dev \
  libbrlapi-dev \
  libbz2-dev \
  libcacard-dev \
  libcap-ng-dev \
  libcapstone-dev \
  libcurl4-gnutls-dev \
  libdaxctl-dev \
  libdrm-dev \
  libdw-dev \
  libfdt-dev \
  libfuse3-dev \
  libgbm-dev \
  libgcrypt20-dev \
  libglib2.0-dev \
  libglusterfs-dev \
  libgtk-3-dev \
  libibverbs-dev \
  libiscsi-dev \
  libjack-dev \
  libjpeg-dev \
  libkeyutils-dev \
  liblzo2-dev \
  libmount-dev \
  libncurses5-dev \
  libnfs-dev \
  libnuma-dev \
  libp11-kit-dev \
  libpam0g-dev \
  libpixman-1-dev \
  libpmem-dev \
  libpulse-dev \
  librbd-dev \
  librdmacm-dev \
  libsasl2-dev \
  libsdl2-dev libsdl2-image-dev \
  libseccomp-dev \
  libslirp-dev \
  libsnappy-dev \
  libsndio-dev \
  libspice-server-dev \
  libssh-dev \
  libu2f-udev \
  libunistring-dev \
  libusb-1.0-0-dev libusb-dev libusbredirhost-dev \
  libvde-dev \
  libvdeplug-dev \
  libvirglrenderer-dev \
  libvncserver-dev \
  libvte-2.91-dev libvte-dev \
  libxen-dev \
  libxkbcommon-dev \
  libzstd-dev \
  xfslibs-dev \
  zlib1g-dev \
  -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
  && apt-get clean && rm -rf /var/lib/apt/lists/* /var/lib/apt/lists/*

WORKDIR /opt/qemu

COPY entrypoint.sh /entrypoint.sh

VOLUME /opt/qemu /input /output

ENTRYPOINT ["/entrypoint.sh"]
