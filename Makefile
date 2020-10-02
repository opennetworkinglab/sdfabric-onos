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
VERSION                      ?= $(shell cat ./VERSION)
THIS_MAKE                    := $(lastword $(MAKEFILE_LIST))

# Docker related
DOCKER_REGISTRY              ?=
DOCKER_REPOSITORY            ?=
DOCKER_BUILD_ARGS            ?=
DOCKER_TAG                   ?= ${VERSION}

# Docker labels. Only set ref and commit date if committed
DOCKER_LABEL_VCS_URL         ?= $(shell git remote get-url $(shell git remote))
DOCKER_LABEL_BUILD_DATE      ?= $(shell date -u "+%Y-%m-%dT%H:%M:%SZ")
DOCKER_LABEL_COMMIT_DATE      = $(shell git show -s --format=%cd --date=iso-strict HEAD)

ifeq ($(shell git ls-files --others --modified --exclude-standard 2>/dev/null | wc -l | sed -e 's/ //g'),0)
  DOCKER_LABEL_VCS_REF = $(shell git rev-parse HEAD)
else
  DOCKER_LABEL_VCS_REF = $(shell git rev-parse HEAD)+dirty
endif

# Includes the default ("working") versions of each component
include ./Makefile.vars

# Shellcheck related
SHELLCHECK_TAG=v0.7.1
SHELLCHECK_IMAGE=koalaman/shellcheck:${SHELLCHECK_TAG}

# ONOS related
ONOS_IMAGENAME               := tost-onos
export ONOS_ROOT             := $(shell pwd)/onos
ONOS_REPO                    := https://gerrit.onosproject.org/onos
ONOS_PROFILE                 := "tost"
KARAF_VERSION                := 4.2.9

# TOST related
TOST_IMAGENAME               := ${DOCKER_REGISTRY}${DOCKER_REPOSITORY}tost:${DOCKER_TAG}
export LOCAL_APPS            := local-apps

# Trellis-Control related
export TRELLIS_CONTROL_ROOT  := $(shell pwd)/trellis-control
export TRELLIS_CONTROL_REPO  := https://gerrit.onosproject.org/trellis-control

# Trellis-T3 related
export TRELLIS_T3_ROOT       := $(shell pwd)/trellis-t3
export TRELLIS_T3_REPO       := https://gerrit.onosproject.org/trellis-t3

# Fabric-Tofino related
export FABRIC_TOFINO_ROOT    := $(shell pwd)/fabric-tofino
export FABRIC_TOFINO_REPO    := https://gerrit.opencord.org/fabric-tofino

# Up4 related
export UP4_ROOT              := $(shell pwd)/up4
export UP4_REPO              := git@github.com:omec-project/up4.git

# Kafka-onos related
export KAFKA_ONOS_ROOT       := $(shell pwd)/kafka-onos
export KAFKA_ONOS_REPO       := https://gerrit.opencord.org/kafka-onos

# Fabric-TNA related
export FABRIC_TNA_ROOT       := $(shell pwd)/fabric-tna
export FABRIC_TNA_REPO       := git@github.com:stratum/fabric-tna.git

.PHONY: onos trellis-control trellis-t3 fabric-tofino up4 kafka-onos fabric-tna

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
	@echo "FABRIC_TOFINO_VERSION     : Override to use a specific branch/commit/tag/release to build the image"
	@echo "UP4_VERSION               : Override to use a specific branch/commit/tag/release to build the image"
	@echo "KAFKA_ONOS_VERSION        : Override to use a specific branch/commit/tag/release to build the image"
	@echo "FABRIC_TNA_VERSION        : Override to use a specific branch/commit/tag/release to build the image"
	@echo ""
	@echo "'Makefile.vars' defines default values for '*_VERSION' variables".
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

	# Try the git checkout first otherwise we download the review
	if ! (cd ${TRELLIS_CONTROL_ROOT} && git checkout ${TRELLIS_CONTROL_VERSION}); then \
	if ! (cd ${TRELLIS_CONTROL_ROOT} && git fetch ${TRELLIS_CONTROL_REPO} ${TRELLIS_CONTROL_VERSION} && git checkout FETCH_HEAD); then \
		echo "Unable to fetch the changes from the trellis-control repository"; \
	fi \
	fi

trellis-control-build: mvn_settings.xml local-apps trellis-control  ## : Builds trellis-control using local app or mvn
	@./app-build.sh $@

trellis-control-update: ## : downloads commits, files, and refs from remote trellis-control
	cd ${TRELLIS_CONTROL_ROOT} && git fetch

	# Try to pull - but fails if we have not checked a branch
	if ! (cd ${TRELLIS_CONTROL_ROOT} && git pull); then \
		echo "Unable to pull from the trellis-control repository"; \
		exit 1; \
	fi

