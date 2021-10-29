# -*- mode: makefile; -*-
# Copyright (C) 2016-2021 Savoir-faire Linux Inc.
#
# Author: Maxim Cournoyer <maxim.cournoyer@savoirfairelinux.com>
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

# Default caching directory
export TARBALLS ?= /var/cache/jami

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
RELEASE_TARBALL_FILENAME := jami_$(RELEASE_VERSION).tar.gz

# Export for consumption in child processes.
export RELEASE_VERSION
export RELEASE_TARBALL_FILENAME

# Debian versions
DEBIAN_VERSION:=$(RELEASE_VERSION)~dfsg1-1
DEBIAN_DSC_FILENAME:=jami_$(DEBIAN_VERSION).dsc

# Qt versions
QT_MAJOR := 6
QT_MINOR := 2
QT_PATCH := 0
QT_TARBALL_CHECKSUM := 60c2dc0ee86dd338e5c5194bd95922abfc097841e3e855693dfb4f5aaf0db4db
DEBIAN_QT_VERSION := $(QT_MAJOR).$(QT_MINOR).$(QT_PATCH)-1
DEBIAN_QT_DSC_FILENAME := libqt-jami_$(DEBIAN_QT_VERSION).dsc
QT_JAMI_PREFIX := /usr/lib/libqt-jami

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

# Predicate to check if the 'guix' command is available.
has-guix-p:
	command -v guix > /dev/null 2>&1 || \
	  (echo 'guix' is required to build the '$@' target && exit 1)

# The bundled tarballs included in the release tarball depend on what
# is available on the host.  To ensure it can be shared across all
# different GNU/Linux distributions, generate it in a minimal
# container.  Wget uses GnuTLS, which looks up its certs from
# /etc/ssl/certs.
guix-share-tarball-arg = $${TARBALLS:+"--share=$$TARBALLS"}
portable-release-tarball: has-guix-p
	guix environment --container --network \
          --preserve=TARBALLS $(guix-share-tarball-arg) \
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


#
# Traditionally built packages (in Docker containers).
#
DISTRIBUTIONS := \
	debian_10 \
	debian_11 \
	debian_testing \
	debian_unstable \
	raspbian_10_armhf \
	ubuntu_18.04 \
	ubuntu_20.04 \
	ubuntu_21.04 \
	ubuntu_21.10 \
	fedora_33 \
	fedora_34 \
	opensuse-leap_15.2 \
	opensuse-leap_15.3 \
	opensuse-tumbleweed \
	snap

IS_SHELL_INTERACTIVE := $(shell [ -t 0 ] && echo yes)

# The following Make variable can be used to provide extra arguments
# used with the 'docker run' commands invoked to build the packages.
DOCKER_RUN_EXTRA_ARGS =

# This function is used to produce the rules of the packaging targets
# that rely on Docker.
# Arg1: The name-version string of the distribution (e.g., ubuntu-18.04).
# Arg2: Extra arguments to pass to 'docker build'.
# Arg3: Extra arguments to pass to 'docker run'.
define make-docker-package-target
$(1)-docker-image-name := jami-packaging-$(1)
$(1)-docker-image-file := .docker-image-$$($(1)-docker-image-name)
$(1)-docker-run-command := docker run \
  --rm --privileged --security-opt apparmor=docker-default \
  -e RELEASE_VERSION="$(RELEASE_VERSION)" \
  -e RELEASE_TARBALL_FILENAME="$(RELEASE_TARBALL_FILENAME)" \
  -e DEBIAN_VERSION="$(DEBIAN_VERSION)" \
  -e DEBIAN_QT_VERSION="$(DEBIAN_QT_VERSION)" \
  -e CURRENT_UID="$(CURRENT_UID)" \
  -e CURRENT_GID="$(CURRENT_GID)" \
  -e DISTRIBUTION="$(1)" \
  -e QT_JAMI_PREFIX="$(QT_JAMI_PREFIX)" \
  -e QT_MAJOR="$(QT_MAJOR)" \
  -e QT_MINOR="$(QT_MINOR)" \
  -e QT_PATCH="$(QT_PATCH)" \
  -e QT_TARBALL_CHECKSUM="$(QT_TARBALL_CHECKSUM)" \
  -e FORCE_REBUILD_QT="$(FORCE_REBUILD_QT)" \
  -e SNAP_PKG_NAME="$(or $(SNAP_PKG_NAME),jami)" \
  -e TARBALLS="$(TARBALLS)" \
  -v '$(TARBALLS)':'$(TARBALLS)' \
  -v '$(CURDIR)/$(RELEASE_TARBALL_FILENAME)':'/src/$(RELEASE_TARBALL_FILENAME)' \
  -v '$(CURDIR)/packages/$(1)':/opt/output \
  -t $(and $(IS_SHELL_INTERACTIVE),-i) \
  $(3) \
  "$$($(1)-docker-image-name)"

