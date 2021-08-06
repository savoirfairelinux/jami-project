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
TARBALL_VERSION := $(shell cat $(CURDIR)/.tarball-version 2> /dev/null)

ifeq ($(TARBALL_VERSION),)
# YYYY-MM-DD
LAST_COMMIT_DATE:=$(shell git log -1 --format=%cd --date=short)

# number of commits that day
NUMBER_OF_COMMITS:=$(shell git log --format=%cd --date=short | grep -c $(LAST_COMMIT_DATE))

# YYMMDD
LAST_COMMIT_DATE_SHORT:=$(shell echo $(LAST_COMMIT_DATE) | sed -s 's/-//g')

# last commit id
COMMIT_ID:=$(shell git rev-parse --short HEAD)

RELEASE_VERSION:=$(LAST_COMMIT_DATE_SHORT).$(NUMBER_OF_COMMITS).$(COMMIT_ID)
else
$(warning Using version from the .tarball-version file: $(TARBALL_VERSION))
RELEASE_VERSION:=$(TARBALL_VERSION)
endif
RELEASE_TARBALL_FILENAME:=jami_$(RELEASE_VERSION).tar.gz

# Debian versions
DEBIAN_VERSION:=$(RELEASE_VERSION)~dfsg1-1
DEBIAN_DSC_FILENAME:=jami_$(DEBIAN_VERSION).dsc

# Qt versions
QT_MAJOR:=5
QT_MINOR:=15
QT_PATCH:=2
QT_TARBALL_CHECKSUM:="3a530d1b243b5dec00bc54937455471aaa3e56849d2593edb8ded07228202240"
DEBIAN_QT_VERSION:=$(QT_MAJOR).$(QT_MINOR).$(QT_PATCH)-1
DEBIAN_QT_DSC_FILENAME:=libqt-jami_$(DEBIAN_QT_VERSION).dsc
QT_JAMI_PREFIX:="/usr/lib/libqt-jami"

#####################
## Other variables ##
#####################
TMPDIR := $(shell mktemp -d)
CURRENT_UID:=$(shell id -u)
CURRENT_GID:=$(shell id -g)

#############################
## Release tarball targets ##
#############################
.PHONY: release-tarball purge-release-tarballs portable-release-tarball
# See: https://reproducible-builds.org/docs/archives/
TAR_REPRODUCIBILITY_OPTIONS = \
	--format=gnu \
	--mtime=@1 \
	--owner=root:0 \
	--group=root:0

# This file can be used when not wanting to invoke the tarball
# producing machinery (which depends on the Git checkout), nor its
# prerequisites.  It is used to set the TARBALL_VERSION Make variable.
.tarball-version:
	echo $(RELEASE_VERSION) > $@

purge-release-tarballs:
	rm -f jami_*.tar.* tarballs.manifest

release-tarball:
	rm -f "$(RELEASE_TARBALL_FILENAME)" tarballs.manifest
	$(MAKE) "$(RELEASE_TARBALL_FILENAME)"

# The bundled tarballs included in the release tarball depend on what
# is available on the host.  To ensure it can be shared across all
# different GNU/Linux distributions, generate it in a minimal
# container.  Wget uses GnuTLS, which looks up its certs from
# /etc/ssl/certs.
guix-share-tarball-arg = $${TARBALLS:+"--share=$$TARBALLS"}
portable-release-tarball:
	command -v guix > /dev/null 2>&1 || \
	  (echo 'guix' is required to build the '$@' target && exit 1) && \
	guix environment --container --network \
          --preserve=TARBALLS $(guix-share-tarball-arg) \
	  --preserve=SSL_CERT \
          --expose=/usr/bin/env \
          --expose=$$SSL_CERT_DIR=/etc/ssl/certs \
          --manifest=$(CURDIR)/guix/minimal-manifest.scm \
          -- $(MAKE) release-tarball

daemon/contrib/native/Makefile:
	mkdir -p daemon/contrib/native && \
	cd daemon/contrib/native && \
	../bootstrap

# Fetch the required contrib sources and copy them to
# daemon/contrib/tarballs.  To use a custom tarballs cache directory,
# export the TARBALLS environment variable.
tarballs.manifest: daemon/contrib/native/Makefile
	cd daemon/contrib/native && \
	$(MAKE) list && \
	$(MAKE) fetch -j && \
	$(MAKE) --no-print-directory --silent list-tarballs > "$(CURDIR)/$@"

ifeq ($(TARBALL_VERSION),)
# Generate the release tarball.  To regenerate a fresh tarball
# manually clear the tarballs.manifest file.
$(RELEASE_TARBALL_FILENAME): tarballs.manifest
# Prepare the sources of the top repository and relevant submodules.
	rm -f "$@"
	mkdir $(TMPDIR)/ring-project
	git archive HEAD | tar xf - -C $(TMPDIR)/ring-project
	for m in daemon lrc client-gnome client-qt; do \
		(cd "$$m" && git archive --prefix "$$m/" HEAD \
			| tar xf - -C $(TMPDIR)/ring-project); \
	done
# Create the base archive.
	tar -cf $(TMPDIR)/ring-project.tar $(TMPDIR)/ring-project \
	  --transform 's,.*/ring-project,ring-project,' \
	  $(TAR_REPRODUCIBILITY_OPTIONS)
# Append the cached tarballs listed in the manifest.
	tar --append --file $(TMPDIR)/ring-project.tar \
	  --files-from $< \
	  --transform 's,^.*/,ring-project/daemon/contrib/tarballs/,' \
          $(TAR_REPRODUCIBILITY_OPTIONS)
	gzip --no-name $(TMPDIR)/ring-project.tar
	mv $(TMPDIR)/ring-project.tar.gz "$@"
	rm -rf $(TMPDIR)
else
# If TARBALL_VERSION is defined, assume it's already been generated,
# without doing any checks, which would require Git.
$(RELEASE_TARBALL_FILENAME):
endif

#######################
## Packaging targets ##
#######################

IS_SHELL_INTERACTIVE := $(shell [ -t 0 ] && echo yes)

# The following Make variable can be used to provide extra arguments
# used with the 'docker run' commands invoked to build the packages.
DOCKER_RUN_EXTRA_ARGS =

# Append the output of make-packaging-target to this Makefile
# see Makefile.packaging.distro_targets
$(shell scripts/make-packaging-target.py --generate-all > Makefile.packaging.distro_targets)
include Makefile.packaging.distro_targets

package-all: $(PACKAGE-TARGETS)

.PHONY: list-package-targets
list-package-targets:
	@$(foreach p,$(PACKAGE-TARGETS),\
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
