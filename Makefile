#
# Copyright 2020-present Open Networking Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# set default shell
SHELL                    := /bin/bash -e -o pipefail

# Variables
VERSION                  ?= $(shell cat ./VERSION)

# Docker related
DOCKER_REGISTRY          ?=
DOCKER_REPOSITORY        ?=
DOCKER_BUILD_ARGS        ?=
DOCKER_TAG               ?= ${VERSION}

# Docker labels. Only set ref and commit date if committed
DOCKER_LABEL_VCS_URL     ?= $(shell git remote get-url $(shell git remote))
DOCKER_LABEL_BUILD_DATE  ?= $(shell date -u "+%Y-%m-%dT%H:%M:%SZ")
DOCKER_LABEL_COMMIT_DATE  = $(shell git show -s --format=%cd --date=iso-strict HEAD)

ifeq ($(shell git ls-files --others --modified --exclude-standard 2>/dev/null | wc -l | sed -e 's/ //g'),0)
  DOCKER_LABEL_VCS_REF = $(shell git rev-parse HEAD)
else
  DOCKER_LABEL_VCS_REF = $(shell git rev-parse HEAD)+dirty
endif

# TOST related
ONOS_IMAGENAME    := ${DOCKER_REGISTRY}${DOCKER_REPOSITORY}tost-onos:${DOCKER_TAG}
ONOS_BRANCH       ?=
ONOS_REVIEW       ?=
ONOS_ROOT         := $(shell pwd)/onos
ONOS_PROFILE      := "tost"

.PHONY: docker-build

# This should to be the first and default target in this Makefile
help: ## : Print this help
	@echo "Usage: make [<target>]"
	@echo "where available targets are:"
	@echo
	@grep '^[[:alnum:]_-]*:.* ##' $(MAKEFILE_LIST) \
	| sort | awk 'BEGIN {FS=":.* ## "}; {printf "%-25s %s\n", $$1, $$2};'
	@echo
	@echo "Environment variables:"
	@echo "ONOS_BRANCH		  : Use the following branch to build the image"
	@echo "ONOS_REVIEW		  : Use the following review to build the image"
	@echo ""
	@echo "'onos' clones onos if does not exist in the workspace."
	@echo "Uses current workspace unless above vars are defined."
	@echo ""

## Make targets

onos: ## : Checkout onos code
	# Clone onos if it does not exist
	if [ ! -d "onos" ]; then \
		git clone https://gerrit.onosproject.org/onos; \
	fi
# Both are not supported
ifdef ONOS_BRANCH
ifdef ONOS_REVIEW
	@echo "Too many parameters. You cannot specify branch and review."
	exit 1
else
	cd ${ONOS_ROOT} && git checkout ${ONOS_BRANCH}
endif
else
ifdef ONOS_REVIEW
	cd ${ONOS_ROOT} && git review -d ${ONOS_REVIEW}
endif
endif

onos-build: onos ## : Builds the tost-onos docker image
	# Set some env variables
	cd ${ONOS_ROOT} && \
	. tools/build/envDefaults && \
	docker build . -t ${ONOS_IMAGENAME} \
	--build-arg PROFILE=${ONOS_PROFILE}

onos-push: ## : Pushes the tost-onos docker image to an external repository
	docker push ${ONOS_IMAGENAME}

tost-build: ## : Builds the tost docker image
	# TBD

tost-push: ## : Pushes the tost-onos docker image to an external repository
	# TBD

# Used for CI job
docker-build: onos-build tost-build ## : Builds the tost-onos and tost images

# User for CD job
docker-push: onos-push tost-push ## : Pushes the tost-onos and tost images

clean: ## : Deletes any locally copied files or artificats
	rm -rf onos

# end file
