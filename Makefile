##############################
## Version number variables ##
##############################
# YYYY-MM-DD
LAST_COMMIT_DATE:=$(shell git log -1 --format=%cd --date=short) # YYYY-MM-DD
# number of commits that day
NUMBER_OF_COMMITS:=$(shell git log --format=%cd --date=short | grep -c $(LAST_COMMIT_DATE))
# YYMMDD
LAST_COMMIT_DATE_SHORT:=$(shell echo $(LAST_COMMIT_DATE) | sed -s 's/-//g')
# last commit id
COMMIT_ID:=$(shell git rev-parse --short HEAD)

RELEASE_VERSION:=$(LAST_COMMIT_DATE_SHORT).$(NUMBER_OF_COMMITS).$(COMMIT_ID)
RELEASE_TARBALL_FILENAME:=ring_$(RELEASE_VERSION).tar.gz

#####################
## Other variables ##
#####################
TMPDIR := $(shell mktemp -d)
RING_PROJECT_DIR := $(shell pwd)

#############################
## Release tarball targets ##
#############################
.PHONY: release-tarball
release-tarball: $(RELEASE_TARBALL_FILENAME)

$(RELEASE_TARBALL_FILENAME):
	# Fetch tarballs
	mkdir -p daemon/contrib/native
	cd daemon/contrib/native && \
	    ../bootstrap && \
	    make fetch-all
	rm -rf daemon/contrib/native

	cd $(TMPDIR) && \
	    tar -C ${RING_PROJECT_DIR}/.. --exclude-vcs -zcf $(RELEASE_TARBALL_FILENAME) $(shell basename $(RING_PROJECT_DIR)) && \
	    mv $(RELEASE_TARBALL_FILENAME) $(RING_PROJECT_DIR)

	rm -rf $(RING_PROJECT_DIR)/daemon/contrib/tarballs/*

###################
## Other targets ##
###################
.PHONY: docs
docs: env
	env/bin/sphinx-build -b html docs/source docs/build/html

env:
	virtualenv env
	env/bin/pip install Sphinx==1.4.1 sphinx-rtd-theme==0.1.9

clean:
	rm -rf env
	rm ring_*.tar.gz
	make -C docs clean