trellis-t3: ## : Checkout trellis-t3 code
	if [ ! -d "trellis-t3" ]; then \
		git clone ${TRELLIS_T3_REPO}; \
	fi

	@modified=$$(cd ${TRELLIS_T3_ROOT} && git status --porcelain); \
	if [ ! -z "$${modified}" ]; then \
		echo "Unable to checkout, you have pending changes in trellis-t3 repository"; \
		exit 1; \
	fi

	if ! (cd ${TRELLIS_T3_ROOT} && git checkout ${TRELLIS_T3_VERSION}); then \
	if ! (cd ${TRELLIS_T3_ROOT} && git fetch ${TRELLIS_T3_REPO} ${TRELLIS_T3_VERSION} && git checkout FETCH_HEAD); then \
		echo "Unable to fetch the changes from the trellis-t3 repository"; \
	fi \
	fi

trellis-t3-build: mvn_settings.xml local-apps trellis-t3  ## : Builds trellis-t3 using local app or mvn
	@./app-build.sh $@

trellis-t3-update: ## : downloads commits, files, and refs from remote trellis-t3
	cd ${TRELLIS_T3_ROOT} && git fetch

	if ! (cd ${TRELLIS_T3_ROOT} && git pull); then \
		echo "Unable to pull from the trellis-t3 repository"; \
		exit 1; \
	fi

fabric-tofino: ## : Checkout fabric-tofino code
	if [ ! -d "fabric-tofino" ]; then \
		git clone ${FABRIC_TOFINO_REPO}; \
	fi

	@modified=$$(cd ${FABRIC_TOFINO_ROOT} && git status --porcelain); \
	if [ ! -z "$${modified}" ]; then \
		echo "Unable to checkout, you have pending changes in fabric-tofino repository"; \
		exit 1; \
	fi

	if ! (cd ${FABRIC_TOFINO_ROOT} && git checkout ${FABRIC_TOFINO_VERSION}); then \
	if ! (cd ${FABRIC_TOFINO_ROOT} && git fetch ${FABRIC_TOFINO_REPO} ${FABRIC_TOFINO_VERSION} && git checkout FETCH_HEAD); then \
		echo "Unable to fetch the changes from the fabric-tofino repository"; \
		exit 1; \
	fi \
	fi

fabric-tofino-build: mvn_settings.xml local-apps fabric-tofino  ## : Builds fabric-tofino using local app or mvn
	@./app-build.sh $@

fabric-tofino-update: ## : downloads commits, files, and refs from remote fabric-tofino
	cd ${FABRIC_TOFINO_ROOT} && git fetch

	if ! (cd ${FABRIC_TOFINO_ROOT} && git pull); then \
		echo "Unable to pull from the fabric-tofino repository"; \
		exit 1; \
	fi

up4: ## : Checkout up4 code
	if [ ! -d "up4" ]; then \
		git clone ${UP4_REPO}; \
	fi

	@modified=$$(cd ${UP4_ROOT} && git status --porcelain); \
	if [ ! -z "$${modified}" ]; then \
		echo "Unable to checkout, you have pending changes in up4 repository"; \
		exit 1; \
	fi

	if ! (cd ${UP4_ROOT} && git checkout ${UP4_VERSION}); then \
	if ! (cd ${UP4_ROOT} && git fetch ${UP4_REPO} ${UP4_VERSION} && git checkout FETCH_HEAD); then \
		echo "Unable to fetch the changes from the up4 repository"; \
		exit 1; \
	fi \
	fi

up4-build: mvn_settings.xml local-apps up4  ## : Builds up4 using local app
	@./app-build.sh $@

up4-update: ## : downloads commits, files, and refs from remote up4
	cd ${UP4_ROOT} && git fetch

	if ! (cd ${UP4_ROOT} && git pull); then \
		echo "Unable to pull from the up4 repository"; \
		exit 1; \
	fi

kafka-onos: ## : Checkout kafka-onos code
	if [ ! -d "kafka-onos" ]; then \
		git clone ${KAFKA_ONOS_REPO}; \
	fi

	@modified=$$(cd ${KAFKA_ONOS_ROOT} && git status --porcelain); \
	if [ ! -z "$${modified}" ]; then \
		echo "Unable to checkout, you have pending changes in kafka-onos repository"; \
		exit 1; \
	fi

	if ! (cd ${KAFKA_ONOS_ROOT} && git checkout ${KAFKA_ONOS_VERSION}); then \
	if ! (cd ${KAFKA_ONOS_ROOT} && git fetch ${KAFKA_ONOS_REPO} ${KAFKA_ONOS_VERSION} && git checkout FETCH_HEAD); then \
		echo "Unable to fetch the changes from the kafka-onos repository"; \
	fi \
	fi

kafka-onos-build: mvn_settings.xml local-apps kafka-onos  ## : Builds kafka-onos using local app or mvn
	@./app-build.sh $@

kafka-onos-update: ## : downloads commits, files, and refs from remote kafka-onos
	cd ${KAFKA_ONOS_ROOT} && git fetch

	if ! (cd ${KAFKA_ONOS_ROOT} && git pull); then \
		echo "Unable to pull from the kafka-onos repository"; \
		exit 1; \
	fi

