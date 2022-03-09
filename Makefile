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
SHELL                        := /bin/bash -e -o pipefail

# General variables
THIS_MAKE                    := $(lastword $(MAKEFILE_LIST))

# Docker related
DOCKER_REGISTRY              ?=
DOCKER_REPOSITORY            ?= opennetworking/sdfabric-onos
DOCKER_BUILD_ARGS            ?=
DOCKER_TAG                   ?= stable
DOCKER_TAG_BUILD_DATE        ?=
DOCKER_TAG_PROFILER          ?=

# Docker labels. Only set ref and commit date if committed
DOCKER_LABEL_VCS_URL         ?= $(shell git remote get-url $(shell git remote))
DOCKER_LABEL_BUILD_DATE      ?= $(shell date -u "+%Y-%m-%dT%H:%M:%SZ")
DOCKER_LABEL_COMMIT_DATE      = $(shell git show -s --format=%cd --date=iso-strict HEAD)

ifeq ($(shell git ls-files --others --modified --exclude-standard 2>/dev/null | wc -l | sed -e 's/ //g'),0)
  DOCKER_LABEL_VCS_REF = $(shell git rev-parse HEAD)
else
  DOCKER_LABEL_VCS_REF = $(shell git rev-parse HEAD)+dirty
endif

ifeq ($(DOCKER_TAG),stable)
# Includes the default ("working") versions of each component
  include ./Makefile.vars.stable
else ifeq ($(DOCKER_TAG),master)
# Includes the master versions of each component
  include ./Makefile.vars.master
else
  $(error You must define properly the DOCKER_TAG variable)
endif

FINAL_IMAGENAME               := ${DOCKER_REGISTRY}${DOCKER_REPOSITORY}:${DOCKER_TAG}${DOCKER_TAG_PROFILER}${DOCKER_TAG_BUILD_DATE}
export LOCAL_APPS             := local-apps

# Shellcheck related
SHELLCHECK_TAG=v0.7.1
SHELLCHECK_IMAGE=koalaman/shellcheck:${SHELLCHECK_TAG}

# ONOS related
ONOS_BASE_IMAGENAME          := onos-base:${DOCKER_TAG}${DOCKER_TAG_PROFILER}${DOCKER_TAG_BUILD_DATE}
export ONOS_ROOT             := $(shell pwd)/onos
ONOS_REPO                    := https://gerrit.onosproject.org/onos
# This profile contains the minimal set of ONOS built-in apps required to control SD-Fabric.
ONOS_PROFILE                 := "sdfabric"
PROFILER                     ?=
ONOS_YOURKIT                 := 2021.3-b230
USE_ONOS_BAZEL_OUTPUT        ?=
USE_LOCAL_SNAPSHOT_ARTIFACTS ?=
KARAF_VERSION                := 4.2.14

# Trellis-Control related
export TRELLIS_CONTROL_ROOT  := $(shell pwd)/trellis-control
export TRELLIS_CONTROL_REPO  := https://gerrit.onosproject.org/trellis-control

# Trellis-T3 related
export TRELLIS_T3_ROOT       := $(shell pwd)/trellis-t3
export TRELLIS_T3_REPO       := https://gerrit.onosproject.org/trellis-t3

# Up4 related
export UP4_ROOT              := $(shell pwd)/up4
export UP4_REPO              := git@github.com:omec-project/up4.git

# Fabric-TNA related
export FABRIC_TNA_ROOT       := $(shell pwd)/fabric-tna
export FABRIC_TNA_REPO       := git@github.com:stratum/fabric-tna.git

.PHONY: onos trellis-control up4 fabric-tna

.SILENT: up4 fabric-tna

# This should to be the first and default target in this Makefile
help: ## : Print this help
	@echo "Usage: make [<target>]"
	@echo "where available targets are:"
	@echo
	@grep '^[[:alnum:]_-]*:.* ##' $(THIS_MAKE) \
	| sort | awk 'BEGIN {FS=":.* ## "}; {printf "%-25s %s\n", $$1, $$2};'
	@echo
	@echo "Environment variables:"
	@echo "ONOS_VERSION              : Override to use a specific branch/commit/tag/release to build the image"
	@echo "TRELLIS_CONTROL_VERSION   : Override to use a specific branch/commit/tag/release to build the image"
	@echo "TRELLIS_T3_VERSION        : Override to use a specific branch/commit/tag/release to build the image"
	@echo "UP4_VERSION               : Override to use a specific branch/commit/tag/release to build the image"
	@echo "FABRIC_TNA_VERSION        : Override to use a specific branch/commit/tag/release to build the image"
	@echo ""
	@echo "'Makefile.vars.stable' defines the stable values for '*_VERSION' variables".
	@echo "'Makefile.vars.master' defines the tip values for '*_VERSION' variables".
	@echo ""

## Make targets

check-scripts: ## : Provides warnings and suggestions for bash/sh shell scripts
	# Fail if any of these files have warnings, exclude sed replacement warnings
	docker run --rm -v "${PWD}:/mnt" ${SHELLCHECK_IMAGE} *.sh -e SC2001