$$($(1)-docker-image-file): docker/Dockerfile_$(1)
	docker build \
	  -t $$($(1)-docker-image-name) \
	  -f docker/Dockerfile_$(1) $(2) $(CURDIR) && \
	touch "$$@"

packages/$(1)/.packages-built: $(RELEASE_TARBALL_FILENAME) $$($(1)-docker-image-file)
	mkdir -p "$$$$(dirname "$$@")" && \
	$$($(1)-docker-run-command) && \
	touch "$$@"

.PHONY: $(1)
$(1): packages/$(1)/.packages-built
PACKAGE-TARGETS += $(1)

.PHONY: $(1)-interactive
$(1)-interactive: $(RELEASE_TARBALL_FILENAME) $$($(1)-docker-image-file)
	$$($(1)-docker-run-command) bash

endef

$(foreach target,$(DISTRIBUTIONS),\
	$(eval $(call make-docker-package-target,$(target))))

#
# Guix-generated Debian packages (deb packs) targets.
#
SUPPORTED_GNU_ARCHS = x86_64 i686
DEB_PACK_TARGETS =

define guix-pack-command
guix pack -C xz -f deb -m $(CURDIR)/guix/guix-pack-manifest.scm -v3 \
  -S /usr/bin/jami-qt=bin/jami-qt \
  -S /usr/share/applications/jami-qt.desktop=share/applications/jami-qt.desktop \
  -S /usr/share/icons/hicolor/scalable/apps/jami.svg=share/icons/hicolor/scalable/apps/jami.svg \
  -S /usr/share/icons/hicolor/48x48/apps/jami.png=share/icons/hicolor/48x48/apps/jami.png \
  -S /usr/share/metainfo/jami-qt.appdata.xml=share/metainfo/jami-qt.appdata.xml \
  --postinst-file=$(CURDIR)/guix/guix-pack-deb.postinst
endef

# Arg1: the GNU architecture type (e.g., x86_64, i686, powerpcle, etc.)
define define-deb-pack-rule
deb-file-name := packages/guix-deb-pack/jami-$(RELEASE_VERSION)-$(1).deb
DEB_PACK_TARGETS += deb-pack-$(subst _,-,$(1))
.PHONY: deb-pack-$(subst _,-,$(1))
deb-pack-$(subst _,-,$(1)): $$(deb-file-name)
$$(deb-file-name): has-guix-p $(RELEASE_TARBALL_FILENAME)
	output=$$$$($(guix-pack-command) --system=$(1)-linux $$(GUIX_PACK_ARGS)) && \
	mkdir -p "$$$$(dirname "$$@")" && \
	cp --reflink=auto "$$$$output" "$$@"
	chmod +w "$$@"
endef

$(foreach arch,$(SUPPORTED_GNU_ARCHS),\
	$(eval $(call define-deb-pack-rule,$(arch))))

PACKAGE-TARGETS += $(DEB_PACK_TARGETS)

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
