#!/bin/bash

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

http_proxy=${http_proxy:-}
https_proxy=${https_proxy:-}
no_proxy=${no_proxy:-}

if [ -f mvn_settings.custom.xml ] ; then
  cp mvn_settings.custom.xml mvn_settings.xml
  exit 0
fi

cat << EOF > mvn_settings.xml
<?xml version="1.0" encoding="UTF-8"?>

<!--
Licensed to the Apache Software Foundation (ASF) under one
or more contributor license agreements.  See the NOTICE file
distributed with this work for additional information
regarding copyright ownership.  The ASF licenses this file
to you under the Apache License, Version 2.0 (the
"License"); you may not use this file except in compliance
with the License.  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing,
software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, either express or implied.  See the License for the
specific language governing permissions and limitations
under the License.
-->

<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 http://maven.apache.org/xsd/settings-1.0.0.xsd">
  <!--PROXY-->
  <!--EXTRA-->
  <!--MIRRORS-->
</settings>
EOF

if [ "$http_proxy$https_proxy" != "" ] ; then
  echo "  <proxies>" >> mvn_settings.proxy.xml
  for PROTOCOL in http https ; do
    proxy="${PROTOCOL}_proxy"
    proxy="${!proxy}"
    if [ "$proxy" = "" ] ; then continue ; fi

    # username/password not yet included
    PROXY_HOST=$(echo "$proxy" | sed "s@.*://@@;s/.*@//;s@:.*@@")
    PROXY_PORT=$(echo "$proxy" | sed "s@.*://@@;s@.*:@@;s@/.*@@")
    NON_PROXY=$(echo "$no_proxy" | sed "s@,@|@g")

    echo "   <proxy>
      <id>$PROTOCOL</id>
      <active>true</active>
      <protocol>$PROTOCOL</protocol>
      <host>$PROXY_HOST</host>
      <port>$PROXY_PORT</port>
      <nonProxyHosts>$NON_PROXY</nonProxyHosts>
    </proxy>" >> mvn_settings.proxy.xml
  done
  echo "  </proxies>" >> mvn_settings.proxy.xml

  sed -i '/<!--PROXY-->/r mvn_settings.proxy.xml' mvn_settings.xml
  rm mvn_settings.proxy.xml
fi

if [ "$USE_LOCAL_SNAPSHOT_ARTIFACTS" == "true" ]; then
  # When using local SNAPSHOT artifacts, we need to prevent maven to fetch from the Sonatype repository.
  # However, we need to point to a valid maven repository otherwise maven fails. For this reason we
  # mirror snapshots to maven central (that won't contain any SNAPSHOT artifacts).
  echo "    <mirrors>
      <mirror>
        <id>central_snapshots</id>
        <name>central_snapshots</name>
        <url>https://repo.maven.apache.org/maven2</url>
        <mirrorOf>snapshots</mirrorOf>
      </mirror>
    </mirrors>" >> mvn_settings.mirror.xml
  sed -i '' -e '/<!--MIRRORS-->/r mvn_settings.mirror.xml' mvn_settings.xml
  rm mvn_settings.mirror.xml
fi

if [ -f mvn_settings.extra.xml ] ; then
  sed -i 's/<!--EXTRA-->/r mvn_settings.extra.xml' mvn_settings.xml
fi