mvn_settings.xml: mvn_settings.sh ## : Builds mvn_settings file for proxy
	@./$<

local-apps: ## : Creates the folder that will host the oar file
	mkdir -p ${LOCAL_APPS}/

trellis-control: ## : Checkout trellis-control code
	# Clones trellis-control if it does not exist
	if [ ! -d "trellis-control" ]; then \
		git clone ${TRELLIS_CONTROL_REPO}; \
	fi

	# Pending changes - do not proceed
	@modified=$$(cd ${TRELLIS_CONTROL_ROOT} && git status --porcelain); \
	if [ ! -z "$${modified}" ]; then \
		echo "Unable to checkout, you have pending changes in trellis-control repository"; \
		exit 1; \
	fi

	# Updates the repo and avoids any stale branches
	cd ${TRELLIS_CONTROL_ROOT} && git remote update

	# Try the git checkout first otherwise we download the review
	if ! (cd ${TRELLIS_CONTROL_ROOT} && (git checkout origin/${TRELLIS_CONTROL_VERSION} || git checkout ${TRELLIS_CONTROL_VERSION})); then \
	if ! (cd ${TRELLIS_CONTROL_ROOT} && git fetch ${TRELLIS_CONTROL_REPO} ${TRELLIS_CONTROL_VERSION} && git checkout FETCH_HEAD); then \
		echo "Unable to fetch the changes from the trellis-control repository"; \
	fi \
	fi

trellis-control-build: mvn_settings.xml .onos-publish-local local-apps trellis-control  ## : Builds trellis-control using local app or mvn
	@./app-build.sh $@

trellis-t3: ## : Checkout trellis-t3 code
	if [ ! -d "trellis-t3" ]; then \
		git clone ${TRELLIS_T3_REPO}; \
	fi

	@modified=$$(cd ${TRELLIS_T3_ROOT} && git status --porcelain); \
	if [ ! -z "$${modified}" ]; then \
		echo "Unable to checkout, you have pending changes in trellis-t3 repository"; \
		exit 1; \
	fi

	cd ${TRELLIS_T3_ROOT} && git remote update

	if ! (cd ${TRELLIS_T3_ROOT} && (git checkout origin/${TRELLIS_T3_VERSION} || git checkout ${TRELLIS_T3_VERSION})); then \
	if ! (cd ${TRELLIS_T3_ROOT} && git fetch ${TRELLIS_T3_REPO} ${TRELLIS_T3_VERSION} && git checkout FETCH_HEAD); then \
		echo "Unable to fetch the changes from the trellis-t3 repository"; \
	fi \
	fi

trellis-t3-build: mvn_settings.xml .onos-publish-local local-apps trellis-t3  ## : Builds trellis-t3 using local app or mvn
	@./app-build.sh $@

up4: ## : Checkout up4 code
	if [ ! -d "up4" ]; then \
		git clone ${UP4_REPO}; \
	fi

	@modified=$$(cd ${UP4_ROOT} && git status --porcelain); \
	if [ ! -z "$${modified}" ]; then \
		echo "Unable to checkout, you have pending changes in up4 repository"; \
		exit 1; \
	fi

	cd ${UP4_ROOT} && git remote update

	if ! (cd ${UP4_ROOT} && (git checkout origin/${UP4_VERSION} || git checkout ${UP4_VERSION})); then \
	if ! (cd ${UP4_ROOT} && git fetch ${UP4_REPO} ${UP4_VERSION} && git checkout FETCH_HEAD); then \
		echo "Unable to fetch the changes from the up4 repository"; \
		exit 1; \
	fi \
	fi

up4-build: mvn_settings.xml .onos-publish-local local-apps up4  ## : Builds up4 using local app
	@./app-build.sh $@

fabric-tna: ## : Checkout fabric-tna code
	if [ ! -d "fabric-tna" ]; then \
		git clone ${FABRIC_TNA_REPO}; \
	fi

	@modified=$$(cd ${FABRIC_TNA_ROOT} && git status --porcelain); \
	if [ ! -z "$${modified}" ]; then \
		echo "Unable to checkout, you have pending changes in fabric-tna repository"; \
		exit 1; \
	fi

	cd ${FABRIC_TNA_ROOT} && git remote update

	if ! (cd ${FABRIC_TNA_ROOT} && (git checkout origin/${FABRIC_TNA_VERSION} || git checkout ${FABRIC_TNA_VERSION})); then \
	if ! (cd ${FABRIC_TNA_ROOT} && git fetch ${FABRIC_TNA_REPO} ${FABRIC_TNA_VERSION} && git checkout FETCH_HEAD); then \
		echo "Unable to fetch the changes from the fabric-tna repository"; \
		exit 1; \
	fi \
	fi

fabric-tna-build: mvn_settings.xml .onos-publish-local local-apps fabric-tna  ## : Builds fabric-tna using local app
	@./app-build.sh $@

## : downloads commits, files, and refs from remotes. Intentionally leave out t3.
apps: trellis-control up4 fabric-tna

## : Build the onos apps. Intentionally leave out t3.
apps-build: trellis-control-build up4-build fabric-tna-build

