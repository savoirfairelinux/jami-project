#!/usr/bin/env python3
#
# Copyright (C) 2016 Savoir-faire Linux Inc.
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
# This helps reduce the lenght of the top Makefile.
#

import argparse

target_template = """\
##
## Distro: %(distribution)s
##

# We don't simply use ring-packaging-distro as the docker image name because
# we want to be able to build multiple versions of the same distro at the
# same time and it could result in race conditions on the machine as we would
# overwrite the docker image of other builds.
#
# This does not impact caching as the docker daemon does not care about the image
# names, just about the contents of the Dockerfile.
PACKAGE_%(distribution)s_DOCKER_IMAGE_NAME:=ring-packaging-%(distribution)s$(RING_PACKAGING_IMAGE_SUFFIX)
PACKAGE_%(distribution)s_DOCKER_IMAGE_FILE:=.docker-image-$(PACKAGE_%(distribution)s_DOCKER_IMAGE_NAME)

PACKAGE_%(distribution)s_DOCKER_RUN_COMMAND:= docker run \\
    --rm \\
    -e RELEASE_VERSION=$(RELEASE_VERSION) \\
    -e RELEASE_TARBALL_FILENAME=$(RELEASE_TARBALL_FILENAME) \\
    -e DEBIAN_VERSION=$(DEBIAN_VERSION) \\
    -e DEBIAN_PACKAGING_OVERRIDE=%(debian_packaging_override)s \\
    -e CURRENT_UID=$(CURRENT_UID) \\
    -e DISTRIBUTION=%(distribution)s \\
    -v $(CURDIR):/opt/ring-project-ro:ro \\
    -v $(CURDIR)/packages/%(distribution)s:/opt/output \\
    -t $(PACKAGE_%(distribution)s_DOCKER_IMAGE_NAME)

$(PACKAGE_%(distribution)s_DOCKER_IMAGE_FILE): docker/Dockerfile_%(distribution)s
	docker build \\
        -t $(PACKAGE_%(distribution)s_DOCKER_IMAGE_NAME) \\
        -f docker/Dockerfile_%(distribution)s \\
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
package-%(distribution)s-interactive: $(RELEASE_TARBALL_FILENAME) packages/%(distribution)s $(PACKAGE_%(distribution)s_DOCKER_IMAGE_FILE)
	$(PACKAGE_%(distribution)s_DOCKER_RUN_COMMAND) bash
"""


def generate_target(distribution, debian_packaging_override, output_file):
    return target_template % {
        "distribution": distribution,
        "debian_packaging_override": debian_packaging_override,
        "output_file": output_file,
    }


def run_generate(parsed_args):
    print(generate_target(parsed_args.distribution,
                          parsed_args.debian_packaging_override))


def run_generate_all(parsed_args):
    targets = [
        # Debian
        {
            "distribution": "debian_8",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
        },
        {
            "distribution": "debian_8_i386",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
        },
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
        # Ubuntu
        {
            "distribution": "ubuntu_14.04",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
        },
        {
            "distribution": "ubuntu_14.04_i386",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
        },
        {
            "distribution": "ubuntu_15.10",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
        },
        {
            "distribution": "ubuntu_15.10_i386",
            "debian_packaging_override": "",
            "output_file": "$(DEBIAN_DSC_FILENAME)",
        },
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
        # Fedora
        {
            "distribution": "fedora_22",
            "debian_packaging_override": "",
            "output_file": ".packages-built",
        },
        {
            "distribution": "fedora_22_i386",
            "debian_packaging_override": "",
            "output_file": ".packages-built",
        },
        {
            "distribution": "fedora_23",
            "debian_packaging_override": "",
            "output_file": ".packages-built",
        },
        {
            "distribution": "fedora_23_i386",
            "debian_packaging_override": "",
            "output_file": ".packages-built",
        },
        {
            "distribution": "fedora_24",
            "debian_packaging_override": "",
            "output_file": ".packages-built",
        },
        {
            "distribution": "fedora_24_i386",
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
    ap.add_argument('--architecture')
    ap.add_argument('--debian_packaging_override', default='')
    ap.add_argument('--output_file')

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
