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
CURRENT_UID              := $(shell id -u)
CURRENT_GID              := $(shell id -g)
MKFILE_PATH              := $(abspath $(lastword $(MAKEFILE_LIST)))
CURRENT_DIR              := $(patsubst %/,%,$(dir $(MKFILE_PATH)))
LOCAL_APPS               := local-apps
# Do not attach stdin if running in an environment without it (e.g., Jenkins)
IT                       := $(shell test -t 0 && echo "-it" || echo "-t")

# Docker related
DOCKER_REGISTRY          ?=
DOCKER_REPOSITORY        ?=
DOCKER_BUILD_ARGS        ?=
DOCKER_TAG               ?= ${VERSION}
DOCKER_MVN_TAG           := 3.6.3-openjdk-11-slim
DOCKER_MVN_IMAGE         := maven:${DOCKER_MVN_TAG}

# Docker labels. Only set ref and commit date if committed
DOCKER_LABEL_VCS_URL     ?= $(shell git remote get-url $(shell git remote))
DOCKER_LABEL_BUILD_DATE  ?= $(shell date -u "+%Y-%m-%dT%H:%M:%SZ")
DOCKER_LABEL_COMMIT_DATE  = $(shell git show -s --format=%cd --date=iso-strict HEAD)

ifeq ($(shell git ls-files --others --modified --exclude-standard 2>/dev/null | wc -l | sed -e 's/ //g'),0)
  DOCKER_LABEL_VCS_REF = $(shell git rev-parse HEAD)
else
  DOCKER_LABEL_VCS_REF = $(shell git rev-parse HEAD)+dirty
endif

# ONOS related
ONOS_IMAGENAME               := tost-onos
ONOS_BRANCH                  ?=
ONOS_REVIEW                  ?=
export ONOS_ROOT             := $(shell pwd)/onos
ONOS_PROFILE                 := "tost"
KARAF_VERSION                := 4.2.9

# TOST related
TOST_IMAGENAME               := ${DOCKER_REGISTRY}${DOCKER_REPOSITORY}tost:${DOCKER_TAG}

# Trellis-Control related
TRELLIS_CONTROL_BRANCH       ?=
TRELLIS_CONTROL_REVIEW       ?=
TRELLIS_CONTROL_MVN          ?=
TRELLIS_CONTROL_ROOT         := $(shell pwd)/trellis-control
TRELLIS_CONTROL_GROUPID      := org.onosproject
TRELLIS_CONTROL_ARTIFACTID   := segmentrouting-oar
TRELLIS_CONTROL_ARTIFACT     := ${TRELLIS_CONTROL_GROUPID}:${TRELLIS_CONTROL_ARTIFACTID}
TRELLIS_CONTROL_VERSION      := 3.0.0-SNAPSHOT

# Trellis-T3 related
TRELLIS_T3_BRANCH            ?=
TRELLIS_T3_REVIEW            ?=
TRELLIS_T3_MVN               ?=
TRELLIS_T3_ROOT              := $(shell pwd)/trellis-t3
TRELLIS_T3_GROUPID           := org.onosproject
TRELLIS_T3_ARTIFACTID        := t3-app
TRELLIS_T3_ARTIFACT          := ${TRELLIS_T3_GROUPID}:${TRELLIS_T3_ARTIFACTID}
TRELLIS_T3_VERSION           := 3.0.0-SNAPSHOT

# Fabric-Tofino related
FABRIC_TOFINO_BRANCH         ?=
FABRIC_TOFINO_REVIEW         ?=
FABRIC_TOFINO_MVN            ?=
FABRIC_TOFINO_ROOT           := $(shell pwd)/fabric-tofino
FABRIC_TOFINO_GROUPID        := org.opencord
FABRIC_TOFINO_ARTIFACTID     := fabric-tofino
FABRIC_TOFINO_ARTIFACT       := ${FABRIC_TOFINO_GROUPID}:${FABRIC_TOFINO_ARTIFACTID}
FABRIC_TOFINO_VERSION        := 1.1.1-SNAPSHOT
FABRIC_TOFINO_TARGETS        := fabric-spgw
FABRIC_TOFINO_SDE_DOCKER_IMG := opennetworking/bf-sde:9.0.0-p4c
FABRIC_TOFINO_P4CFLAGS       := "-DS1U_SGW_PREFIX='(8w192++8w0++8w0++8w0)' -DS1U_SGW_PREFIX_LEN=8"