onos: ## : Checkout onos code
	if [ ! -d "onos" ]; then \
		git clone https://gerrit.onosproject.org/onos; \
	fi

	@modified=$$(cd ${ONOS_ROOT} && git status --porcelain); \
	if [ ! -z "$${modified}" ]; then \
		echo "Unable to checkout, you have pending changes in onos repository"; \
		exit 1; \
	fi

	cd ${ONOS_ROOT} && git remote update

	# In case of failure, we do not proceed because we cannot build with mvn
	if ! (cd ${ONOS_ROOT} && (git checkout origin/${ONOS_VERSION} || git checkout ${ONOS_VERSION})); then \
	if ! (cd ${ONOS_ROOT} && git fetch ${ONOS_REPO} ${ONOS_VERSION} && git checkout FETCH_HEAD); then \
		echo "Unable to fetch the changes from the onos repository"; \
		exit 1; \
	fi \
	fi

onos-build: onos ## : Builds the onos-base docker image
	rm -rf .onos-publish-local
ifeq ($(PROFILER),true)
	# profiler enabled
	cd ${ONOS_ROOT} && \
	. tools/build/envDefaults && \
	docker build . -t ${ONOS_BASE_IMAGENAME} \
	--build-arg PROFILE=${ONOS_PROFILE} \
	--build-arg ONOS_YOURKIT=${ONOS_YOURKIT} \
	-f tools/dev/Dockerfile-yourkit
else ifeq ($(USE_ONOS_BAZEL_OUTPUT),true)
	# profiler not enabled, using local bazel output
	cd ${ONOS_ROOT} && \
	. tools/build/envDefaults && \
	bazel build onos --define profile=${ONOS_PROFILE}
	docker build -t ${ONOS_BASE_IMAGENAME} -f ${ONOS_ROOT}/tools/dev/Dockerfile-bazel ${ONOS_ROOT}/bazel-bin
else
	# profiler not enabled
	cd ${ONOS_ROOT} && \
	. tools/build/envDefaults && \
	docker build . -t ${ONOS_BASE_IMAGENAME} \
	--build-arg PROFILE=${ONOS_PROFILE}
endif
	make .onos-publish-local

.onos-publish-local:
ifeq ($(USE_LOCAL_SNAPSHOT_ARTIFACTS),true)
	@# TODO: build custom docker container with required dependencies instead of installing via publish-local script
	docker run --rm --entrypoint bash -it -v $(shell pwd)/:/src \
	-e ONOS_ROOT=/src/onos -e MAVEN_REPO=/src/.m2/repository -w /src \
	bitnami/minideb:buster ./publish-local.sh
endif
	touch .onos-publish-local

package: ## : Builds the sdfabric-onos docker image
	docker build $(DOCKER_BUILD_ARGS) \
    -t ${FINAL_IMAGENAME} \
    --build-arg DOCKER_TAG="${DOCKER_TAG}${DOCKER_TAG_PROFILER}${DOCKER_TAG_BUILD_DATE}" \
    --build-arg LOCAL_APPS=${LOCAL_APPS} \
    --build-arg KARAF_VERSION=${KARAF_VERSION} \
    --build-arg org_label_schema_version="${DOCKER_TAG}${DOCKER_TAG_PROFILER}${DOCKER_TAG_BUILD_DATE}" \
    --build-arg org_label_schema_vcs_url="${DOCKER_LABEL_VCS_URL}" \
    --build-arg org_label_schema_vcs_ref="${DOCKER_LABEL_VCS_REF}" \
    --build-arg org_label_schema_build_date="${DOCKER_LABEL_BUILD_DATE}" \
    --build-arg org_onosproject_onos_version="$(shell cd ${ONOS_ROOT} && git rev-parse HEAD)"\
    --build-arg org_onosproject_trellis_control_version="$(shell cd ${TRELLIS_CONTROL_ROOT} && git rev-parse HEAD)"\
    --build-arg org_omecproject_up4_version="$(shell cd ${UP4_ROOT} && git rev-parse HEAD)"\
    --build-arg org_stratumproject_fabric_tna_version="$(shell cd ${FABRIC_TNA_ROOT} && git rev-parse HEAD)"\
    -f Dockerfile .

onos-push: ## : Pushes the onos-base docker image to an external repository
	docker push ${ONOS_BASE_IMAGENAME}

push: ## : Pushes the sdfabric-onos docker image to an external repository
	docker push ${FINAL_IMAGENAME}

# Used for CI job
docker-build: check-scripts onos-build apps-build package ## : Builds the sdfabric-onos image

# User for CD job
docker-push: push ## : Pushes the sdfabric-onos Docker image

clean: ## : Deletes any locally copied files or artifacts
	rm -rf ${ONOS_ROOT}
	rm -rf ${TRELLIS_CONTROL_ROOT}
	rm -rf ${TRELLIS_T3_ROOT}
	rm -rf ${UP4_ROOT}
	rm -rf ${FABRIC_TNA_ROOT}
	rm -rf ${LOCAL_APPS}
	rm -rf .m2
	rm -rf mvn_settings.xml
	rm -rf .onos-publish-local

# end file
