[aguslr/docker-qemu-appimage][1]
================================

[![publish-docker-image](https://github.com/aguslr/docker-qemu-appimage/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/aguslr/docker-qemu-appimage/actions/workflows/docker-publish.yml) [![docker-pulls](https://img.shields.io/docker/pulls/aguslr/qemu-appimage)](https://hub.docker.com/r/aguslr/qemu-appimage) [![image-size](https://img.shields.io/docker/image-size/aguslr/qemu-appimage/latest)](https://hub.docker.com/r/aguslr/qemu-appimage)


This *Docker* image sets up a container to build QEMU AppImages.


Installation
------------

To use *docker-qemu-appimage*, run the container. Any [argument will be passed
to the `configure` script][2] before compiling QEMU:

1. Clone and start the container:

       docker run \
         -v "${PWD}"/input:/input -v "${PWD}"/output:/output \
         docker.io/aguslr/qemu-appimage:latest --target-list=i386-softmmu

2. Find the generated AppImages in `./output`.


### Variables

The image is configured using environment variables passed at runtime:

| Variable    | Function                    | Default | Required |
| :---------- | :-------------------------- | :------ | -------- |
| `APP_NAME`  | Name of the app to package  | `QEMU`  | N        |
| `QEMU_VER`  | Version of QEMU to compile  | `8.0.2` | N        |
| `QEMU_OPTS` | Custom QEMU runtime options | EMPTY   | N        |

Here's an example to create an AppImage for a Pentium 3 machine with 64 MB of
RAM:

    docker run --rm -e 'APP_NAME=Pentium 3' -e 'QEMU_VER=7.2.1' \
      -e 'QEMU_OPTS=qemu-system-i386 -cpu pentium 3 -m 64' \
      -v ${PWD}/output:/output \
      docker.io/aguslr/qemu-appimage:latest --target-list=i386-softmmu


### Disk images

We can place disk images (QCOW2, ISO, raw images, etc.) in an `input` directory
and they will be copied and loaded at runtime:

| Extension | Function    | Device   |
| :-------- | :---------- | :------- |
| `qcow2`   | Hard drive  | `-hda`   |
| `iso`     | CD-ROM      | `-cdrom` |
| `img`     | Floppy disk | `-fda`   |

These files will be read-only, therefore [changes to the disk][3] will be saved
to a *QCOW2* image in a directory named after the AppImage inside
`${XDG_DATA_HOME}/qemu.appimage`, unless we pass the `-snapshot` argument to the
AppImage.


### Examples

- Disable VNC support in QEMU and create an AppImage for a *Sun Solaris 9* disk
   image (located in `./input`):

       docker run --rm -e 'APP_NAME=Solaris 9' \
         -e 'QEMU_OPTS=qemu-system-sparc -M SS-5 -m 256 -vga cg3 -g 1024x768' \
         -v ${PWD}/input:/input -v ${PWD}/output:/output \
         docker.io/aguslr/qemu-appimage:latest \
         --target-list=sparc-softmmu --disable-vnc && \
         ./output/Solaris_9-8.0.2-x86_64.AppImage -snapshot -monitor stdio

<picture>
  <source media="(prefers-color-scheme: light)" srcset="https://github.com/aguslr/docker-qemu-appimage/raw/main/screenshots/solaris9-light.png">
  <source media="(prefers-color-scheme: dark)"  srcset="https://github.com/aguslr/docker-qemu-appimage/raw/main/screenshots/solaris9-dark.png">
  <img title="Solaris 9" alt="solaris9" src="https://github.com/aguslr/docker-qemu-appimage/raw/main/screenshots/solaris9-light.png">
</picture>

- Disable *PulseAudio* and *SLiRP* support in QEMU and create an AppImage for a
  *Mac OS 9* disk image (located in `./input`):

       docker run --rm -e 'APP_NAME=Mac OS 9.2' \
         -e 'QEMU_OPTS=qemu-system-ppc -machine mac99 -m 256 -nic none -g 1024x768x32' \
         -v ${PWD}/input:/input -v ${PWD}/output:/output \
         docker.io/aguslr/qemu-appimage:latest \
         --target-list=ppc-softmmu --disable-pa --disable-slirp && \
         ./output/Mac_OS_9.2-8.0.2-x86_64.AppImage -snapshot -vnc :0

<picture>
  <source media="(prefers-color-scheme: light)" srcset="https://github.com/aguslr/docker-qemu-appimage/raw/main/screenshots/macos9-light.png">
  <source media="(prefers-color-scheme: dark)"  srcset="https://github.com/aguslr/docker-qemu-appimage/raw/main/screenshots/macos9-dark.png">
  <img title="Mac OS 9.2" alt="macos9" src="https://github.com/aguslr/docker-qemu-appimage/raw/main/screenshots/macos9-light.png">
</picture>


Build locally
-------------

Instead of pulling the image from a remote repository, you can build it locally:

1. Clone the repository:

       git clone https://github.com/aguslr/docker-qemu-appimage.git

2. Change into the newly created directory and use `docker-compose` to build and
   launch the container:

       cd docker-qemu-appimage && docker-compose up --build -d


[1]: https://github.com/aguslr/docker-qemu-appimage
[2]: https://github.com/qemu/qemu/blob/45ae97993a75f975f1a01d25564724c7e10a543f/configure#L831
[3]: http://web.archive.org/web/http://dustymabe.com/2015/01/11/qemu-img-backing-files-a-poor-mans-snapshotrollback/
