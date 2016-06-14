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
package-all: package-debian8 \
             package-debian9 \
             package-ubuntu14.04 \
             package-ubuntu15.04 \
             package-ubuntu15.10 \
             package-ubuntu16.04

##
## Distro: Debian 8
##

PACKAGE_DEBIAN8_DOCKER_RUN_COMMAND:= docker run \
	--rm \
	-e RELEASE_VERSION=$(RELEASE_VERSION) \
	-e RELEASE_TARBALL_FILENAME=$(RELEASE_TARBALL_FILENAME) \
	-e DEBIAN_VERSION=$(DEBIAN_VERSION) \
	-e CURRENT_UID=$(CURRENT_UID) \
	-e DEBIAN_PACKAGING_OVERRIDE=packaging/distros/debian8/debian \
	-v $(CURDIR):/opt/ring-project-ro:ro \
	-v $(CURDIR)/packages/debian8:/opt/output \
	-i \
	-t ring-packaging-debian8

.PHONY: docker-image-debian8
docker-image-debian8:
	docker build \
        -t ring-packaging-debian8 \
        -f docker/Dockerfile_debian8 \
        $(CURDIR)

packages/debian8:
	mkdir -p packages/debian8

packages/debian8/$(DEBIAN_AMD64_CHANGES_FILENAME): docker-image-debian8 release-tarball packages/debian8
	$(PACKAGE_DEBIAN8_DOCKER_RUN_COMMAND)

.PHONY: package-debian8
package-debian9: packages/debian8/$(DEBIAN_AMD64_CHANGES_FILENAME)

.PHONY: package-debian8-interactive
package-debian8-interactive:
	$(PACKAGE_DEBIAN8_DOCKER_RUN_COMMAND) bash

##
## Distro: Debian 9
##

PACKAGE_DEBIAN9_DOCKER_RUN_COMMAND:= docker run \
	--rm \
	-e RELEASE_VERSION=$(RELEASE_VERSION) \
	-e RELEASE_TARBALL_FILENAME=$(RELEASE_TARBALL_FILENAME) \
	-e DEBIAN_VERSION=$(DEBIAN_VERSION) \
	-e CURRENT_UID=$(CURRENT_UID) \
	-v $(CURDIR):/opt/ring-project-ro:ro \
	-v $(CURDIR)/packages/debian9:/opt/output \
	-i \
	-t ring-packaging-debian9

.PHONY: docker-image-debian9
docker-image-debian9:
	docker build \
        -t ring-packaging-debian9 \
        -f docker/Dockerfile_debian9 \
        $(CURDIR)

packages/debian9:
	mkdir -p packages/debian9

packages/debian9/$(DEBIAN_AMD64_CHANGES_FILENAME): docker-image-debian9 release-tarball packages/debian9
	$(PACKAGE_DEBIAN9_DOCKER_RUN_COMMAND)

.PHONY: package-debian9
package-debian9: packages/debian9/$(DEBIAN_AMD64_CHANGES_FILENAME)

.PHONY: package-debian9-interactive
package-debian9-interactive:
	$(PACKAGE_DEBIAN9_DOCKER_RUN_COMMAND) bash

##
## Distro: Ubuntu 14.04
##

PACKAGE_UBUNTU14.04_DOCKER_RUN_COMMAND:= docker run \
	--rm \
	-e RELEASE_VERSION=$(RELEASE_VERSION) \
	-e RELEASE_TARBALL_FILENAME=$(RELEASE_TARBALL_FILENAME) \
	-e DEBIAN_VERSION=$(DEBIAN_VERSION) \
	-e CURRENT_UID=$(CURRENT_UID) \
	-e DEBIAN_PACKAGING_OVERRIDE=packaging/distros/debian8/debian \
	-v $(CURDIR):/opt/ring-project-ro:ro \
	-v $(CURDIR)/packages/ubuntu14.04:/opt/output \
	-i \
	-t ring-packaging-ubuntu14.04

.PHONY: docker-image-ubuntu14.04
docker-image-ubuntu14.04:
	docker build \
	    -t ring-packaging-ubuntu14.04 \
	    -f docker/Dockerfile_ubuntu14.04 \
	    $(CURDIR)

packages/ubuntu14.04:
	mkdir -p packages/ubuntu14.04

packages/ubuntu14.04/$(DEBIAN_AMD64_CHANGES_FILENAME): docker-image-ubuntu14.04 release-tarball packages/ubuntu14.04
	$(PACKAGE_UBUNTU14.04_DOCKER_RUN_COMMAND)

.PHONY: package-ubuntu14.04
package-ubuntu14.04: packages/ubuntu14.04/$(DEBIAN_AMD64_CHANGES_FILENAME)

.PHONY: package-ubuntu14.04-interactive
package-ubuntu14.04-interactive:
	$(PACKAGE_UBUNTU14.04_DOCKER_RUN_COMMAND) bash

##
## Distro: Ubuntu 15.04
##

