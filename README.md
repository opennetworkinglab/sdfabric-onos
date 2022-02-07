# SD-Fabric ONOS Development Build Environment

This repository contains scripts required to build `sdfabric-onos`, a Docker image containing **ONOS** and other apps that make the SD-Fabric control plane.

## Build

We provide multiple build targets for the Makefile. Versions of the components are defined in `Makefile.vars.*` files; `stable` version points to well known stable commits and `master` branch points to **ONOS** master and to the tip of external apps. **DOCKER_TAG** is used to select which version to build, by default points to `stable`.

`onos-build` is used to build a specialized **Docker** image of **ONOS** that will contain only a subset of the ONOS built-in apps. It depends on `onos` target, which is used to setup the `onos` workspace for the build. It clones `onos` if it does not exist in the workspace, it will try to checkout the **ONOS_VERSION** first and in case of failure will try to download the patchset from remote repository. **ONOS_VERSION** is defined in `Makefile.vars.DOCKER_TAG` file, overriding the variable at run time it is possible to build a different version of **ONOS**.


```sh
# Build an onos image from the current workspace.
make onos-build
```

```sh
# Build an onos image from the tip of the onos-2.2 branch.
make ONOS_VERSION=onos-2.2 onos-build
```

```sh
# Build an onos image from the change number/review 12345.
make ONOS_VERSION=ref/changes/72/12345/1 onos-build
```

Makefile will build also the apps. These are the apps currently integrated in the script: **trellis-control**, **up4** and **fabric-tna**. For each one, there is a **build** target.

`appname-build` builds with the version specified in the `Makefile.vars.DOCKER_TAG`, using the following sources in order: (1) Maven central (for released versions or snapshots); (2) Local source code (for local branch not yet pushed); (3) Gerrit/Github (for pending review in the form of refs/changes/... or pending pull request). As a prerequisite, the script prepares `mvn_settings.xml` file, creates the `local-apps` folder and checks out the code if it is not present (relies on `appname` target). **APPNAME_VERSION**, defined in `Makefile.vars.DOCKER_TAG` file, can be overridden at runtime.


```sh
# Build trellis-control from the source code.
make trellis-control-build
```

```sh
# Build up4 app from the source code.
make up4-build
```

`apps-build` is an additional target that automates the build process of the apps building one by one all the apps.

```sh
# Build one by one all the apps.
make apps-build
```

Finally, the last build target is `build`. It builds a `sdfabric-onos` monolithic including the `onos-base` image plus the external apps. It does not activate all the required apps. This step is performed during the deployment. The required apps are usually specified in the Helm chart.

```sh
# Build a sdfabric-onos image from the current workspace.
make package
```

### Build with custom ONOS API changes
When doing ONOS API changes, we don't want to fetch ONOS maven artifacts from the
remote sonatype SNAPSHOT repository. To do so, we need to set an environment variable
(`USE_LOCAL_SNAPSHOT_ARTIFACTS=true`) and follow a specific order when building the
final `sdfabric-onos` image.

1. ONOS (this will also publish the ONOS maven artifacts in  the local `.m2` folder):
   `USE_LOCAL_SNAPSHOT_ARTIFACTS=true [DOCKER_TAG=master] make onos-build`
2. Trellis Control, UP4:
   `USE_LOCAL_SNAPSHOT_ARTIFACTS=true [DOCKER_TAG=master] make trellis-control-build up4-build`
3. Fabric TNA:
   `USE_LOCAL_SNAPSHOT_ARTIFACTS=true [DOCKER_TAG=master] make fabric-tna-build`
4. Final image (`sdfabric-onos`):
   `USE_LOCAL_SNAPSHOT_ARTIFACTS=true [DOCKER_TAG=master] make package`

### Build with custom changes in the repositories
It is not always possible to build images with the latests changes, as sometimes hotfixes need to be delivered quickly in order to fix the issues identified in production. Hereafter the steps to build images with custom changes not yet merged - please note that we don't have the full flexibility provided by a separated “production” branch which means that sometimes the following workflow could not be realizable.

1. `ONOS`
1.1 Identify a stable commit that has been well tested and do reset to that commit
1.2 Take a note about the `SNAPSHOT` version
1.3 Organize the hotfixes as a train (on top of each other)
1.4 Rebase the train on top of the stable commit
1.5 Write the `ref/changes` path of the tip patch in the `Makefile.vars.stable` file

2. `trellis-control`
2.1 Identify a stable commit that has been well tested and do reset to that commit
2.2 Take a note about the `SNAPSHOT` version
2.3 Organize the hotfixes as a train (on top of each other)
2.4 Rebase the train on top of the stable commit
2.5 Update the `onos-dependencies` to the `ONOS SNAPSHOT` version and push a review
2.6 Write the `ref/changes` path of the step `2.5` in the `Makefile.vars.stable` file

3. `fabric-tna`
3.1 Identify a stable commit that has been well tested and do reset to that commit
3.2 Create a branch out of the stable commit; update the `onos-dependencies` to the `ONOS SNAPSHOT` version and the `trellis-api` version to the `trellis-control SNAPSHOT` version and push a patch
3.3 Merge all the hotfixes in the branch created at the step `4.2` and push a new commit
3.4 Write the branch name created at the step `4.2` in the `Makefile.vars.stable` file, alternatively the PR number using `pull/#PR/head`

4. `up4`
4.1 Identify a stable commit that has been well tested and do reset to that commit
4.2 Create a branch out of the stable commit; update the `onos-dependencies` to the `ONOS SNAPSHOT` version and push a patch
4.3 Merge all the hotfixes in the branch created at the step `5.2` and push a new commit
4.4 Write the branch name created at the step `5.2` in the `Makefile.vars.stable` file, alternatively the PR number using `pull/#PR/head`

5. Build a stable image with the `docker-build` target using the locally built maven artifacts
    `USE_LOCAL_SNAPSHOT_ARTIFACTS=true DOCKER_TAG=stable make docker-build`

## Update

Use `apps` or `appname` targets to downloads commits, files, and refs from remotes.


```sh
# Update one by one all the apps.
make apps
```

## Clean

Use `clean` target to remove the local artificats generated by the tool.

```sh
# Cleans the workspace.
make clean
```

## Push

We provide multiple push target for the Makefile. Typically, you need to first login by `docker login` command to push the image on a repository.

`onos-push` will push the `onos-base` image.

```sh
make onos-push
```

`push` will push the `sdfabric-onos` image to the defined **DOCKER_REGISTRY** and **DOCKER_REPOSITORY**.

```sh
make DOCKER_REPOSITORY=opennetworking/ push
```

## CI/CD targets

There are two special targets used by the CI/CD jobs: `docker-build` and `docker-push`. The first target automates the build process of the `sdfabric-onos` image (`check-scripts`, `onos-build`, `apps-build` and `package`). While the second one is just an alias for `push`. Feel free to use them if you are ok with the prerequisites steps.
