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

ARG DOCKER_TAG

# We start from a base onos image and install the apps.
FROM onos-base:${DOCKER_TAG} as install

ARG KARAF_VERSION
ARG LOCAL_APPS

# ENV settings
ENV ONOS=/root/onos
ENV KARAF_ROOT=${ONOS}/apache-karaf-$KARAF_VERSION
ENV APPS_ROOT=${ONOS}/apps
ENV KARAF_M2=${KARAF_ROOT}/system
ENV DOWNLOAD_ROOT=/download
ENV APP_INSTALL_ROOT=/expand

# Copy the apps to the install stage container
COPY $LOCAL_APPS/ ${DOWNLOAD_ROOT}/

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    unzip && \
    rm -rf /var/lib/apt/lists/*

WORKDIR ${DOWNLOAD_ROOT}

# Install the applications
COPY app-install.sh ./app-install.sh
RUN chmod 755 ./app-install.sh
RUN ./app-install.sh

ARG DOCKER_TAG

# Create the final image coping over the installed applications from the install stage
FROM onos-base:${DOCKER_TAG}

ARG KARAF_VERSION

# The ENV settings must be replicated below as they are not shared between stages
ENV ONOS=/root/onos
ENV KARAF_ROOT=${ONOS}/apache-karaf-$KARAF_VERSION
ENV KARAF_M2=${KARAF_ROOT}/system
ENV APPS_ROOT=${ONOS}/apps

COPY --from=install ${KARAF_M2}/ ${KARAF_M2}/
COPY --from=install ${APPS_ROOT}/ ${APPS_ROOT}/

# Label image
ARG org_label_schema_version=unknown
ARG org_label_schema_vcs_url=unknown
ARG org_label_schema_vcs_ref=unknown
ARG org_label_schema_build_date=unknown
ARG org_onosproject_onos_version=unknown
ARG org_onosproject_trellis_control_version=unknown
ARG org_omecproject_up4_version=unknown
ARG org_stratumproject_fabric_tna_version=unknown

LABEL org.label-schema.schema-version=1.0 \
      org.label-schema.name=sdfabric-onos \
      org.label-schema.version=$org_label_schema_version \
      org.label-schema.vcs-url=$org_label_schema_vcs_url \
      org.label-schema.vcs-ref=$org_label_schema_vcs_ref \
      org.label-schema.build-date=$org_label_schema_build_date \
      org.onosproject.onos.version=$org_onosproject_onos_version \
      org.onosproject.trellis-control.version=$org_onosproject_trellis_control_version \
      org.omecproject.up4.version=$org_omecproject_up4_version \
      org.stratumproject.fabric-tna.version=$org_stratumproject_fabric_tna_version
