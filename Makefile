# -*- mode: makefile; -*-
# Copyright (C) 2016-2021 Savoir-faire Linux Inc.
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
.DEFAULT_GOAL := package-all

##############################
## Version number variables ##
##############################
# YYYY-MM-DD
LAST_COMMIT_DATE:=$(shell git log -1 --format=%cd --date=short)

# number of commits that day
NUMBER_OF_COMMITS:=$(shell git log --format=%cd --date=short | grep -c $(LAST_COMMIT_DATE))

# YYMMDD
LAST_COMMIT_DATE_SHORT:=$(shell echo $(LAST_COMMIT_DATE) | sed -s 's/-//g')

# last commit id
COMMIT_ID:=$(shell git rev-parse --short HEAD)

RELEASE_VERSION:=$(LAST_COMMIT_DATE_SHORT).$(NUMBER_OF_COMMITS).$(COMMIT_ID)
RELEASE_TARBALL_FILENAME:=jami_$(RELEASE_VERSION).tar.gz

# Debian versions
DEBIAN_VERSION:=$(RELEASE_VERSION)~dfsg1-1
DEBIAN_DSC_FILENAME:=jami_$(DEBIAN_VERSION).dsc
DEBIAN_OCI_VERSION:=$(RELEASE_VERSION)~dfsg1-0
DEBIAN_OCI_DSC_FILENAME:=jami_$(DEBIAN_OCI_VERSION).dsc
DEBIAN_OCI_PKG_DIR:="packaging/rules/debian-one-click-install"

DEBIAN_QT_DSC_FILENAME:=qt-jami_$(DEBIAN_VERSION).dsc

#####################
## Other variables ##
#####################
TMPDIR := $(shell mktemp -d)
CURRENT_UID:=$(shell id -u)
CURRENT_GID:=$(shell id -g)

#############################
## Release tarball targets ##
#############################
.PHONY: release-tarball
release-tarball: $(RELEASE_TARBALL_FILENAME)

# Fetch the required contrib sources and copy them to
# daemon/contrib/tarballs.  To use a custom tarballs cache directory,
# export the TARBALLS environment variable.
tarballs.manifest:
	rm -rf daemon/contrib/native
	mkdir -p daemon/contrib/native && \
	cd daemon/contrib/native && \
	../bootstrap && \
        $(MAKE) list && \
        $(MAKE) fetch -j && \
	$(MAKE) --silent list-tarballs > $(CURDIR)/$@
	rm -rf daemon/contrib/native

# Generate the release tarball.  Note: to avoid building 1+ GiB
# tarball containing all the bundled libraries, only the required
# tarballs are included.  This means the resulting release tarball
# content depends on what libraries the host has installed.  To build
# a single release tarball that can be used for any GNU/Linux machine,
# it should be built in a minimal container.)
$(RELEASE_TARBALL_FILENAME): tarballs.manifest
# Prepare the sources of the top repository and relevant submodules.
	rm -f "$@"
	mkdir $(TMPDIR)/ring-project
	git archive HEAD | tar xf - -C $(TMPDIR)/ring-project
	for m in daemon lrc client-gnome; do \
		(cd "$$m" && git archive --prefix "$$m/" HEAD \
			| tar xf - -C $(TMPDIR)/ring-project); \
	done
# Create the base archive.
	tar --create --file $(TMPDIR)/ring-project.tar $(TMPDIR)/ring-project \
		--transform 's,.*/ring-project,ring-project,'
# Append the cached tarballs listed in the manifest.
	tar --append --file $(TMPDIR)/ring-project.tar \
		--files-from $< \
		--transform 's,^.*/,ring-project/daemon/contrib/tarballs/,'
	gzip $(TMPDIR)/ring-project.tar
	mv $(TMPDIR)/ring-project.tar.gz "$@"
	rm -rf $(TMPDIR)

#######################
## Packaging targets ##
#######################

# Append the output of make-packaging-target to this Makefile
# see Makefile.packaging.distro_targets
$(shell scripts/make-packaging-target.py --generate-all > Makefile.packaging.distro_targets)
include Makefile.packaging.distro_targets

package-all: $(PACKAGE-TARGETS)

.PHONY: list-package-targets
list-package-targets:
	$(foreach p,$(PACKAGE-TARGETS),\
		echo $(p);)

docker/Dockerfile_snap: patches/docker-snap-build-scripts.patch
	if patch -p1 -fR --dry-run < $< >/dev/null 2>&1; then \
	  echo "Patching $@... skipped (already patched)"; \
	else \
	  echo "Patching $@..."; \
	  patch -p1 -Ns < $< || { echo "Patching $@... failed" >&2 && exit 1; }; \
	  echo "Patching $@... done"; \
	fi
.PHONY: docker/Dockerfile_snap

###################
## Other targets ##
###################
.PHONY: docs

# Build the documentation
# Note that newly added RST files will likely not display on all documents'
# navigation bar unless the docs/build folder is manually deleted.
docs: env
	env/bin/sphinx-build -b html docs/source docs/build/html
	env/bin/sphinx-build -b texinfo docs/source docs/build/texinfo

env:
	virtualenv env
	env/bin/pip install Sphinx==1.4.1 sphinx-rtd-theme==0.1.9

.PHONY: clean
clean:
	rm -rf env
	rm -rf docs/build
	rm -f jami_*.tar.gz
	rm -rf packages
	rm -f Makefile.packaging.distro_targets
	rm -f .docker-image-*
	rm -rf daemon/contrib/tarballs/*