PACKAGE_UBUNTU15.04_DOCKER_RUN_COMMAND:= docker run \
	--rm \
	-e RELEASE_VERSION=$(RELEASE_VERSION) \
	-e RELEASE_TARBALL_FILENAME=$(RELEASE_TARBALL_FILENAME) \
	-e DEBIAN_VERSION=$(DEBIAN_VERSION) \
	-e CURRENT_UID=$(CURRENT_UID) \
	-e DEBIAN_PACKAGING_OVERRIDE=packaging/distros/debian8/debian \
	-v $(CURDIR):/opt/ring-project-ro:ro \
	-v $(CURDIR)/packages/ubuntu15.04:/opt/output \
	-i \
	-t ring-packaging-ubuntu15.04

.PHONY: docker-image-ubuntu15.04
docker-image-ubuntu15.04:
	docker build \
	    -t ring-packaging-ubuntu15.04 \
	    -f docker/Dockerfile_ubuntu15.04 \
	    $(CURDIR)

packages/ubuntu15.04:
	mkdir -p packages/ubuntu15.04

packages/ubuntu15.04/$(DEBIAN_AMD64_CHANGES_FILENAME): docker-image-ubuntu15.04 release-tarball packages/ubuntu15.04
	$(PACKAGE_UBUNTU15.04_DOCKER_RUN_COMMAND)

.PHONY: package-ubuntu15.04
package-ubuntu15.04: packages/ubuntu15.04/$(DEBIAN_AMD64_CHANGES_FILENAME)

.PHONY: package-ubuntu15.04-interactive
package-ubuntu15.04-interactive:
	$(PACKAGE_UBUNTU15.04_DOCKER_RUN_COMMAND) bash

##
## Distro: Ubuntu 15.10
##

PACKAGE_UBUNTU15.10_DOCKER_RUN_COMMAND:= docker run \
	--rm \
	-e RELEASE_VERSION=$(RELEASE_VERSION) \
	-e RELEASE_TARBALL_FILENAME=$(RELEASE_TARBALL_FILENAME) \
	-e DEBIAN_VERSION=$(DEBIAN_VERSION) \
	-e CURRENT_UID=$(CURRENT_UID) \
	-e DEBIAN_PACKAGING_OVERRIDE=packaging/distros/debian8/debian \
	-v $(CURDIR):/opt/ring-project-ro:ro \
	-v $(CURDIR)/packages/ubuntu15.10:/opt/output \
	-i \
	-t ring-packaging-ubuntu15.10

.PHONY: docker-image-ubuntu15.10
docker-image-ubuntu15.10:
	docker build \
	    -t ring-packaging-ubuntu15.10 \
	    -f docker/Dockerfile_ubuntu15.10 \
	    $(CURDIR)

packages/ubuntu15.10:
	mkdir -p packages/ubuntu15.10

packages/ubuntu15.10/$(DEBIAN_AMD64_CHANGES_FILENAME): docker-image-ubuntu15.10 release-tarball packages/ubuntu15.10
	$(PACKAGE_UBUNTU15.10_DOCKER_RUN_COMMAND)

.PHONY: package-ubuntu15.10
package-ubuntu15.10: packages/ubuntu15.10/$(DEBIAN_AMD64_CHANGES_FILENAME)

.PHONY: package-ubuntu15.10-interactive
package-ubuntu15.10-interactive:
	$(PACKAGE_UBUNTU15.10_DOCKER_RUN_COMMAND) bash

##
## Distro: Ubuntu 16.04
##

PACKAGE_UBUNTU16.04_DOCKER_RUN_COMMAND:= docker run \
	--rm \
	-e RELEASE_VERSION=$(RELEASE_VERSION) \
	-e RELEASE_TARBALL_FILENAME=$(RELEASE_TARBALL_FILENAME) \
	-e DEBIAN_VERSION=$(DEBIAN_VERSION) \
	-e CURRENT_UID=$(CURRENT_UID) \
	-v $(CURDIR):/opt/ring-project-ro:ro \
	-v $(CURDIR)/packages/ubuntu16.04:/opt/output \
	-i \
	-t ring-packaging-ubuntu16.04


.PHONY: docker-image-ubuntu16.04
docker-image-ubuntu16.04:
	docker build \
	    -t ring-packaging-ubuntu16.04 \
	    -f docker/Dockerfile_ubuntu16.04 \
	    $(CURDIR)

packages/ubuntu16.04:
	mkdir -p packages/ubuntu16.04

packages/ubuntu16.04/$(DEBIAN_AMD64_CHANGES_FILENAME): docker-image-ubuntu16.04 release-tarball packages/ubuntu16.04
	$(PACKAGE_UBUNTU16.04_DOCKER_RUN_COMMAND)

.PHONY: package-ubuntu16.04
package-ubuntu16.04: packages/ubuntu16.04/$(DEBIAN_AMD64_CHANGES_FILENAME)

.PHONY: package-ubuntu16.04-interactive
package-ubuntu16.04-interactive:
	$(PACKAGE_UBUNTU16.04_DOCKER_RUN_COMMAND) bash

###################
## Other targets ##
###################
.PHONY: docs
docs: env
	env/bin/sphinx-build -b html docs/source docs/build/html
	env/bin/sphinx-build -b texinfo docs/source docs/build/texinfo

env:
	virtualenv env
	env/bin/pip install Sphinx==1.4.1 sphinx-rtd-theme==0.1.9

clean:
	rm -rf env
	rm -rf docs/build
	rm -f ring_*.tar.gz
	rm -rf packages
