#!/usr/bin/env python3
#
# Copyright (C) 2016-2017 Savoir-faire Linux Inc.
#
# Author: Alexandre Viau <alexandre.viau@savoirfairelinux.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Creates packaging targets for a distribution and architecture.
# This helps reduce the length of the top Makefile.
#

import argparse

target_template = """\
##
## Distro: %(distribution)s
##

# We don't simply use jami-packaging-distro as the docker image name because
# we want to be able to build multiple versions of the same distro at the
# same time and it could result in race conditions on the machine as we would
# overwrite the docker image of other builds.
#
# This does not impact caching as the docker daemon does not care about the image
# names, just about the contents of the Dockerfile.
PACKAGE_%(distribution)s_DOCKER_IMAGE_NAME:=jami-packaging-%(distribution)s$(RING_PACKAGING_IMAGE_SUFFIX)
PACKAGE_%(distribution)s_DOCKER_IMAGE_FILE:=.docker-image-$(PACKAGE_%(distribution)s_DOCKER_IMAGE_NAME)
DOCKER_EXTRA_ARGS =
QEMU_STATIC_%(distribution)s = %(qemu_static)s

PACKAGE_%(distribution)s_DOCKER_RUN_COMMAND = docker run \\
    --rm \\
    -e RELEASE_VERSION=$(RELEASE_VERSION) \\
    -e RELEASE_TARBALL_FILENAME=$(RELEASE_TARBALL_FILENAME) \\
    -e DEBIAN_VERSION=%(version)s \\
    -e DEBIAN_PACKAGING_OVERRIDE=%(debian_packaging_override)s \\
    -e CURRENT_UID=$(CURRENT_UID) \\
    -e DISTRIBUTION=%(distribution)s \\
    -v $(CURDIR):/opt/ring-project-ro:ro \\
    -v $(CURDIR)/packages/%(distribution)s:/opt/output \\
    -t $(DOCKER_EXTRA_ARGS) %(options)s \\
    $(PACKAGE_%(distribution)s_DOCKER_IMAGE_NAME)

# FIXME: dirty qemu-static hack required because our Jenkis node runs Docker 17
# Remove all the qemu-static / QEMU-STATIC stuff as soon as we get Docker 18 +
QEMU_STATIC_%(distribution)s:
	if [ ! -z $(QEMU_STATIC_%(distribution)s) ]; then mkdir -p qemu-static && cp -af /usr/bin/$(QEMU_STATIC_%(distribution)s) qemu-static/; fi

$(PACKAGE_%(distribution)s_DOCKER_IMAGE_FILE): QEMU_STATIC_%(distribution)s docker/Dockerfile_%(docker_image)s
	docker build \\
        -t $(PACKAGE_%(distribution)s_DOCKER_IMAGE_NAME) \\
        -f docker/Dockerfile_%(docker_image)s %(password_rhel8)s \\
        $(CURDIR)
	touch $(PACKAGE_%(distribution)s_DOCKER_IMAGE_FILE)

packages/%(distribution)s:
	mkdir -p packages/%(distribution)s

packages/%(distribution)s/%(output_file)s: $(RELEASE_TARBALL_FILENAME) packages/%(distribution)s $(PACKAGE_%(distribution)s_DOCKER_IMAGE_FILE)
	$(PACKAGE_%(distribution)s_DOCKER_RUN_COMMAND)
	touch packages/%(distribution)s/*

.PHONY: package-%(distribution)s
package-%(distribution)s: packages/%(distribution)s/%(output_file)s

.PHONY: package-%(distribution)s-interactive
package-%(distribution)s-interactive: DOCKER_EXTRA_ARGS = -i
package-%(distribution)s-interactive: $(RELEASE_TARBALL_FILENAME) packages/%(distribution)s $(PACKAGE_%(distribution)s_DOCKER_IMAGE_FILE)
	$(PACKAGE_%(distribution)s_DOCKER_RUN_COMMAND) bash
"""


def generate_target(distribution, debian_packaging_override, output_file, options='', docker_image='', version='', qemu_static='', password_rhel8 = ''):
    if (docker_image == ''):
        docker_image = distribution
    if (docker_image == 'rhel_8'):
        password_rhel8 = password_rhel8
    if (version == ''):
        version = "$(DEBIAN_VERSION)"
    return target_template % {
        "distribution": distribution,
        "docker_image": docker_image,
        "debian_packaging_override": debian_packaging_override,
        "output_file": output_file,
        "options": options,
        "version": version,
        "qemu_static": qemu_static,
        "password_rhel8": password_rhel8,
    }


def run_generate(parsed_args):
    print(generate_target(parsed_args.distribution,
                          parsed_args.debian_packaging_override,
                          parsed_args.output_file,
                          parsed_args.options,
                          parsed_args.docker_image,
                          parsed_args.version,
                          parsed_args.qemu_static))