# Up4 related
UP4_BRANCH                   ?=
OMECPROJECT_API              ?=
UP4_ROOT                     := $(shell pwd)/up4
UP4_ARTIFACTID               := up4-app
UP4_VERSION                  := 1.0.0-SNAPSHOT
UP4_TARGETS                  := _prepare_app_build
ifeq ($(OMECPROJECT_API),)
  UP4_REPO = https://github.com/omec-project/up4.git
else
  UP4_REPO = https://omecproject:${OMECPROJECT_API}@github.com/omec-project/up4.git
endif

# Kafka-onos related
KAFKA_ONOS_BRANCH            ?=
KAKFA_ONOS_REVIEW            ?=
KAFKA_ONOS_MVN               ?=
KAFKA_ONOS_ROOT              := $(shell pwd)/kafka-onos
KAFKA_ONOS_GROUPID           := org.opencord
KAFKA_ONOS_ARTIFACTID        := kafka
KAFKA_ONOS_ARTIFACT          := ${KAFKA_ONOS_GROUPID}:${KAFKA_ONOS_ARTIFACTID}
KAFKA_ONOS_VERSION           := 2.4.0-SNAPSHOT

# Fabric-TNA related
FABRIC_TNA_BRANCH            ?=
ONOS_BUILDER_API             ?=
FABRIC_TNA_ROOT              := $(shell pwd)/fabric-tna
FABRIC_TNA_ARTIFACTID        := fabric-tna
FABRIC_TNA_VERSION           := 1.0.0-SNAPSHOT
FABRIC_TNA_TARGETS           := fabric fabric-spgw
FABRIC_TNA_SDE_DOCKER_IMG    := opennetworking/bf-sde:9.2.0-p4c

ifeq ($(ONOS_BUILDER_API),)
  FABRIC_TNA_REPO = https://github.com/stratum/fabric-tna.git
else
  FABRIC_TNA_REPO = https://onos-builder:${ONOS_BUILDER_API}@github.com/stratum/fabric-tna.git
endif

.PHONY:

.SILENT: up4 fabric-tna

# This should to be the first and default target in this Makefile
help: ## : Print this help
	@echo "Usage: make [<target>]"
	@echo "where available targets are:"
	@echo
	@grep '^[[:alnum:]_-]*:.* ##' $(MAKEFILE_LIST) \
	| sort | awk 'BEGIN {FS=":.* ## "}; {printf "%-25s %s\n", $$1, $$2};'
	@echo
	@echo "Environment variables:"
	@echo "ONOS_BRANCH               : Define to use the following branch to build the image"
	@echo "ONOS_REVIEW               : Define to use the following review to build the image"
	@echo "TRELLIS_CONTROL_BRANCH    : Define to use the following branch to build the image"
	@echo "TRELLIS_CONTROL_REVIEW    : Define to use the following review to build the image"
	@echo "TRELLIS_CONTROL_MVN       : Define to download the app using mvn"
	@echo "TRELLIS_T3_BRANCH         : Define to use the following branch to build the image"
	@echo "TRELLIS_T3_REVIEW         : Define to use the following review to build the image"
	@echo "TRELLIS_T3_MVN            : Define to download the app using mvn"
	@echo "FABRIC_TOFINO_BRANCH      : Define to use the following branch to build the image"
	@echo "FABRIC_TOFINO_REVIEW      : Define to use the following review to build the image"
	@echo "FABRIC_TOFINO_MVN         : Define to download the app using mvn"
	@echo "UP4_BRANCH                : Define to use the following branch to build the image"
	@echo "KAFKA_ONOS_BRANCH         : Define to use the following branch to build the image"
	@echo "KAFKA_ONOS_REVIEW         : Define to use the following review to build the image"
	@echo "KAFKA_ONOS_MVN            : Define to download the app using mvn"
	@echo "FABRIC_TNA_BRANCH         : Define to use the following branch to build the image"
	@echo ""
	@echo "'onos' clones onos if it does not exist in the workspace."
	@echo "Uses current workspace unless above vars are defined."
	@echo ""
	@echo "'trellis-control' clones trellis-control if it does not exist in the workspace."
	@echo "Uses current workspace unless above vars are defined."
	@echo ""
	@echo "'trellis-t3' clones trellis-t3 if it does not exist in the workspace."
	@echo "Uses current workspace unless above vars are defined."
	@echo ""
	@echo "'fabric-tofino' clones fabric-tofino if it does not exist in the workspace."
	@echo "Uses current workspace unless above vars are defined."
	@echo ""
	@echo "'up4' clones up4 if it does not exist in the workspace."
	@echo "Uses current workspace unless above vars are defined."
	@echo ""
	@echo "'kafka-onos' clones kafka-onos if it does not exist in the workspace."
	@echo "Uses current workspace unless above vars are"
	@echo ""
	@echo "'fabric-tna' clones fabric-tna if it does not exist in the workspace."
	@echo "Uses current workspace unless above vars are"
	@echo ""

