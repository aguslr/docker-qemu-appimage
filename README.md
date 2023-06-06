[aguslr/docker-qemu-appimage][1]
================================

[![publish-docker-image](https://github.com/aguslr/docker-qemu-appimage/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/aguslr/docker-qemu-appimage/actions/workflows/docker-publish.yml) [![docker-pulls](https://img.shields.io/docker/pulls/aguslr/qemu-appimage)](https://hub.docker.com/r/aguslr/qemu-appimage) [![image-size](https://img.shields.io/docker/image-size/aguslr/qemu-appimage/latest)](https://hub.docker.com/r/aguslr/qemu-appimage)


This *Docker* image sets up a container to build QEMU AppImages.


Installation
------------

To use *docker-qemu-appimage*, run the container. Any [argument will be passed
to the `configure` script][2] before compiling QEMU:

1. Clone and start the container:

       docker run -v "${PWD}"/output:/output \
         docker.io/aguslr/qemu-appimage:latest --target-list=i386-softmmu

2. Find the generated AppImage in `./output`.


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
