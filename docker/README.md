# Packaging dockerfiles

This folder contains Dockerfiles for building Ring. They are used by
Makefile.packaging, at the root of this repository

## 32bit images

Some of the Dockerfiles refer to 32bit images in the savoirfairelinux docker
hub organization. These images are generated with the following method:


### Debian/Ubuntu

- Download 32bit system iso or image
- Install the system in a container or virtual magine
- Run the following commands from the system:
    * `apt update`
    * `apt upgrade`
    * `apt install git docker.io debootstrap`
    * `git clone https://github.com/moby/moby.git`
    * `./moby/contrib/mkimage.sh -t savoirfairelinux/<distro>32:<distroversion> debootstrap --variant=minbase --arch=i386 <codename>`
    * `docker login`
    * `docker push savoirfairelinux/<distro>32:<distroversion>`

### Fedora

TODO

### Snap

`Dockerfile_snap` is from snapcraft [Dockerfile](snapcraft-Dockerfile)
upstream, under GPLv3-only, and is not considered part of the project.
It was modified to support `core22`.

[stable.Dockerfile]: https://raw.githubusercontent.com/snapcore/snapcraft/main/docker/Dockerfile