## Make targets

mvn_settings.xml: mvn_settings.sh ## : Builds mvn_settings file for proxy
	@./$<

local-apps: ## : Creates the folder that will host the oar file
	mkdir -p ${LOCAL_APPS}/

trellis-control: ## : Checkout trellis-control code
	# Clones trellis-control if it does not exist
	if [ ! -d "trellis-control" ]; then \
		git clone https://gerrit.onosproject.org/trellis-control; \
	fi
# Both are not supported
ifdef TRELLIS_CONTROL_BRANCH
ifdef TRELLIS_CONTROL_REVIEW
	@echo "Too many parameters. You cannot specify branch and review."
	exit 1
else
	cd ${TRELLIS_CONTROL_ROOT} && git checkout ${TRELLIS_CONTROL_BRANCH}
endif
else
ifdef TRELLIS_CONTROL_REVIEW
	cd ${TRELLIS_CONTROL_ROOT} && git review -d ${TRELLIS_CONTROL_REVIEW}
endif
endif

trellis-control-build: mvn_settings.xml local-apps trellis-control  ## : Builds trellis-control using local app or mvn
	# Settings are needed by both build processes - contains proxy settings and extra
	cp mvn_settings.xml ${TRELLIS_CONTROL_ROOT}/
ifdef TRELLIS_CONTROL_MVN
	# Dependencies are needed only by the mvn copy - contains repo settings
	cp dependencies.xml ${TRELLIS_CONTROL_ROOT}/
	# Mounting the current dir allows to cache the .m2 folder that is persisted and leveraged by subsequent builds
	docker run ${IT} --rm -v ${CURRENT_DIR}:/root -w /root/trellis-control ${DOCKER_MVN_IMAGE} \
		bash -c "mvn dependency:copy -Dartifact=${TRELLIS_CONTROL_ARTIFACT}:${TRELLIS_CONTROL_VERSION}:oar \
		-DoutputDirectory=oar/target -Dmdep.useBaseVersion=true \
		-Dmdep.overWriteReleases=true -Dmdep.overWriteSnapshots=true -f dependencies.xml \
		-s mvn_settings.xml; \
		chown -R ${CURRENT_UID}:${CURRENT_GID} /root"
else
	# Having the same mount file allows to reduce build time.
	docker run ${IT} --rm -v ${CURRENT_DIR}:/root -w /root/trellis-control ${DOCKER_MVN_IMAGE} \
		bash -c "mvn clean install -s mvn_settings.xml; \
		chown -R ${CURRENT_UID}:${CURRENT_GID} /root"
endif
	# Final step requires to move the oar to the folder used by the tost docker file
	cp ${TRELLIS_CONTROL_ROOT}/oar/target/${TRELLIS_CONTROL_ARTIFACTID}-${TRELLIS_CONTROL_VERSION}.oar ${LOCAL_APPS}/

trellis-t3: ## : Checkout trellis-t3 code
	if [ ! -d "trellis-t3" ]; then \
		git clone https://gerrit.onosproject.org/trellis-t3; \
	fi
ifdef TRELLIS_T3_BRANCH
ifdef TRELLIS_T3_REVIEW
	@echo "Too many parameters. You cannot specify branch and review."
	exit 1
else
	cd ${TRELLIS_T3_ROOT} && git checkout ${TRELLIS_T3_BRANCH}
endif
else
ifdef TRELLIS_T3_REVIEW
	cd ${TRELLIS_T3_ROOT} && git review -d ${TRELLIS_T3_REVIEW}
endif
endif

trellis-t3-build: mvn_settings.xml local-apps trellis-t3  ## : Builds trellis-t3 using local app or mvn
	cp mvn_settings.xml ${TRELLIS_T3_ROOT}/
