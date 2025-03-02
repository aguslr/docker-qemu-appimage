#!/bin/sh

# Check arguments for a command shell
case "${1}" in
	sh|bash)
		command -v "${1}" >/dev/null && ${1}
		exit
		;;
	/bin/sh|/bin/bash)
		[ -x "${1}" ] && ${1}
		exit
		;;
esac

# Set environment
ARCH="$(uname -m)"
VERSION="${QEMU_VER}"
export ARCH VERSION

# Check for provided QEMU executable
case "${QEMU_OPTS%% *}" in
	qemu-system*)
		executable="${QEMU_OPTS%% *}"
		QEMU_OPTS="${QEMU_OPTS#* }"
		;;
esac

# Function to generate AppImage
makeAppImage() {

	# Get executable
	executable="${1}" || return

	# Cleanup AppDir
	mkdir -p /AppDir || return
	(cd /AppDir && rm -rf -- ./* ./.??*)

	# Install QEMU and clean up
	make DESTDIR=/AppDir -j"$(nproc)" install && rm -rf /AppDir/var

	# Remove unnecessary QEMU binaries
	find /AppDir -executable -type f \
		\( -name 'qemu-system-*' -and -not -name "${executable}" \) -delete

	# Create desktop entry
	mkdir -p /AppDir/usr/share/applications/ || return
	cat <<- EOF > /AppDir/usr/share/applications/qemu.desktop
	[Desktop Entry]
	Name=${NAME}
	Comment=Emulator
	Exec=${executable}
	Terminal=false
	Type=Application
	Icon=qemu
	Categories=System;Emulator;X-QEMU-AppImage;
	EOF

	# Create AppRun script
	cat << '	EOF' | sed -r 's/^\t//' > /AppDir/AppRun
	#!/bin/sh

	# Set environment
	HERE="${0%/*}"
	APPIMAGE="${ARGV0##*/}"
	APPIMAGE_NAME="${APPIMAGE%.*}"

	# Set paths
	PATH="${HERE}/usr/bin":${PATH}
	LD_LIBRARY_PATH="${HERE}/usr/lib":${LD_LIBRARY_PATH}
	export PATH LD_LIBRARY_PATH

	# Check if AppImage's portable home was set
	if [ "${HOME##*/}" = "${APPIMAGE}.home" ]; then
		# Set data directory
		QEMU_DATA="${HOME}"
	else
		# Set data directory
		XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
		QEMU_DATA="${XDG_DATA_HOME}/qemu.appimage/${APPIMAGE_NAME:-QEMU}"
	fi

	# Check arguments for a command
	case "${1}" in
		--command=list)
			for bin in "${HERE}/usr/bin"/*; do
				echo "${bin##*/}"
			done
			exit
			;;
		--command=*)
			command="${1##*=}" && shift
			[ -x "${HERE}/usr/bin/${command}" ] && ${command} "${@}"
			exit
			;;
	esac

	# Add options for BIOS
	if [ -f "${HERE}/bios.bin" ]; then
		OPTS="${OPTS} -bios ${HERE}/bios.bin"
	elif [ -f "${HERE}/bios.rom" ]; then
		OPTS="${OPTS} -bios ${HERE}/bios.rom"
	fi

	# Check arguments for `-snapshot`
	for ARG in "${@}"; do
		[ "${ARG}" = '-snapshot' ] && SNAPSHOT=1
	done

	# Create backing files for disk images
	for disk in "${HERE}"/hd?.qcow2; do
		# Check file exists
		[ -f "${disk}" ] || continue
		# Get filename
		diskname="${disk##*/}"
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
			mkdir -p "${QEMU_DATA}" || exit
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
		floppyname="${floppy##*/}"
		# Get devicename
		device="${floppyname%.*}"
		OPTS="${OPTS} -${device} ${floppy}"
	done

	# Add options for CD image
	[ -f "${HERE}/cdrom.iso" ] && OPTS="${OPTS} -cdrom ${HERE}/cdrom.iso"

	EOF

	# Add executable and options
	if [ "${APP_NAME}" ]; then
		cat <<- EOF >> /AppDir/AppRun
		# Run QEMU
		${executable} ${QEMU_OPTS} -name "${APP_NAME}" \${OPTS} "\${@}"
		EOF
	else
		cat <<- EOF >> /AppDir/AppRun
		# Run QEMU
		${executable} ${QEMU_OPTS} \${OPTS} "\${@}"
		EOF
	fi
	chmod a+x /AppDir/AppRun

	# Set App icon
	if [ -f /input/icon.svg ]; then
		# Clean up existing icons
		rm -rf /AppDir/usr/share/icons/hicolor
		# Create icon directory
		mkdir -p /AppDir/usr/share/icons/hicolor/scalable/apps/ || exit
		# Copy SVG file to icon directory
		cp -f /input/icon.svg /AppDir/usr/share/icons/hicolor/scalable/apps/qemu.svg
		# Generate PNG icon
		convert -gravity center -background none -size 256x256^ -extent 256x256^ \
			/AppDir/usr/share/icons/hicolor/scalable/apps/qemu.svg /AppDir/qemu.png
		# Set icon file variable
		icon_file=/AppDir/usr/share/icons/hicolor/scalable/apps/qemu.svg
	elif [ -f /input/icon.png ]; then
		# Get PNG icon size
		icon_dir="$(identify -format "%wx%h" /input/icon.png)"
		# Clean up existing icons
		rm -rf /AppDir/usr/share/icons/hicolor
		# Create icon directory
		mkdir -p /AppDir/usr/share/icons/hicolor/"${icon_dir}"/apps/ || exit
		# Copy PNG icons
		cp -f /input/icon.png /AppDir/usr/share/icons/hicolor/"${icon_dir}"/apps/qemu.png
		cp -f /input/icon.png /AppDir/qemu.png
		# Set icon file variable
		icon_file=/AppDir/usr/share/icons/hicolor/"${icon_dir}"/apps/qemu.png
	else
		# Set icon file variable
		icon_file=/AppDir/usr/share/icons/hicolor/scalable/apps/qemu.svg
	fi

	# Copy binaries and images
	find /input -type f -iname '*.fd' -exec cp -vf {} /AppDir/ \;
	find /input -type f \( -iname '*.bin' -or -iname '*.rom' \) \
		-exec cp -vf {} /AppDir/ \;
	find /input -type f \( -iname '*.qcow2' -or -iname '*.img' -or -iname '*.iso' \) \
		-exec cp -vf {} /AppDir/ \;

	# Create AppImage
	unset QTDIR QT_PLUGIN_PATH LD_LIBRARY_PATH
	(
		cd /opt/linuxdeploy && \
			./squashfs-root/AppRun \
			--appdir /AppDir \
			--desktop-file /AppDir/usr/share/applications/*.desktop \
			--executable /AppDir/usr/bin/"${executable}" \
			--icon-file "${icon_file}" \
			--output appimage && \
			find /AppDir -executable -type f -exec ldd {} \; | grep " => /usr" | cut -d " " -f 2-3 | sort | uniq
		mv -vf ./*.AppImage /output
	)

}

# Download QEMU's source code
if [ ! -x ./configure ]; then
	if [ -f "/qemu-${VERSION}.tar.xz" ]; then
		tar -xJv --strip-components=1 -f "/qemu-${VERSION}.tar.xz" || exit
	else
		wget "https://download.qemu.org/qemu-${VERSION}.tar.xz" -O - \
			| tar -xJv --strip-components=1 || exit
	fi
elif [ -f ./VERSION ]; then
	VERSION=$(cat ./VERSION)
fi

# Configure and build QEMU
if [ ! -d ./build ]; then
	mkdir ./build || exit
	cd ./build && \
		../configure \
		--prefix=/usr \
		--enable-strip \
		--enable-system \
		--enable-tools \
		--disable-user \
		--disable-debug-info \
		--disable-werror \
		"$@" || exit
	make -j"$(nproc)" || exit
else
	cd ./build || exit
fi

# Configure AppDir
if [ "${executable}" ]; then
		# Set name
		NAME="${APP_NAME:-$executable}"
		# Run function
		makeAppImage "${executable}"
else
	find ./*-softmmu -name 'qemu-system-*' -print | while IFS= read -r file; do
		# Set executable
		executable="$(basename "${file}")"
		# Set name
		NAME="${APP_NAME:-$executable}"
		# Run function
		makeAppImage "${executable}"
	done
fi
