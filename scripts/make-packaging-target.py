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

PACKAGE_%(distribution)s_DOCKER_RUN_COMMAND:= docker run \\
    --rm \\
    -e RELEASE_VERSION=$(RELEASE_VERSION) \\
    -e RELEASE_TARBALL_FILENAME=$(RELEASE_TARBALL_FILENAME) \\
    -e DEBIAN_VERSION=$(DEBIAN_VERSION) \\
    -e DEBIAN_PACKAGING_OVERRIDE=%(debian_packaging_override)s \\
    -e CURRENT_UID=$(CURRENT_UID) \\
    -v $(CURDIR):/opt/ring-project-ro:ro \\
    -v $(CURDIR)/packages/%(distribution)s:/opt/output \\
    -i \\
    -t ring-packaging-%(distribution)s

.docker-image-%(distribution)s: docker/Dockerfile_%(distribution)s
	docker build \\
        -t ring-packaging-%(distribution)s \\
        -f docker/Dockerfile_%(distribution)s \\
        $(CURDIR)
	touch .docker-image-%(distribution)s

packages/%(distribution)s:
	mkdir -p packages/%(distribution)s

packages/%(distribution)s/$(DEBIAN_DSC_FILENAME): $(RELEASE_TARBALL_FILENAME) packages/%(distribution)s .docker-image-%(distribution)s
	$(PACKAGE_%(distribution)s_DOCKER_RUN_COMMAND)
	touch packages/%(distribution)s/*

.PHONY: package-%(distribution)s
package-%(distribution)s: packages/%(distribution)s/$(DEBIAN_DSC_FILENAME)

.PHONY: package-%(distribution)s-interactive
package-%(distribution)s-interactive: $(RELEASE_TARBALL_FILENAME) packages/%(distribution)s .docker-image-%(distribution)s
	$(PACKAGE_%(distribution)s_DOCKER_RUN_COMMAND) bash
"""


def generate_target(distribution, debian_packaging_override):
    return target_template % {
        "distribution": distribution,
        "debian_packaging_override": debian_packaging_override,
    }


def run_generate(parsed_args):
    print(generate_target(parsed_args.distribution,
                          parsed_args.debian_packaging_override))


def run_generate_all(parsed_args):
    targets = [
        # Debian
        {
            "distribution": "debian8",
            "debian_packaging_override": "",
        },
        {
            "distribution": "debian8_i386",
            "debian_packaging_override": "",
        },
        {
            "distribution": "debian9",
            "debian_packaging_override": "",
        },
        {
            "distribution": "debian9_i386",
            "debian_packaging_override": "",
        },
        # Ubuntu
        {
            "distribution": "ubuntu14.04",
            "debian_packaging_override": "",
        },
        {
            "distribution": "ubuntu14.04_i386",
            "debian_packaging_override": "",
        },
        {
            "distribution": "ubuntu15.04",
            "debian_packaging_override": "",
        },
        {
            "distribution": "ubuntu15.04_i386",
            "debian_packaging_override": "",
        },
        {
            "distribution": "ubuntu15.10",
            "debian_packaging_override": "",
        },
        {
            "distribution": "ubuntu15.10_i386",
            "debian_packaging_override": "",
        },
        {
            "distribution": "ubuntu16.04",
            "debian_packaging_override": "",
        },
        {
            "distribution": "ubuntu16.04_i386",
            "debian_packaging_override": "",
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
