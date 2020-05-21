SHELL = bash
# .ONESHELL:
# .SHELLFLAGS = -e
# See https://www.gnu.org/software/make/manual/html_node/Phony-Targets.html
.PHONY: default all build circleci-local-build check-binaries check-buildx check-docker-login docker-login-if-possible buildx-prepare \
        buildx TODO

## Caution: this Makefile has 'multiple entries', which means that it is 'calling himself'.
# For instance, if you call 'make circleci-local-build':
# 1. CircleCi cli is invoked
# 2. After have installed a build environment (inside a docker container), CircleCI will call "make" without parameter, which correspond to a 'make build-all-images' build (because of default target)
# 3. And 'build-all-images' target will run 4 times the "make all-one-image" for 4 different architecture (arm32v6, arm32v7, arm64v8 and amd64).

# DOCKER_REGISTRY: Nothing, or 'registry:5000/'
DOCKER_REGISTRY ?=
 # DOCKER_USERNAME: Nothing, or 'biarms'
DOCKER_USERNAME ?=
 # DOCKER_PASSWORD: Nothing, or '********'
DOCKER_PASSWORD ?=
 # BETA_VERSION: Nothing, or '-beta-123'
BETA_VERSION ?=
DOCKER_IMAGE_NAME = biarms/phpmyadmin
# Find latest release version on https://github.com/phpmyadmin/phpmyadmin/releases
DOCKER_IMAGE_VERSION = 5.0.2
DOCKER_IMAGE_TAGNAME = $(DOCKER_REGISTRY)$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_VERSION)-linux-$(ARCH)$(BETA_VERSION)
# See https://www.gnu.org/software/make/manual/html_node/Shell-Function.html
# BUILD_DATE=$(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
BUILD_DATE=$(shell date -u +"%Y-%m-%d") # rerunning builds are faster with this settings ;)
# See https://microbadger.com/labels
VCS_REF=$(shell git rev-parse --short HEAD)

PLATFORM ?= linux/arm/v7,linux/arm64/v8,linux/amd64
ARCH ?= arm64v8
LINUX_ARCH ?= aarch64
BUILD_ARCH = $(ARCH)/

# See https://github.com/docker-library/official-images#architectures-other-than-amd64
# |---------|------------|
# |  ARCH   | LINUX_ARCH |
# |---------|------------|
# |  amd64  |   x86_64   |
# | arm32v6 |   armv6l   |
# | arm32v7 |   armv7l   |
# | arm64v8 |   aarch64  |
# |---------|------------|

default: all

# 2 builds are implemented: build and buildx !
# all: check-docker-login build
all: check-docker-login buildx

build: build-all-images

# Launch a local build as on circleci, that will call the default target, but inside the 'circleci build and test env'
circleci-local-build: check-docker-login
	@ circleci local execute -e DOCKER_USERNAME="${DOCKER_USERNAME}" -e DOCKER_PASSWORD="${DOCKER_PASSWORD}"

check-binaries:
	@ which docker > /dev/null || (echo "Please install docker before using this script" && exit 1)
	@ which git > /dev/null || (echo "Please install git before using this script" && exit 2)
	@ # deprecated: which manifest-tool > /dev/null || (echo "Ensure that you've got the manifest-tool utility in your path. Could be downloaded from  https://github.com/estesp/manifest-tool/releases/" && exit 3)
	@ DOCKER_CLI_EXPERIMENTAL=enabled docker manifest --help | grep "docker manifest COMMAND" > /dev/null || (echo "docker manifest is needed. Consider upgrading docker" && exit 4)
	@ DOCKER_CLI_EXPERIMENTAL=enabled docker version -f '{{.Client.Experimental}}' | grep "true" > /dev/null || (echo "docker experimental mode is not enabled" && exit 5)
	# Debug info
	@ echo "DOCKER_REGISTRY: ${DOCKER_REGISTRY}"
	@ echo "BUILD_DATE: ${BUILD_DATE}"
	@ echo "VCS_REF: ${VCS_REF}"
	@ echo "DOCKER_IMAGE_TAGNAME: ${DOCKER_IMAGE_TAGNAME}"

check-buildx: check-binaries
	# Next line will fail if docker server can't be contacted
	docker version
	DOCKER_CLI_EXPERIMENTAL=enabled docker buildx version

check-docker-login: check-binaries
	@ if [[ "${DOCKER_USERNAME}" == "" ]]; then echo "DOCKER_USERNAME and DOCKER_PASSWORD env variables are mandatory for this kind of build"; exit -1; fi

docker-login-if-possible: check-binaries
	if [[ ! "${DOCKER_USERNAME}" == "" ]]; then echo "${DOCKER_PASSWORD}" | docker login --username "${DOCKER_USERNAME}" --password-stdin; fi

