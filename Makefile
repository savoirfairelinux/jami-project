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
RELEASE_TARBALL_FILENAME:=ring_$(RELEASE_VERSION).tar.gz

# Debian versions
DEBIAN_VERSION:=$(RELEASE_VERSION)~dfsg1-1
DEBIAN_AMD64_CHANGES_FILENAME:=ring_$(DEBIAN_VERSION)_amd64.changes

#####################
## Other variables ##
#####################
TMPDIR := $(shell mktemp -d)
CURRENT_UID:=$(shell id -u)

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
	    tar -C $(CURDIR)/.. \
	        --exclude-vcs \
	        -zcf $(RELEASE_TARBALL_FILENAME) \
	        $(shell basename $(CURDIR)) && \
	    mv $(RELEASE_TARBALL_FILENAME) $(CURDIR)

	rm -rf $(CURDIR)/daemon/contrib/tarballs/*

#######################
## Packaging targets ##
#######################

.PHONY: package-all
package-all: package-debian9 package-ubuntu16.04

##
## Distro: Debian 9
##

.PHONY: docker-image-debian9
docker-image-debian9:
	docker build \
        -t ring-packaging-debian9 \
        -f docker/Dockerfile_debian9 \
        $(CURDIR)

packages/debian9/$(DEBIAN_AMD64_CHANGES_FILENAME): docker-image-debian9 release-tarball
	mkdir -p packages/debian9
	docker run \
        --rm \
        -e RELEASE_VERSION=$(RELEASE_VERSION) \
        -e RELEASE_TARBALL_FILENAME=$(RELEASE_TARBALL_FILENAME) \
        -e DEBIAN_VERSION=$(DEBIAN_VERSION) \
        -e CURRENT_UID=$(CURRENT_UID) \
        -v $(CURDIR):/opt/ring-project-ro:ro \
        -v $(CURDIR)/packages/debian9:/opt/output \
        -t ring-packaging-debian9

.PHONY: package-debian9
package-debian9: packages/debian9/$(DEBIAN_AMD64_CHANGES_FILENAME)

##
## Distro: Ubuntu 15.04
##

.PHONY: docker-image-ubuntu15.04
docker-image-ubuntu15.04:
	docker build \
        -t ring-packaging-ubuntu15.04 \
        -f docker/Dockerfile_ubuntu15.04 \
        $(CURDIR)

packages/ubuntu15.04/$(DEBIAN_AMD64_CHANGES_FILENAME): docker-image-ubuntu15.04 release-tarball
	mkdir -p packages/ubuntu15.04
	docker run \
        --rm \
        -e RELEASE_VERSION=$(RELEASE_VERSION) \
        -e RELEASE_TARBALL_FILENAME=$(RELEASE_TARBALL_FILENAME) \
        -e DEBIAN_VERSION=$(DEBIAN_VERSION) \
        -e CURRENT_UID=$(CURRENT_UID) \
        -v $(CURDIR):/opt/ring-project-ro:ro \
        -v $(CURDIR)/packages/ubuntu15.04:/opt/output \
        -t ring-packaging-ubuntu15.04

.PHONY: package-ubuntu15.10
package-ubuntu15.10: packages/ubuntu15.10/$(DEBIAN_AMD64_CHANGES_FILENAME)

##
## Distro: Ubuntu 15.10
##

.PHONY: docker-image-ubuntu15.10
docker-image-ubuntu15.10:
	docker build \
        -t ring-packaging-ubuntu15.10 \
        -f docker/Dockerfile_ubuntu15.10 \
        $(CURDIR)

packages/ubuntu15.10/$(DEBIAN_AMD64_CHANGES_FILENAME): docker-image-ubuntu15.10 release-tarball
	mkdir -p packages/ubuntu15.10
	docker run \
        --rm \
        -e RELEASE_VERSION=$(RELEASE_VERSION) \
        -e RELEASE_TARBALL_FILENAME=$(RELEASE_TARBALL_FILENAME) \
        -e DEBIAN_VERSION=$(DEBIAN_VERSION) \
        -e CURRENT_UID=$(CURRENT_UID) \
        -v $(CURDIR):/opt/ring-project-ro:ro \
        -v $(CURDIR)/packages/ubuntu15.10:/opt/output \
        -t ring-packaging-ubuntu15.10

.PHONY: package-ubuntu15.10
package-ubuntu15.10: packages/ubuntu15.10/$(DEBIAN_AMD64_CHANGES_FILENAME)

##
## Distro: Ubuntu 16.04
##

.PHONY: docker-image-ubuntu16.04
docker-image-ubuntu16.04:
	docker build \
        -t ring-packaging-ubuntu16.04 \
        -f docker/Dockerfile_ubuntu16.04 \
        $(CURDIR)

packages/ubuntu16.04/$(DEBIAN_AMD64_CHANGES_FILENAME): docker-image-ubuntu16.04 release-tarball
	mkdir -p packages/ubuntu16.04
	docker run \
        --rm \
        -e RELEASE_VERSION=$(RELEASE_VERSION) \
        -e RELEASE_TARBALL_FILENAME=$(RELEASE_TARBALL_FILENAME) \
        -e DEBIAN_VERSION=$(DEBIAN_VERSION) \
        -e CURRENT_UID=$(CURRENT_UID) \
        -v $(CURDIR):/opt/ring-project-ro:ro \
        -v $(CURDIR)/packages/ubuntu16.04:/opt/output \
        -t ring-packaging-ubuntu16.04

.PHONY: package-ubuntu16.04
package-ubuntu16.04: packages/ubuntu16.04/$(DEBIAN_AMD64_CHANGES_FILENAME)

###################
## Other targets ##
###################
.PHONY: docs
docs: env
	env/bin/sphinx-build -b html docs/source docs/build/html

env:
	virtualenv env
	env/bin/pip install Sphinx==1.4.1 sphinx-rtd-theme==0.1.9

.PHONY: clean
clean:
	rm -rf env
	rm -f ring_*.tar.gz
	rm -rf packages
	make -C docs clean
