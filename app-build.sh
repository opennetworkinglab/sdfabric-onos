#!/bin/bash

# Copyright 2020-present Open Networking Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Build the apps

# General purposes vars
CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)
CURRENT_DIR=$(pwd)
MVN=1
PROJECT_VERSION=0

# Docker related vars
DOCKER_MVN_TAG=3.6.3-openjdk-11-slim
DOCKER_MVN_IMAGE=maven:${DOCKER_MVN_TAG}

# Do not attach stdin if running in an environment without it (e.g., Jenkins)
IT=$(test -t 0 && echo "-it" || echo "-t")

# Trellis-control related vars
TRELLIS_CONTROL_GROUPID=org.onosproject
TRELLIS_CONTROL_ARTIFACTID=segmentrouting-app
TRELLIS_CONTROL_ARTIFACT=${TRELLIS_CONTROL_GROUPID}:${TRELLIS_CONTROL_ARTIFACTID}
TRELLIS_CONTROL_OAR=${TRELLIS_CONTROL_ROOT}/app/target/${TRELLIS_CONTROL_ARTIFACTID}-${TRELLIS_CONTROL_VERSION}.oar

# Trellis-t3 related vars
TRELLIS_T3_GROUPID=org.onosproject
TRELLIS_T3_ARTIFACTID=t3-app
TRELLIS_T3_ARTIFACT=${TRELLIS_T3_GROUPID}:${TRELLIS_T3_ARTIFACTID}
TRELLIS_T3_OAR=${TRELLIS_T3_ROOT}/app/target/${TRELLIS_T3_ARTIFACTID}-${TRELLIS_T3_VERSION}.oar

# Fabric-tofino related vars
FABRIC_TOFINO_GROUPID=org.opencord
FABRIC_TOFINO_ARTIFACTID=fabric-tofino
FABRIC_TOFINO_ARTIFACT=${FABRIC_TOFINO_GROUPID}:${FABRIC_TOFINO_ARTIFACTID}
FABRIC_TOFINO_TARGETS=(fabric-spgw)
FABRIC_TOFINO_SDE_DOCKER_IMG=opennetworking/bf-sde:9.0.0-p4c
FABRIC_TOFINO_P4CFLAGS="-DS1U_SGW_PREFIX='(8w192++8w0++8w0++8w0)' -DS1U_SGW_PREFIX_LEN=8"
FABRIC_TOFINO_OAR=${FABRIC_TOFINO_ROOT}/target/${FABRIC_TOFINO_ARTIFACTID}-${FABRIC_TOFINO_VERSION}.oar

# UP4 related vars
UP4_GROUPID=org.omecproject
UP4_ARTIFACTID=up4-app
UP4_ARTIFACT=${UP4_GROUPID}:${UP4_ARTIFACTID}
UP4_TARGETS=_prepare_app_build
UP4_OAR=${UP4_ROOT}/app/app/target/${UP4_ARTIFACTID}-${UP4_VERSION}.oar

# Kafka-onos related vars
KAFKA_ONOS_GROUPID=org.opencord
KAFKA_ONOS_ARTIFACTID=kafka
KAFKA_ONOS_ARTIFACT=${KAFKA_ONOS_GROUPID}:${KAFKA_ONOS_ARTIFACTID}
KAFKA_ONOS_OAR=${KAFKA_ONOS_ROOT}/target/${KAFKA_ONOS_ARTIFACTID}-${KAFKA_ONOS_VERSION}.oar

# Fabric-tna related vars
FABRIC_TNA_GROUPID=org.stratumproject
FABRIC_TNA_ARTIFACTID=fabric-tna
FABRIC_TNA_ARTIFACT=${FABRIC_TNA_GROUPID}:${FABRIC_TNA_ARTIFACTID}
FABRIC_TNA_TARGETS=(fabric fabric-spgw fabric-int fabric-spgw-int)
FABRIC_TNA_SDE_DOCKER_IMG=opennetworking/bf-sde:9.2.0-p4c
FABRIC_TNA_OAR=${FABRIC_TNA_ROOT}/target/${FABRIC_TNA_ARTIFACTID}-${FABRIC_TNA_VERSION}.oar

set -eu -o pipefail

