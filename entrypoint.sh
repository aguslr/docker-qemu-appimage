#!/bin/sh

# Set environment
ARCH="$(uname -m)"
VERSION="${QEMU_VER}"
export ARCH VERSION

# Download QEMU's source code
if [ ! -x ./configure ]; then
	wget "https://download.qemu.org/qemu-${VERSION}.tar.xz" -O - \
		| tar -xJv --strip-components=1 || exit
fi

# Configure QEMU
mkdir build && cd build && \
	../configure \
	--prefix=/usr \
	--enable-strip \
	--enable-sdl \
	--enable-system \
	--disable-user \
	--disable-gtk \
	--disable-gnutls \
	--disable-vte \
	--disable-libssh \
	--disable-smartcard \
	--disable-curses \
	--disable-gcrypt \
	--disable-rdma \
	--disable-tpm \
	--disable-rbd \
	--disable-debug-info \
	--disable-werror \
	"$@" || exit

# Build QEMU
make -j"$(nproc)"

# Install QEMU and clean up
make DESTDIR=/AppDir -j"$(nproc)" install && rm -rf /AppDir/var

# Copy QEMU binaries
find ./*-softmmu -name 'qemu-system-*' -exec cp -vf {} /AppDir/usr/bin/ \;

# Create desktop entry
executable=$(basename /AppDir/usr/bin/qemu-system-*)
mkdir -p /AppDir/usr/share/applications/ && \
	cat <<- EOF > /AppDir/usr/share/applications/qemu.desktop
	[Desktop Entry]
	Name=${APP_NAME:-QEMU}
	Comment=Emulator
	Exec=${executable}
	Terminal=false
	Type=Application
	Icon=qemu
	Categories=System;Emulator;
	EOF

# Create AppRun script
cat <<- 'EOF' > /AppDir/AppRun
#!/bin/sh

HERE="$(dirname "$(readlink -f "${0}")")"

# Set paths
export PATH="${HERE}/usr/bin":${PATH}

# Make sure that XDG_CONFIG_HOME and XDG_DATA_HOME are set
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:=$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:=$HOME/.local/share}"
EOF
# Add images if they exist
[ -f /input/disk.qcow2 ] && printf 'OPTS="${OPTS} -hda ${HERE}/disk.qcow2"'  >> /AppDir/AppRun
[ -f /input/floppy.img ] && printf 'OPTS="${OPTS} -fda ${HERE}/floppy.img"'  >> /AppDir/AppRun
[ -f /input/cdrom.iso ]  && printf 'OPTS="${OPTS} -cdrom ${HERE}/cdrom.iso"' >> /AppDir/AppRun
# Add executable and options
cat <<- EOF >> /AppDir/AppRun

	if [ "\${1}" ]; then
		${executable} \${OPTS} ${QEMU_OPTS} "\${@}"
	else
		${executable} \${OPTS} ${QEMU_OPTS} -snapshot
	fi
EOF
chmod a+x /AppDir/AppRun

# Copy icon
mkdir -p /AppDir/usr/share/icons/hicolor/scalable/apps/
if [ -f /input/icon.svg ]; then
	cp -f /input/icon.svg /AppDir/usr/share/icons/hicolor/scalable/apps/qemu.svg
else
	wget -c -nv \
		'https://gitlab.com/qemu-project/qemu/-/raw/f7da9c17c114417911ac2008d0401084a5030391/pc-bios/qemu_logo_no_text.svg' \
		-O /AppDir/usr/share/icons/hicolor/scalable/apps/qemu.svg
fi

# Copy binaries and images
find /input -type f -iname '*.bin' -exec cp -vf {} /AppDir/ \;
find /input -type f \( -iname '*.qcow2' -or -iname '*.img' -or -iname '*.iso' \) \
	-exec cp -vf {} /AppDir/ \;

# Download AppImage deploy
wget -c -nv \
	"https://github.com/probonopd/linuxdeployqt/releases/download/continuous/linuxdeployqt-continuous-${ARCH}.AppImage" \
	-O ./linuxdeployqt.appimage && \
	chmod a+x linuxdeployqt.appimage

# Extract AppImage
unset QTDIR QT_PLUGIN_PATH LD_LIBRARY_PATH
./linuxdeployqt.appimage --appimage-extract && \
	./squashfs-root/AppRun /AppDir/usr/share/applications/*.desktop -bundle-non-qt-libs && \
	./squashfs-root/AppRun /AppDir/usr/share/applications/*.desktop -appimage && \
	find /AppDir -executable -type f -exec ldd {} \; | grep " => /usr" | cut -d " " -f 2-3 | sort | uniq

# Move generated AppImages
mv -vf ./*.AppImage /output