ifdef TRELLIS_T3_MVN
	cp dependencies.xml ${TRELLIS_T3_ROOT}/
	docker run ${IT} --rm -v ${CURRENT_DIR}:/root -w /root/trellis-t3 ${DOCKER_MVN_IMAGE} \
		bash -c "mvn dependency:copy -Dartifact=${TRELLIS_T3_ARTIFACT}:${TRELLIS_T3_VERSION}:oar \
		-DoutputDirectory=app/target -Dmdep.useBaseVersion=true \
		-Dmdep.overWriteReleases=true -Dmdep.overWriteSnapshots=true -f dependencies.xml \
		-s mvn_settings.xml; \
		chown -R ${CURRENT_UID}:${CURRENT_GID} /root"
else
	docker run ${IT} --rm -v ${CURRENT_DIR}:/root -w /root/trellis-t3 ${DOCKER_MVN_IMAGE} \
		bash -c "mvn clean install -s mvn_settings.xml; \
		chown -R ${CURRENT_UID}:${CURRENT_GID} /root"
endif
	cp ${TRELLIS_T3_ROOT}/app/target/${TRELLIS_T3_ARTIFACTID}-${TRELLIS_T3_VERSION}.oar ${LOCAL_APPS}/

fabric-tofino: ## : Checkout fabric-tofino code
	if [ ! -d "fabric-tofino" ]; then \
		git clone https://gerrit.opencord.org/fabric-tofino; \
	fi
ifdef FABRIC_TOFINO_BRANCH
ifdef FABRIC_TOFINO_REVIEW
	@echo "Too many parameters. You cannot specify branch and review."
	exit 1
else
	cd ${FABRIC_TOFINO_ROOT} && git checkout ${FABRIC_TOFINO_BRANCH}
endif
else
ifdef FABRIC_TOFINO_REVIEW
	cd ${FABRIC_TOFINO_ROOT} && git review -d ${FABRIC_TOFINO_REVIEW}
endif
endif

fabric-tofino-build: mvn_settings.xml local-apps fabric-tofino  ## : Builds fabric-tofino using local app or mvn
	cp mvn_settings.xml ${FABRIC_TOFINO_ROOT}/
ifdef FABRIC_TOFINO_MVN
	cp dependencies.xml ${FABRIC_TOFINO_ROOT}/
	docker run ${IT} --rm -v ${CURRENT_DIR}:/root -w /root/fabric-tofino ${DOCKER_MVN_IMAGE} \
		bash -c "mvn dependency:copy -Dartifact=${FABRIC_TOFINO_ARTIFACT}:${FABRIC_TOFINO_VERSION}:oar \
		-DoutputDirectory=target -Dmdep.useBaseVersion=true \
		-Dmdep.overWriteReleases=true -Dmdep.overWriteSnapshots=true -f dependencies.xml \
		-s mvn_settings.xml; \
		chown -R ${CURRENT_UID}:${CURRENT_GID} /root"
else
	# This workaround is temporary - typically we need to build only the pipeconf
	cd ${FABRIC_TOFINO_ROOT} && make ${FABRIC_TOFINO_TARGETS} SDE_DOCKER_IMG=${FABRIC_TOFINO_SDE_DOCKER_IMG} \
		P4CFLAGS=${FABRIC_TOFINO_P4CFLAGS}
	docker run ${IT} --rm -v ${CURRENT_DIR}:/root -w /root/fabric-tofino ${DOCKER_MVN_IMAGE} \
		bash -c "mvn clean install -s mvn_settings.xml; \
		chown -R ${CURRENT_UID}:${CURRENT_GID} /root"
endif
	cp ${FABRIC_TOFINO_ROOT}/target/${FABRIC_TOFINO_ARTIFACTID}-${FABRIC_TOFINO_VERSION}.oar ${LOCAL_APPS}/

up4: ## : Checkout up4 code
	if [ ! -d "up4" ]; then \
		git clone ${UP4_REPO}; \
	fi
ifdef UP4_BRANCH
	cd ${UP4_ROOT} && git checkout ${UP4_BRANCH}
endif

up4-build: mvn_settings.xml local-apps up4  ## : Builds up4 using local app
	cp mvn_settings.xml ${UP4_ROOT}/app
	# Copy the p4 reources inside the app before the actual build
	cd ${UP4_ROOT} && make ${UP4_TARGETS}
	docker run ${IT} --rm -v ${CURRENT_DIR}:/root -w /root/up4/app ${DOCKER_MVN_IMAGE} \
		bash -c "mvn clean install -s mvn_settings.xml; \
		chown -R ${CURRENT_UID}:${CURRENT_GID} /root"
	cp ${UP4_ROOT}/app/app/target/${UP4_ARTIFACTID}-${UP4_VERSION}.oar ${LOCAL_APPS}/