function extract_version {
	# Enter in the project folder
	cd "$1" || exit 1
	# Verify if the VERSION file exists
	if [ -f "VERSION" ]; then
		NEW_VERSION=$(head -n1 "VERSION")
		# If this is a golang project, use funky v-prefixed versions
		if [ -f "Gopkg.toml" ] || [ -f "go.mod" ]; then
			PROJECT_VERSION=v${NEW_VERSION}
		else
			PROJECT_VERSION=${NEW_VERSION}
		fi
	# If this is a node.js project
	elif [ -f "package.json" ]; then
		NEW_VERSION=$(python -c 'import json,sys;obj=json.load(sys.stdin); print obj["version"]' < package.json)
		PROJECT_VERSION=${NEW_VERSION}
	# If this is a mvn project
	elif [ -f "pom.xml" ]; then
		NEW_VERSION=$(xmllint --xpath '/*[local-name()="project"]/*[local-name()="version"]/text()' pom.xml)
		PROJECT_VERSION=${NEW_VERSION}
	else
		echo "ERROR: No versioning file found!"
		exit 1
	fi
	cd ../
}

# Generic function to build an app
function build_app {
	# First step is to remove the oar dir
	rm -rf "$1"
	# Settings are needed by both build processes - contains proxy settings and extra
	cp mvn_settings.xml "$2"
	# Dependencies are needed only by the mvn copy - contains repo settings
	cp dependencies.xml "$2"
	# Mounting the current dir allows to cache the .m2 folder that is persisted and leveraged by subsequent builds
	docker run "${IT}" --rm -v "${CURRENT_DIR}":/root -w /root/"$3" "${DOCKER_MVN_IMAGE}" \
		bash -c "mvn dependency:copy -Dartifact=$4:$5:oar \
		-DoutputDirectory=$6 -Dmdep.useBaseVersion=true \
		-Dmdep.overWriteReleases=true -Dmdep.overWriteSnapshots=true -f dependencies.xml \
		-s mvn_settings.xml; \
		chown -R ${CURRENT_UID}:${CURRENT_GID} /root"
	# If the oar is not found - try to build using the source code
	if [ ! -f "$7" ]; then
		cd "$2" || exit 1
		# Verify for the last time if the VERSION is a checkout object or a review
		if ! (git checkout "origin/$5" || git checkout "$5"); then
			if ! (git fetch "$8" "$5" && git checkout FETCH_HEAD); then
				exit 1
			fi
		fi
		cd ../
		# Having the same mount file allows to reduce build time
		docker run "${IT}" --rm -v "${CURRENT_DIR}":/root -w /root/"$3" "${DOCKER_MVN_IMAGE}" \
			bash -c "mvn clean install -s mvn_settings.xml; \
			chown -R ${CURRENT_UID}:${CURRENT_GID} /root"
		# We need to override the version variable because it is not valid at this point
		MVN=0
	fi
}

function trellis-control-build {
	# Build function
	build_app "${TRELLIS_CONTROL_ROOT}"/app/target \
	"${TRELLIS_CONTROL_ROOT}"/ "trellis-control" \
	"${TRELLIS_CONTROL_ARTIFACT}" "${TRELLIS_CONTROL_VERSION}" \
	"app/target" "${TRELLIS_CONTROL_OAR}" "${TRELLIS_CONTROL_REPO}"
	# If MVN was not successful - built from sources
	if [ "$MVN" -eq "0" ]; then
		# Update VERSION
		extract_version "${TRELLIS_CONTROL_ROOT}"
		# Update OAR
		TRELLIS_CONTROL_OAR="${TRELLIS_CONTROL_ROOT}"/app/target/"${TRELLIS_CONTROL_ARTIFACTID}"-"${PROJECT_VERSION}".oar
	fi
	# Final step requires to move the oar to the folder used by the tost docker file. Moreover, it will help catch up errors
	cp "${TRELLIS_CONTROL_OAR}" "${LOCAL_APPS}"/
}

function trellis-t3-build {
	build_app "${TRELLIS_T3_ROOT}"/app/target \
	"${TRELLIS_T3_ROOT}"/ "trellis-t3" \
	"${TRELLIS_T3_ARTIFACT}" "${TRELLIS_T3_VERSION}" \
	"app/target" "${TRELLIS_T3_OAR}" "${TRELLIS_T3_REPO}"
	if [ "$MVN" -eq "0" ]; then
		extract_version "${TRELLIS_T3_ROOT}"
		TRELLIS_T3_OAR="${TRELLIS_T3_ROOT}"/app/target/"${TRELLIS_T3_ARTIFACTID}"-"${PROJECT_VERSION}".oar
	fi
	cp "${TRELLIS_T3_OAR}" "${LOCAL_APPS}"/
}

