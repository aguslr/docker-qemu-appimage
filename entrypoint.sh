#!/bin/sh

# Set environment
ARCH="$(uname -m)"
VERSION="${QEMU_VER}"
export ARCH VERSION

# Download QEMU's source code
if [ ! -x ./configure ]; then
	wget "https://download.qemu.org/qemu-${VERSION}.tar.xz" -O - \
		| tar -xJv --strip-components=1 || exit
elif [ -f ./VERSION ]; then
	VERSION=$(cat ./VERSION)
fi

# Configure and build QEMU
if [ ! -d ./build ]; then
	mkdir build && cd build && \
		../configure \
		--prefix=/usr \
		--enable-strip \
		--enable-system \
		--disable-user \
		--disable-debug-info \
		--disable-werror \
		"$@" || exit
	make -j"$(nproc)"
else
	cd ./build || exit
fi

# Download AppImage deploy
wget -c -nv \
	"https://github.com/probonopd/linuxdeployqt/releases/download/continuous/linuxdeployqt-continuous-${ARCH}.AppImage" \
	-O /usr/local/bin/linuxdeployqt.appimage && \
	chmod a+x /usr/local/bin/linuxdeployqt.appimage

# Extract AppImage deploy
(cd /opt && /usr/local/bin/linuxdeployqt.appimage --appimage-extract)

# Get QEMU binaries
case "${QEMU_OPTS%% *}" in
	qemu-system*)
		executable="${QEMU_OPTS%% *}"
		QEMU_OPTS="${QEMU_OPTS#* }"
		;;
esac

# Function to generate AppImage
makeAppImage() {

	# Cleanup AppDir
	mkdir -p /AppDir && (cd /AppDir && rm -rf -- ./* ./.??*)

	# Get executable
	executable="${1}"

	# Install QEMU and clean up
	make DESTDIR=/AppDir -j"$(nproc)" install && rm -rf /AppDir/var

	# Copy QEMU binary
	find ./*-softmmu -name "${executable}" -exec cp -vf {} /AppDir/usr/bin/ \;

	# Create desktop entry
	mkdir -p /AppDir/usr/share/applications/ && \
		cat <<- EOF > /AppDir/usr/share/applications/qemu.desktop
		[Desktop Entry]
		Name=${NAME}
		Comment=Emulator
		Exec=${executable}
		Terminal=false
		Type=Application
		Icon=qemu
		Categories=System;Emulator;
		EOF

	# Create AppRun script
	cat << '	EOF' | sed -r 's/^\t//' > /AppDir/AppRun
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
	XDG_CONFIG_HOME="${XDG_CONFIG_HOME:=$HOME/.config}"
	XDG_DATA_HOME="${XDG_DATA_HOME:=$HOME/.local/share}"
	export XDG_CONFIG_HOME XDG_DATA_HOME

	# Set data directory
	QEMU_DATA="${XDG_DATA_HOME}/qemu.appimage/${APPIMAGE_NAME:-QEMU}"

	# Check arguments
	for ARG in "${@}"; do
		[ "${ARG}" = '-snapshot' ] && SNAPSHOT=1
	done

	# Create backing files for disk images
	for disk in "${HERE}"/hd?.qcow2; do
		# Check file exists
		[ -f "${disk}" ] || continue
		# Get filename
		diskname="$(basename "${disk}")"
		# Get devicename
		device="${diskname%.*}"
		# Check for backing file
		if [ -f "${QEMU_DATA}/${diskname}" ]; then
			# Rebase backing file
			qemu-img rebase -f qcow2 -u -b "${disk}" -F qcow2 \
				"${QEMU_DATA}/${diskname}" \
				&& OPTS="${OPTS} -${device} ${QEMU_DATA}/${diskname}" \
				|| OPTS="${OPTS} -${device} ${disk}"
		elif [ ! "${SNAPSHOT}" ]; then
			# Create data directory
			mkdir -p "${QEMU_DATA}"
			# Create disk image
			qemu-img create -f qcow2 -b "${disk}" -F qcow2 \
				"${QEMU_DATA}/${diskname}" \
				&& OPTS="${OPTS} -${device} ${QEMU_DATA}/${diskname}" \
				|| OPTS="${OPTS} -${device} ${disk}"
		else
			OPTS="${OPTS} -${device} ${disk}"
		fi
	done

	# Add options for other floppy images
	for floppy in "${HERE}"/fd?.img; do
		# Check file exists
		[ -f "${floppy}" ] || continue
		# Get filename
		floppyname="$(basename "${floppy}")"
		# Get devicename
		device="${floppyname%.*}"
		OPTS="${OPTS} -${device} ${floppy}"
	done

	# Add options for CD image
	[ -f "${HERE}/cdrom.iso" ] && OPTS="${OPTS} -cdrom ${HERE}/cdrom.iso"

	EOF

	# Add executable and options
	cat <<- EOF >> /AppDir/AppRun
	# Run QEMU
	${executable} ${QEMU_OPTS} \${OPTS} "\${@}"
	EOF
	chmod a+x /AppDir/AppRun

	# Set App icon
	if [ -f /input/icon.svg ]; then
		# Clean up existing icons
		rm -rf /AppDir/usr/share/icons/hicolor
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
		# Clean up existing icons
		rm -rf /AppDir/usr/share/icons/hicolor
		# Create icon directory
		mkdir -p /AppDir/usr/share/icons/hicolor/"${icon_dir}"/apps/
		# Copy PNG icons
		cp -f /input/icon.png /AppDir/usr/share/icons/hicolor/"${icon_dir}"/apps/qemu.png
		cp -f /input/icon.png /AppDir/qemu.png
	fi

	# Copy binaries and images
	find /input -type f -iname '*.bin' -exec cp -vf {} /AppDir/ \;
	find /input -type f \( -iname '*.qcow2' -or -iname '*.img' -or -iname '*.iso' \) \
		-exec cp -vf {} /AppDir/ \;

	# Create AppImage
	unset QTDIR QT_PLUGIN_PATH LD_LIBRARY_PATH
	(
		cd /opt && \
			./squashfs-root/AppRun /AppDir/usr/share/applications/*.desktop -bundle-non-qt-libs && \
			./squashfs-root/AppRun /AppDir/usr/share/applications/*.desktop -appimage && \
			find /AppDir -executable -type f -exec ldd {} \; | grep " => /usr" | cut -d " " -f 2-3 | sort | uniq
		mv -vf ./*.AppImage /output
	)

}

# Configure AppDir
if [ "${executable}" ]; then
		# Set name
		NAME="${APP_NAME:-$executable}"
		# Run function
		makeAppImage "${executable}"
else
	find ./*-softmmu -name 'qemu-system-*' -print \
		| while IFS= read -r file; do
		# Set executable
		executable="$(basename "${file}")"
		# Set name
		NAME="${APP_NAME:-$executable}"
		# Run function
		makeAppImage "${executable}"
	done
fi