def run_generate_all(parsed_args):
    targets = [
        # Debian
        {
            "distribution": "debian_9",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
        },
        {
            "distribution": "debian_9_i386",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
        },
        {
            "distribution": "debian_9_armhf",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
            "options": "--privileged --security-opt apparmor=docker-default",
            "qemu_static": 'qemu-arm-static',
        },
        {
            "distribution": "debian_9_arm64",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
            "options": "--privileged --security-opt apparmor=docker-default",
            "qemu_static": 'qemu-aarch64-static',
        },
        {
            "distribution": "debian_9_oci",
            "docker_image": "debian_9",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_OCI_DSC_FILENAME)",
            "options": "-e OVERRIDE_PACKAGING_DIR=$(DEBIAN_OCI_PKG_DIR)",
            "version": "$(DEBIAN_OCI_VERSION)",
        },
        {
            "distribution": "debian_9_i386_oci",
            "docker_image": "debian_9_i386",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_OCI_DSC_FILENAME)",
            "options": "-e OVERRIDE_PACKAGING_DIR=$(DEBIAN_OCI_PKG_DIR)",
            "version": "$(DEBIAN_OCI_VERSION)",
        },
        {
            "distribution": "debian_9_armhf_oci",
            "docker_image": "debian_9_armhf",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
            "options": "-e OVERRIDE_PACKAGING_DIR=$(DEBIAN_OCI_PKG_DIR) --privileged --security-opt apparmor=docker-default",
            "version": "$(DEBIAN_OCI_VERSION)",
            "qemu_static": 'qemu-arm-static',
        },
        {
            "distribution": "debian_9_arm64_oci",
            "docker_image": "debian_9_arm64",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
            "options": "-e OVERRIDE_PACKAGING_DIR=$(DEBIAN_OCI_PKG_DIR) --privileged --security-opt apparmor=docker-default",
            "version": "$(DEBIAN_OCI_VERSION)",
            "qemu_static": 'qemu-aarch64-static',
        },
        {
            "distribution": "debian_10",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
            "options": "--privileged --security-opt apparmor=docker-default",
        },
        {
            "distribution": "debian_10_i386",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
            "options": "--privileged --security-opt apparmor=docker-default",
        },
        {
            "distribution": "debian_10_armhf",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
            "options": "--privileged --security-opt apparmor=docker-default",
            "qemu_static": 'qemu-arm-static',
        },
        {
            "distribution": "debian_10_arm64",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
            "options": "--privileged --security-opt apparmor=docker-default",
            "qemu_static": 'qemu-aarch64-static',
        },
        {
            "distribution": "debian_10_oci",
            "docker_image": "debian_10",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_OCI_DSC_FILENAME)",
            "options": "-e OVERRIDE_PACKAGING_DIR=$(DEBIAN_OCI_PKG_DIR) --privileged --security-opt apparmor=docker-default",
            "version": "$(DEBIAN_OCI_VERSION)",
        },
        {
            "distribution": "debian_10_i386_oci",
            "docker_image": "debian_10_i386",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_OCI_DSC_FILENAME)",
            "options": "-e OVERRIDE_PACKAGING_DIR=$(DEBIAN_OCI_PKG_DIR) --privileged --security-opt apparmor=docker-default",
            "version": "$(DEBIAN_OCI_VERSION)",
        },
        {
            "distribution": "debian_10_armhf_oci",
            "docker_image": "debian_10_armhf",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
            "options": "-e OVERRIDE_PACKAGING_DIR=$(DEBIAN_OCI_PKG_DIR) --privileged --security-opt apparmor=docker-default",
            "version": "$(DEBIAN_OCI_VERSION)",
            "qemu_static": 'qemu-arm-static',
        },
        {
            "distribution": "debian_10_arm64_oci",
            "docker_image": "debian_10_arm64",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
            "options": "-e OVERRIDE_PACKAGING_DIR=$(DEBIAN_OCI_PKG_DIR) --privileged --security-opt apparmor=docker-default",
            "version": "$(DEBIAN_OCI_VERSION)",
            "qemu_static": 'qemu-aarch64-static',
        },
        # Raspbian
        {
            "distribution": "raspbian_10_armhf",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
            "options": "--privileged --security-opt apparmor=docker-default",
            "qemu_static": 'qemu-arm-static',
        },
        {
            "distribution": "raspbian_10_armhf_oci",
            "docker_image": "raspbian_10_armhf",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
            "options": "-e OVERRIDE_PACKAGING_DIR=$(DEBIAN_OCI_PKG_DIR) --privileged --security-opt apparmor=docker-default",
            "version": "$(DEBIAN_OCI_VERSION)",
            "qemu_static": 'qemu-arm-static',
        },
        # Ubuntu
        {
            "distribution": "ubuntu_16.04",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
        },
        {
            "distribution": "ubuntu_16.04_i386",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
        },
        {
            "distribution": "ubuntu_16.04_oci",
            "docker_image": "ubuntu_16.04",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_OCI_DSC_FILENAME)",
            "options": "-e OVERRIDE_PACKAGING_DIR=$(DEBIAN_OCI_PKG_DIR)",
            "version": "$(DEBIAN_OCI_VERSION)",
        },
        {
            "distribution": "ubuntu_16.04_i386_oci",
            "docker_image": "ubuntu_16.04_i386",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_OCI_DSC_FILENAME)",
            "options": "-e OVERRIDE_PACKAGING_DIR=$(DEBIAN_OCI_PKG_DIR)",
            "version": "$(DEBIAN_OCI_VERSION)",
        },
        {
            "distribution": "ubuntu_18.04",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
        },
        {
            "distribution": "ubuntu_18.04_i386",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
        },
        {
            "distribution": "ubuntu_18.04_oci",
            "docker_image": "ubuntu_18.04",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_OCI_DSC_FILENAME)",
            "options": "-e OVERRIDE_PACKAGING_DIR=$(DEBIAN_OCI_PKG_DIR)",
            "version": "$(DEBIAN_OCI_VERSION)",
        },
        {
            "distribution": "ubuntu_18.04_i386_oci",
            "docker_image": "ubuntu_18.04_i386",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_OCI_DSC_FILENAME)",
            "options": "-e OVERRIDE_PACKAGING_DIR=$(DEBIAN_OCI_PKG_DIR)",
            "version": "$(DEBIAN_OCI_VERSION)",
        },
        {
            "distribution": "ubuntu_18.10",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
            "options": "--privileged --security-opt apparmor=docker-default",
        },
        {
            "distribution": "ubuntu_18.10_i386",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
            "options": "--privileged --security-opt apparmor=docker-default",
        },
        {
            "distribution": "ubuntu_18.10_oci",
            "docker_image": "ubuntu_18.10",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_OCI_DSC_FILENAME)",
            "options": "-e OVERRIDE_PACKAGING_DIR=$(DEBIAN_OCI_PKG_DIR) --privileged --security-opt apparmor=docker-default",
            "version": "$(DEBIAN_OCI_VERSION)",
        },
        {
            "distribution": "ubuntu_18.10_i386_oci",
            "docker_image": "ubuntu_18.10_i386",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_OCI_DSC_FILENAME)",
            "options": "-e OVERRIDE_PACKAGING_DIR=$(DEBIAN_OCI_PKG_DIR) --privileged --security-opt apparmor=docker-default",
            "version": "$(DEBIAN_OCI_VERSION)",
        },
        {
            "distribution": "ubuntu_19.04",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
            "options": "--privileged --security-opt apparmor=docker-default",
        },
        {
            "distribution": "ubuntu_19.04_i386",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
            "options": "--privileged --security-opt apparmor=docker-default",
        },
        {
            "distribution": "ubuntu_19.04_oci",
            "docker_image": "ubuntu_19.04",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_OCI_DSC_FILENAME)",
            "options": "-e OVERRIDE_PACKAGING_DIR=$(DEBIAN_OCI_PKG_DIR) --privileged --security-opt apparmor=docker-default",
            "version": "$(DEBIAN_OCI_VERSION)",
        },
        {
            "distribution": "ubuntu_19.04_i386_oci",
            "docker_image": "ubuntu_19.04_i386",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_OCI_DSC_FILENAME)",
            "options": "-e OVERRIDE_PACKAGING_DIR=$(DEBIAN_OCI_PKG_DIR) --privileged --security-opt apparmor=docker-default",
            "version": "$(DEBIAN_OCI_VERSION)",
        },
        {
            "distribution": "ubuntu_19.10",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
            "options": "--privileged --security-opt apparmor=docker-default",
        },
        {
            "distribution": "ubuntu_19.10_i386",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
            "options": "--privileged --security-opt apparmor=docker-default",
        },
        {
            "distribution": "ubuntu_19.10_oci",
            "docker_image": "ubuntu_19.10",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_OCI_DSC_FILENAME)",
            "options": "-e OVERRIDE_PACKAGING_DIR=$(DEBIAN_OCI_PKG_DIR) --privileged --security-opt apparmor=docker-default",
            "version": "$(DEBIAN_OCI_VERSION)",
        },
        {
            "distribution": "ubuntu_19.10_i386_oci",
            "docker_image": "ubuntu_19.10_i386",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_OCI_DSC_FILENAME)",
            "options": "-e OVERRIDE_PACKAGING_DIR=$(DEBIAN_OCI_PKG_DIR) --privileged --security-opt apparmor=docker-default",
            "version": "$(DEBIAN_OCI_VERSION)",
        },
        {
            "distribution": "ubuntu_20.04",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
            "options": "--privileged --security-opt apparmor=docker-default",
        },
        {
            "distribution": "ubuntu_20.04_oci",
            "docker_image": "ubuntu_20.04",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_OCI_DSC_FILENAME)",
            "options": "-e OVERRIDE_PACKAGING_DIR=$(DEBIAN_OCI_PKG_DIR) --privileged --security-opt apparmor=docker-default",
            "version": "$(DEBIAN_OCI_VERSION)",
        },

        # Fedora
        {
            "distribution": "fedora_27",
            "debian_packaging_override": "",
            "output_file": ".packages-built",
        },
        {
            "distribution": "fedora_27_i386",
            "debian_packaging_override": "",
            "output_file": ".packages-built",
        },
        {
            "distribution": "fedora_28",
            "debian_packaging_override": "",
            "output_file": ".packages-built",
            "options": "--security-opt seccomp=./docker/profile-seccomp-fedora_28.json --privileged",
        },
        {
            "distribution": "fedora_28_i386",
            "debian_packaging_override": "",
            "output_file": ".packages-built",
            "options": "--security-opt seccomp=./docker/profile-seccomp-fedora_28.json --privileged",
        },
        {
            "distribution": "fedora_29",
            "debian_packaging_override": "",
            "output_file": ".packages-built",
            "options": "--security-opt seccomp=./docker/profile-seccomp-fedora_28.json --privileged",
        },
        {
            "distribution": "fedora_29_i386",
            "debian_packaging_override": "",
            "output_file": ".packages-built",
            "options": "--security-opt seccomp=./docker/profile-seccomp-fedora_28.json --privileged",
        },
        {
            "distribution": "fedora_30",
            "debian_packaging_override": "",
            "output_file": ".packages-built",
            "options": "--security-opt seccomp=./docker/profile-seccomp-fedora_28.json --privileged",
        },
        {
            "distribution": "fedora_30_i386",
            "debian_packaging_override": "",
            "output_file": ".packages-built",
            "options": "--security-opt seccomp=./docker/profile-seccomp-fedora_28.json --privileged",
        },
        {
            "distribution": "fedora_31",
            "debian_packaging_override": "",
            "output_file": ".packages-built",
            "options": "--security-opt seccomp=./docker/profile-seccomp-fedora_28.json --privileged",
        },
        {
            "distribution": "fedora_31_i386",
            "debian_packaging_override": "",
            "output_file": ".packages-built",
            "options": "--security-opt seccomp=./docker/profile-seccomp-fedora_28.json --privileged",
        },
        {
            "distribution": "fedora_32",
            "debian_packaging_override": "",
            "output_file": ".packages-built",
            "options": "--security-opt seccomp=./docker/profile-seccomp-fedora_28.json --privileged",
        },
        {
            "distribution": "fedora_32_i386",
            "debian_packaging_override": "",
            "output_file": ".packages-built",
            "options": "--security-opt seccomp=./docker/profile-seccomp-fedora_28.json --privileged",
        },
        {
            "distribution": "rhel_8",
            "debian_packaging_override": "",
            "output_file": ".packages-built",
            "options": "--security-opt seccomp=./docker/profile-seccomp-fedora_28.json --privileged",
            "password_rhel8": "--build-arg PASS=${PASS}"
        },
        #opensuse_leap
        {
            "distribution": "opensuse-leap_15.1",
            "debian_packaging_override": "",
            "output_file": ".packages-built",
            "options": "--security-opt seccomp=./docker/profile-seccomp-fedora_28.json --privileged"
        },
        # Gentoo
        {
            "distribution": "gentoo",
            "debian_packaging_override": "",
            "output_file": ".packages-built",
        },

    ]

    for target in targets:
        print(generate_target(**target))


def parse_args():
    ap = argparse.ArgumentParser(
        description="Packaging targets generation tool"
    )

    ga = ap.add_mutually_exclusive_group(required=True)

    # Action arguments
    ga.add_argument('--generate',
                    action='store_true',
                    help='Generate a single packaging target')
    ga.add_argument('--generate-all',
                    action='store_true',
                    help='Generates all packaging targets')

    # Parameters
    ap.add_argument('--distribution')
    ap.add_argument('--debian_packaging_override', default='')
    ap.add_argument('--output_file')
    ap.add_argument('--options', default='')
    ap.add_argument('--docker_image', default='')
    ap.add_argument('--version', default='')
    ap.add_argument('--qemu_static', default='')

    parsed_args = ap.parse_args()

    return parsed_args


def main():
    parsed_args = parse_args()

    if parsed_args.generate:
        run_generate(parsed_args)
    elif parsed_args.generate_all:
        run_generate_all(parsed_args)

if __name__ == "__main__":
    main()
