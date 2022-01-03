#!/bin/bash

#
# Copyright 2022-present Open Networking Foundation
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

# This script is run inside a container (minideb:buster) with ONOS codebase sitting in ONOS_ROOT env var
set -eu -o pipefail

# install dependencies required by the onos-publish script
apt-get update && apt-get install -y curl build-essential python python-pip
pip install requests
curl -L -o bazelisk https://github.com/bazelbuild/bazelisk/releases/download/v1.5.0/bazelisk-linux-amd64
chmod +x bazelisk && mv bazelisk /usr/bin/bazel

#shellcheck source=/dev/null
source "${ONOS_ROOT}"/tools/dev/bash_profile

cd "${ONOS_ROOT}"
onos-publish -l