# See https://docs.docker.com/buildx/working-with-buildx/
buildx-prepare: check-buildx
	DOCKER_CLI_EXPERIMENTAL=enabled docker context create buildx-multi-arch-context || true
	DOCKER_CLI_EXPERIMENTAL=enabled docker buildx create buildx-multi-arch-context --name=buildx-multi-arch || true
	DOCKER_CLI_EXPERIMENTAL=enabled docker buildx use buildx-multi-arch

buildx: docker-login-if-possible buildx-prepare checkout
	DOCKER_CLI_EXPERIMENTAL=enabled docker buildx version
	cd docker/apache && \
	DOCKER_CLI_EXPERIMENTAL=enabled docker buildx build --progress plain -f Dockerfile --push --platform "${PLATFORM}" --tag "$(DOCKER_REGISTRY)${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_VERSION}${BETA_VERSION}" --build-arg VERSION="${DOCKER_IMAGE_VERSION}" --build-arg VCS_REF="${VCS_REF}" --build-arg BUILD_DATE="${BUILD_DATE}" .
	cd docker/apache && \
	DOCKER_CLI_EXPERIMENTAL=enabled docker buildx build --progress plain -f Dockerfile --push --platform "${PLATFORM}" --tag "$(DOCKER_REGISTRY)${DOCKER_IMAGE_NAME}:latest${BETA_VERSION}" --build-arg VERSION="${DOCKER_IMAGE_VERSION}" --build-arg VCS_REF="${VCS_REF}" --build-arg BUILD_DATE="${BUILD_DATE}" .

prepare: check-build install-qemu

# Test are qemu based. SHOULD_DO: use `docker buildx bake`. See https://github.com/docker/buildx#buildx-bake-options-target
install-qemu: check-binaries
	# @ # From https://github.com/multiarch/qemu-user-static:
	docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

uninstall-qemu: check-binaries
	docker run --rm --privileged multiarch/qemu-user-static:register --reset

check: check-binaries
	@ if [[ "$(DOCKER_IMAGE_VERSION)" == "" ]]; then \
	    echo 'DOCKER_IMAGE_VERSION is $(DOCKER_IMAGE_VERSION) (MUST BE SET !)' && \
	    echo 'Correct usage sample: ' && \
        echo '    ARCH=arm64v8 LINUX_ARCH=aarch64 DOCKER_IMAGE_VERSION=5.7.30 make' && \
	    echo '    or ' && \
        echo '    ARCH=arm64v8 LINUX_ARCH=aarch64 DOCKER_IMAGE_VERSION=5.7.30 make' && \
        exit -1; \
	fi
	@ if [[ "$(ARCH)" == "" ]]; then \
	    echo 'ARCH is $(ARCH) (MUST BE SET !)' && \
	    echo 'Correct usage sample: ' && \
        echo '    ARCH=arm64v8 LINUX_ARCH=aarch64 DOCKER_IMAGE_VERSION=5.7.30 make' && \
	    echo '    or ' && \
        echo '    ARCH=arm64v8 LINUX_ARCH=aarch64 DOCKER_IMAGE_VERSION=5.7.30 make' && \
        exit -2; \
	fi
	@ if [[ "$(LINUX_ARCH)" == "" ]]; then \
	    echo 'LINUX_ARCH is $(LINUX_ARCH) (MUST BE SET !)' && \
	    echo 'Correct usage sample: ' && \
	    echo '    ARCH=arm32v7 LINUX_ARCH=armv7l DOCKER_IMAGE_VERSION=5.7.30 make ' && \
	    echo '    or ' && \
        echo '    ARCH=arm64v8 LINUX_ARCH=aarch64 DOCKER_IMAGE_VERSION=5.7.30 make' && \
        exit -3; \
	fi

# build-all-one-image-arm32v6 => manifest for arm32v6/php:7.4-apache not found
build-all-images: prepare build-all-one-image-arm32v7 build-all-one-image-arm64v8 build-all-one-image-amd64

# Actually, the 'push' will only be done is DOCKER_USERNAME is set and not empty !
build-all-one-image: build-one-image test-one-image tag-one-image push-one-image

build-all-one-image-arm32v6: prepare
	ARCH=arm32v6 LINUX_ARCH=armv6l  make build-all-one-image

build-all-one-image-arm32v7: prepare
	ARCH=arm32v7 LINUX_ARCH=armv7l  make build-all-one-image

build-all-one-image-arm64v8: prepare
	ARCH=arm64v8 LINUX_ARCH=aarch64 make build-all-one-image

build-all-one-image-amd64: prepare
	ARCH=amd64   LINUX_ARCH=x86_64  make build-all-one-image

