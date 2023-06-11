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

# Configure and build QEMU
if [ ! -d ./build ]; then
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
	make -j"$(nproc)"
else
	cd ./build || exit
fi

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
	Actions=ReadOnly;

	[Desktop Action ReadOnly]
	Name=New Window with a temporary disk
	Exec=${executable} -snapshot
	EOF

# Create AppRun script
cat << 'EOF' > /AppDir/AppRun
#!/bin/sh

# Set environment
HERE="$(dirname "$(readlink -f "${0}")")"
APPIMAGE=$(basename "$ARGV0")
APPIMAGE_NAME="${APPIMAGE%.*}"

# Set paths
PATH="${HERE}/usr/bin":${PATH}
LD_LIBRARY_PATH="${HERE}/usr/lib":${LD_LIBRARY_PATH}
export PATH LD_LIBRARY_PATH

# Make sure that XDG_CONFIG_HOME and XDG_DATA_HOME are set
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:=$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:=$HOME/.local/share}"

# Check arguments
for ARG in "${@}"; do
	[ "${ARG}" = '-snapshot' ] && SNAPSHOT=1
done

# Create file for disk image
if [ -f "${HERE}/disk.qcow2" ]; then
	# Check for disk image
	if [ -f "${QEMU_DATA}/disk.qcow2" ]; then
		# Create directory structure
		QEMU_DATA="${XDG_DATA_HOME}/qemu.appimage/${APPIMAGE_NAME:-QEMU}" && \
			mkdir -p "${QEMU_DATA}"
		# Rebase backing file
		qemu-img rebase -f qcow2 -u -b "${HERE}/disk.qcow2" -F qcow2 \
			"${QEMU_DATA}/disk.qcow2" \
			&& OPTS="${OPTS} -hda ${QEMU_DATA}/disk.qcow2" \
			|| OPTS="${OPTS} -hda ${HERE}/disk.qcow2"
	elif [ ! "${SNAPSHOT}" ]; then
		# Create directory structure
		QEMU_DATA="${XDG_DATA_HOME}/qemu.appimage/${APPIMAGE_NAME:-QEMU}" && \
			mkdir -p "${QEMU_DATA}"
		# Create disk image
		qemu-img create -f qcow2 -b "${HERE}/disk.qcow2" -F qcow2 \
			"${QEMU_DATA}/disk.qcow2" \
			&& OPTS="${OPTS} -hda ${QEMU_DATA}/disk.qcow2" \
			|| OPTS="${OPTS} -hda ${HERE}/disk.qcow2"
	else
		OPTS="${OPTS} -hda ${HERE}/disk.qcow2"
	fi
fi

# Add options for other images
[ -f "${HERE}/floppy.img" ] && OPTS="${OPTS} -fda ${HERE}/floppy.img"
[ -f "${HERE}/cdrom.iso" ]  && OPTS="${OPTS} -cdrom ${HERE}/cdrom.iso"

EOF
# Add executable and options
cat << EOF >> /AppDir/AppRun
# Run QEMU
${executable} \${OPTS} ${QEMU_OPTS} "\${@}"
EOF
chmod a+x /AppDir/AppRun

# Clean up existing icons
rm -rf /AppDir/usr/share/icons/hicolor
# Set App icon
if [ -f /input/icon.svg ]; then
	# Create icon directory
	mkdir -p /AppDir/usr/share/icons/hicolor/scalable/apps/
	# Copy SVG file to icon directory
	cp -f /input/icon.svg /AppDir/usr/share/icons/hicolor/scalable/apps/qemu.svg
	# Generate PNG icon
	convert -gravity center -background none -size 256x256^ -extent 256x256^ \
		/AppDir/usr/share/icons/hicolor/scalable/apps/qemu.svg /AppDir/qemu.png
elif [ -f /input/icon.png ]; then
	# Get PNG icon size
	icon_dir="$(identify -format "%wx%h" /input/icon.png)"
	# Create icon directory
	mkdir -p /AppDir/usr/share/icons/hicolor/"${icon_dir}"/apps/
	# Copy PNG icons
	cp -f /input/icon.png /AppDir/usr/share/icons/hicolor/"${icon_dir}"/apps/qemu.png
	cp -f /input/icon.png /AppDir/qemu.png
else
	# Create icon directory
	mkdir -p /AppDir/usr/share/icons/hicolor/scalable/apps/
	# Download SVG file to icon directory
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
