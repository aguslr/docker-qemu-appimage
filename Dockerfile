ARG BASE_IMAGE=library/ubuntu:jammy

FROM docker.io/${BASE_IMAGE} AS builder
ENV QEMU_VER=9.2.2
COPY rootfs/ /
WORKDIR /src
RUN <<-EOT bash
	set -eu

	apt-get update
	env DEBIAN_FRONTEND=noninteractive \
		apt-get install -y \
		wget imagemagick file build-essential python3-pip
	apt-get clean && rm -rf /var/lib/apt/lists/* /var/lib/apt/lists/*

	pip install tomli sphinx-rtd-theme

	wget -c -nv -P / \
		"https://download.qemu.org/qemu-${QEMU_VER}.tar.xz"

	wget -c -nv \
		"https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-$(uname -m).AppImage" \
		-O /usr/local/bin/linuxdeploy.appimage && \
		chmod a+x /usr/local/bin/linuxdeploy.appimage

	mkdir -p /opt/linuxdeploy && cd /opt/linuxdeploy && \
		/usr/local/bin/linuxdeploy.appimage --appimage-extract && \
		rm -f /usr/local/bin/linuxdeploy.appimage
EOT
VOLUME /src /input /output
ENTRYPOINT ["/entrypoint.sh"]

FROM builder AS slim
RUN <<-EOT bash
	set -eu

	apt-get update
	env DEBIAN_FRONTEND=noninteractive \
		apt-get install -y --no-install-recommends \
		git bison flex ninja-build valgrind \
		libcap-ng-dev \
		libepoxy-dev \
		libpixman-1-dev \
		libpmem-dev \
		libpulse-dev \
		libsdl2-dev libsdl2-image-dev \
		libslirp-dev \
		libspice-server-dev \
		libusb-1.0-0-dev libusb-dev libusbredirhost-dev \
		libvncserver-dev \
		-o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
	apt-get clean && rm -rf /var/lib/apt/lists/* /var/lib/apt/lists/*
EOT

FROM slim AS full
RUN <<-EOT bash
	set -eu

	apt-get update
	env DEBIAN_FRONTEND=noninteractive \
		apt-get install -y --no-install-recommends \
		python3-venv \
		libaio-dev \
		libbluetooth-dev \
		libbpf-dev \
		libbrlapi-dev \
		libbz2-dev \
		libcacard-dev \
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
		librbd-dev \
		librdmacm-dev \
		libsasl2-dev \
		libseccomp-dev \
		libsnappy-dev \
		libsndio-dev \
		libssh-dev \
		libu2f-udev \
		libunistring-dev \
		libvde-dev \
		libvdeplug-dev \
		libvirglrenderer-dev \
		libvte-2.91-dev libvte-dev \
		libxen-dev \
		libxkbcommon-dev \
		libzstd-dev \
		xfslibs-dev \
		zlib1g-dev \
		-o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
	apt-get clean && rm -rf /var/lib/apt/lists/* /var/lib/apt/lists/*
EOT