create-and-push-manifests: #ideally, should reference 'all-images', but that's boring when we test this script...
	# biarms/mysql:5.7.30
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create --amend "${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_VERSION}${BETA_VERSION}" "${DOCKER_IMAGE_NAME}:${MYSQL_VERSION_OTHER_ARCH}-linux-arm32v7${BETA_VERSION}" "${DOCKER_IMAGE_NAME}:${MYSQL_VERSION_OTHER_ARCH}-linux-arm64v8${BETA_VERSION}" "${DOCKER_IMAGE_NAME}:${MYSQL_VERSION_OTHER_ARCH}-linux-amd64${BETA_VERSION}"
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest annotate "${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_VERSION}${BETA_VERSION}" "${DOCKER_IMAGE_NAME}:${MYSQL_VERSION_OTHER_ARCH}-linux-arm32v7${BETA_VERSION}" --os linux --arch arm --variant v7
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest annotate "${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_VERSION}${BETA_VERSION}" "${DOCKER_IMAGE_NAME}:${MYSQL_VERSION_OTHER_ARCH}-linux-arm64v8${BETA_VERSION}" --os linux --arch arm64 --variant v8
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest annotate "${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_VERSION}${BETA_VERSION}" "${DOCKER_IMAGE_NAME}:${MYSQL_VERSION_OTHER_ARCH}-linux-amd64${BETA_VERSION}" --os linux --arch amd64
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest push "${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_VERSION}${BETA_VERSION}"
	# ${DOCKER_IMAGE_NAME}:latest
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest create --amend "${DOCKER_IMAGE_NAME}:latest${BETA_VERSION}" "${DOCKER_IMAGE_NAME}:${MYSQL_VERSION_ARM32V6}-linux-arm32v6${BETA_VERSION}" "${DOCKER_IMAGE_NAME}:${MYSQL_VERSION_OTHER_ARCH}-linux-arm32v7${BETA_VERSION}" "${DOCKER_IMAGE_NAME}:${MYSQL_VERSION_OTHER_ARCH}-linux-arm64v8${BETA_VERSION}" "${DOCKER_IMAGE_NAME}:${MYSQL_VERSION_OTHER_ARCH}-linux-amd64${BETA_VERSION}"
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest annotate "${DOCKER_IMAGE_NAME}:latest${BETA_VERSION}" "${DOCKER_IMAGE_NAME}:${MYSQL_VERSION_ARM32V6}-linux-arm32v6${BETA_VERSION}" --os linux --arch arm --variant v6
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest annotate "${DOCKER_IMAGE_NAME}:latest${BETA_VERSION}" "${DOCKER_IMAGE_NAME}:${MYSQL_VERSION_OTHER_ARCH}-linux-arm32v7${BETA_VERSION}" --os linux --arch arm --variant v7
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest annotate "${DOCKER_IMAGE_NAME}:latest${BETA_VERSION}" "${DOCKER_IMAGE_NAME}:${MYSQL_VERSION_OTHER_ARCH}-linux-arm64v8${BETA_VERSION}" --os linux --arch arm64 --variant v8
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest annotate "${DOCKER_IMAGE_NAME}:latest${BETA_VERSION}" "${DOCKER_IMAGE_NAME}:${MYSQL_VERSION_OTHER_ARCH}-linux-amd64${BETA_VERSION}" --os linux --arch amd64
	DOCKER_CLI_EXPERIMENTAL=enabled docker manifest push "${DOCKER_IMAGE_NAME}:latest${BETA_VERSION}"

checkout: check-binaries
	rm -rf docker || true
	git clone https://github.com/phpmyadmin/docker
	cd docker && git checkout tags/$(DOCKER_IMAGE_VERSION)

build-one-image: checkout
	cp docker/apache/Dockerfile docker/apache/Dockerfile-orig
	cp Dockerfile docker/apache/.
	cd docker/apache && \
	docker build -t ${DOCKER_REGISTRY}${DOCKER_IMAGE_TAGNAME} --build-arg VERSION="${DOCKER_IMAGE_VERSION}" --build-arg VCS_REF="${VCS_REF}" --build-arg BUILD_DATE="${BUILD_DATE}" --build-arg BUILD_ARCH="${BUILD_ARCH}" ${DOCKER_FILE} .
	rm -rf docker

test-one-image: check
	# Smoke tests:
	docker run --rm ${DOCKER_IMAGE_TAGNAME} /bin/echo "Success."
	docker run --rm ${DOCKER_IMAGE_TAGNAME} uname -a

tag-one-image: check
	docker tag $(DOCKER_IMAGE_TAGNAME) $(DOCKER_REGISTRY)$(DOCKER_IMAGE_TAGNAME)

push-one-image: docker-login-if-possible
	# push only is 'DOCKER_USERNAME' (and hopefully DOCKER_PASSWORD) are set:
	if [[ ! "${DOCKER_USERNAME}" == "" ]]; then docker push "${DOCKER_IMAGE_TAGNAME}"; fi

# Helper targets
rmi-one-image: check
	docker rmi -f $(DOCKER_IMAGE_TAGNAME)

rebuild-one-image: rmi-one-image build-one-image