fabric-tna: ## : Checkout fabric-tna code
	if [ ! -d "fabric-tna" ]; then \
		git clone ${FABRIC_TNA_REPO}; \
	fi

	@modified=$$(cd ${FABRIC_TNA_ROOT} && git status --porcelain); \
	if [ ! -z "$${modified}" ]; then \
		echo "Unable to checkout, you have pending changes in fabric-tna repository"; \
		exit 1; \
	fi

	if ! (cd ${FABRIC_TNA_ROOT} && git checkout ${FABRIC_TNA_VERSION}); then \
	if ! (cd ${FABRIC_TNA_ROOT} && git fetch ${FABRIC_TNA_REPO} ${FABRIC_TNA_VERSION} && git checkout FETCH_HEAD); then \
		echo "Unable to fetch the changes from the fabric-tna repository"; \
		exit 1; \
	fi \
	fi

fabric-tna-build: mvn_settings.xml local-apps fabric-tna  ## : Builds fabric-tna using local app
	@./app-build.sh $@

fabric-tna-update: ## : downloads commits, files, and refs from remote fabric-tna
	cd ${FABRIC_TNA_ROOT} && git fetch

	if ! (cd ${FABRIC_TNA_ROOT} && git pull); then \
		echo "Unable to pull from the fabric-tna repository"; \
		exit 1; \
	fi

apps-update: trellis-control-update trellis-t3-update fabric-tofino-update up4-update kafka-onos-update fabric-tna-update ## : downloads commits, files, and refs from remotes

apps-build: trellis-control-build trellis-t3-build fabric-tofino-build up4-build kafka-onos-build fabric-tna-build ## : Build the onos apps

onos: ## : Checkout onos code
	if [ ! -d "onos" ]; then \
		git clone https://gerrit.onosproject.org/onos; \
	fi

	@modified=$$(cd ${ONOS_ROOT} && git status --porcelain); \
	if [ ! -z "$${modified}" ]; then \
		echo "Unable to checkout, you have pending changes in onos repository"; \
		exit 1; \
	fi

	# In case of failure, we do not proceed because we cannot build with mvn
	if ! (cd ${ONOS_ROOT} && git checkout ${ONOS_VERSION}); then \
	if ! (cd ${ONOS_ROOT} && git fetch ${ONOS_REPO} ${ONOS_VERSION} && git checkout FETCH_HEAD); then \
		echo "Unable to fetch the changes from the onos repository"; \
		exit 1; \
	fi \
	fi

onos-update: ## : downloads commits, files, and refs from remote onos
	cd ${ONOS_ROOT} && git fetch

	if ! (cd ${ONOS_ROOT} && git pull); then \
		echo "Unable to pull from the onos repository"; \
		exit 1; \
	fi

onos-build: onos ## : Builds the tost-onos docker image
	# Set some env variables
	cd ${ONOS_ROOT} && \
	. tools/build/envDefaults && \
	docker build . -t ${ONOS_IMAGENAME} \
	--build-arg PROFILE=${ONOS_PROFILE}

tost-build: ## : Builds the tost docker image
	docker build $(DOCKER_BUILD_ARGS) \
    -t ${TOST_IMAGENAME} \
    --build-arg LOCAL_APPS=${LOCAL_APPS} \
    --build-arg KARAF_VERSION=${KARAF_VERSION} \
    --build-arg org_label_schema_version="${VERSION}" \
    --build-arg org_label_schema_vcs_url="${DOCKER_LABEL_VCS_URL}" \
    --build-arg org_label_schema_vcs_ref="${DOCKER_LABEL_VCS_REF}" \
    --build-arg org_label_schema_build_date="${DOCKER_LABEL_BUILD_DATE}" \
    --build-arg org_onosproject_onos_version="${ONOS_VERSION}"\
    --build-arg org_onosproject_trellis_control_version="${TRELLIS_CONTROL_VERSION}"\
    --build-arg org_onosproject_trellis_t3_version="${TRELLIS_T3_VERSION}"\
    --build-arg org_opencord_fabric_tofino_version="${FABRIC_TOFINO_VERSION}"\
    --build-arg org_omecproject_up4_version="${UP4_VERSION}"\
    --build-arg org_opencord_kafka_onos_version="${KAFKA_ONOS_VERSION}"\
    --build-arg org_stratumproject_fabric_tna_version="${FABRIC_TNA_VERSION}"\
    -f Dockerfile.tost .

onos-push: ## : Pushes the tost-onos docker image to an external repository
	docker push ${ONOS_IMAGENAME}

tost-push: ## : Pushes the tost docker image to an external repository
	docker push ${TOST_IMAGENAME}

# Used for CI job
docker-build: check-scripts onos-build apps-build tost-build ## : Builds the tost image

# User for CD job
docker-push: tost-push ## : Pushes the tost image

clean: ## : Deletes any locally copied files or artifacts
	rm -rf ${ONOS_ROOT}
	rm -rf ${TRELLIS_CONTROL_ROOT}
	rm -rf ${TRELLIS_T3_ROOT}
	rm -rf ${FABRIC_TOFINO_ROOT}
	rm -rf ${UP4_ROOT}
	rm -rf ${KAFKA_ONOS_ROOT}
	rm -rf ${FABRIC_TNA_ROOT}
	rm -rf ${LOCAL_APPS}
	rm -rf .m2
	rm -rf mvn_settings.xml

# end file