function fabric-tofino-build {
	# This workaround is temporary - typically we need to build only the pipeconf
	cd "${FABRIC_TOFINO_ROOT}" || exit 1 && make "${FABRIC_TOFINO_TARGETS[@]}" SDE_DOCKER_IMG="${FABRIC_TOFINO_SDE_DOCKER_IMG}" P4CFLAGS="${FABRIC_TOFINO_P4CFLAGS}"
	cd ../
	build_app "${FABRIC_TOFINO_ROOT}"/target \
	"${FABRIC_TOFINO_ROOT}"/ "fabric-tofino" \
	"${FABRIC_TOFINO_ARTIFACT}" "${FABRIC_TOFINO_VERSION}" \
	"target" "${FABRIC_TOFINO_OAR}" "${FABRIC_TOFINO_REPO}"
	if [ "$MVN" -eq "0" ]; then
		extract_version "${FABRIC_TOFINO_ROOT}"
		FABRIC_TOFINO_OAR="${FABRIC_TOFINO_ROOT}"/target/"${FABRIC_TOFINO_ARTIFACTID}"-"${PROJECT_VERSION}".oar
	fi
	cp "${FABRIC_TOFINO_OAR}" "${LOCAL_APPS}"/
	# Extra step to avoid build failure; clean up artifacts to ensure
	# the release process won't complain about uncommitted changes.
	cd "${FABRIC_TOFINO_ROOT}" || exit 1 && git checkout .
	cd ../
}

function up4-build {
	# Prepares app folder
	cd "${UP4_ROOT}" || exit 1 && make "${UP4_TARGETS}"
	cd ../
	build_app "${UP4_ROOT}"/app/app/target \
	"${UP4_ROOT}"/app "up4/app" \
	"${UP4_ARTIFACT}" "${UP4_VERSION}" \
	"app/app/target" "${UP4_OAR}" "${UP4_REPO}"
	if [ "$MVN" -eq "0" ]; then
		extract_version "${UP4_ROOT}"/app
		cd ../
		UP4_OAR="${UP4_ROOT}"/app/app/target/"${UP4_ARTIFACTID}"-"${PROJECT_VERSION}".oar
	fi
	cp "${UP4_OAR}" "${LOCAL_APPS}"/
}

function kafka-onos-build {
	build_app "${KAFKA_ONOS_ROOT}"/target \
	"${KAFKA_ONOS_ROOT}"/ "kafka-onos" \
	"${KAFKA_ONOS_ARTIFACT}" "${KAFKA_ONOS_VERSION}" \
	"target" "${KAFKA_ONOS_OAR}" "${KAFKA_ONOS_REPO}"
	if [ "$MVN" -eq "0" ]; then
		extract_version "${KAFKA_ONOS_ROOT}"
		KAFKA_ONOS_OAR="${KAFKA_ONOS_ROOT}"/target/"${KAFKA_ONOS_ARTIFACTID}"-"${PROJECT_VERSION}".oar
	fi
	cp "${KAFKA_ONOS_OAR}" "${LOCAL_APPS}"/
}

function fabric-tna-build {
	# This workaround is temporary - typically we need to build only the pipeconf
	cd "${FABRIC_TNA_ROOT}" || exit 1 && make "${FABRIC_TNA_TARGETS[@]}" SDE_DOCKER_IMG="${FABRIC_TNA_SDE_DOCKER_IMG}"
	cd ../
	build_app "${FABRIC_TNA_ROOT}"/target \
	"${FABRIC_TNA_ROOT}"/ "fabric-tna" \
	"${FABRIC_TNA_ARTIFACT}" "${FABRIC_TNA_VERSION}" \
	"target" "${FABRIC_TNA_OAR}" "${FABRIC_TNA_REPO}"
	if [ "$MVN" -eq "0" ]; then
		extract_version "${FABRIC_TNA_ROOT}"
		FABRIC_TNA_OAR="${FABRIC_TNA_ROOT}"/target/"${FABRIC_TNA_ARTIFACTID}"-"${PROJECT_VERSION}".oar
	fi
	cp "${FABRIC_TNA_OAR}" "${LOCAL_APPS}"/
}

"$1"