kafka-onos: ## : Checkout kafka-onos code
	if [ ! -d "kafka-onos" ]; then \
		git clone https://gerrit.opencord.org/kafka-onos; \
	fi
ifdef KAFKA_ONOS_BRANCH
ifdef KAFKA_ONOS_REVIEW
	@echo "Too many parameters. You cannot specify branch and review."
	exit 1
else
	cd ${KAFKA_ONOS_ROOT} && git checkout ${KAFKA_ONOS_BRANCH}
endif
else
ifdef KAFKA_ONOS_REVIEW
	cd ${KAFKA_ONOS_ROOT} && git review -d ${KAFKA_ONOS_REVIEW}
endif
endif

kafka-onos-build: mvn_settings.xml local-apps kafka-onos  ## : Builds kafka-onos using local app or mvn
	cp mvn_settings.xml ${KAFKA_ONOS_ROOT}/
ifdef KAFKA_ONOS_MVN
	cp dependencies.xml ${KAFKA_ONOS_ROOT}/
	docker run ${IT} --rm -v ${CURRENT_DIR}:/root -w /root/kafka-onos ${DOCKER_MVN_IMAGE} \
		bash -c "mvn dependency:copy -Dartifact=${KAFKA_ONOS_ARTIFACT}:${KAFKA_ONOS_VERSION}:oar \
		-DoutputDirectory=target -Dmdep.useBaseVersion=true \
		-Dmdep.overWriteReleases=true -Dmdep.overWriteSnapshots=true -f dependencies.xml \
		-s mvn_settings.xml; \
		chown -R ${CURRENT_UID}:${CURRENT_GID} /root"
else
	docker run ${IT} --rm -v ${CURRENT_DIR}:/root -w /root/kafka-onos ${DOCKER_MVN_IMAGE} \
		bash -c "mvn clean install -s mvn_settings.xml; \
		chown -R ${CURRENT_UID}:${CURRENT_GID} /root"
endif
	cp ${KAFKA_ONOS_ROOT}/target/${KAFKA_ONOS_ARTIFACTID}-${KAFKA_ONOS_VERSION}.oar ${LOCAL_APPS}/

fabric-tna: ## : Checkout fabric-tna code
	if [ ! -d "fabric-tna" ]; then \
		git clone ${FABRIC_TNA_REPO}; \
	fi
ifdef FABRIC_TNA_BRANCH
	cd ${FABRIC_TNA_ROOT} && git checkout ${FABRIC_TNA_BRANCH}
endif

fabric-tna-build: mvn_settings.xml local-apps fabric-tna  ## : Builds fabric-tna using local app
	cp mvn_settings.xml ${FABRIC_TNA_ROOT}/
	# Rebuilds the artifact and the pipeconf
	cd ${FABRIC_TNA_ROOT} && make ${FABRIC_TNA_TARGETS} SDE_DOCKER_IMG=${FABRIC_TNA_SDE_DOCKER_IMG}
	docker run ${IT} --rm -v ${CURRENT_DIR}:/root -w /root/fabric-tna ${DOCKER_MVN_IMAGE} \
		bash -c "mvn clean install -s mvn_settings.xml; \
		chown -R ${CURRENT_UID}:${CURRENT_GID} /root"
	cp ${FABRIC_TNA_ROOT}/target/${FABRIC_TNA_ARTIFACTID}-${FABRIC_TNA_VERSION}.oar ${LOCAL_APPS}/

onos: ## : Checkout onos code
	if [ ! -d "onos" ]; then \
		git clone https://gerrit.onosproject.org/onos; \
	fi
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

apps-build: trellis-control-build trellis-t3-build fabric-tofino-build up4-build kafka-onos-build fabric-tna-build ## : Build the onos apps

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
    --build-arg org_onosproject_vcs_commit_date="${DOCKER_LABEL_COMMIT_DATE}" \
    -f Dockerfile.tost .

onos-push: ## : Pushes the tost-onos docker image to an external repository
	docker push ${ONOS_IMAGENAME}

tost-push: ## : Pushes the tost docker image to an external repository
	docker push ${TOST_IMAGENAME}

# Used for CI job
docker-build: onos-build apps-build tost-build ## : Builds the tost image

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
