SHELL = bash

#BUILD_ARCH=''
#DOCKER_REGISTRY=''
DOCKER_IMAGE_VERSION=5.0.2
DOCKER_IMAGE_NAME=biarms/phpmyadmin
DOCKER_IMAGE_TAGNAME=$(DOCKER_REGISTRY)/$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_VERSION)-$(BUILD_ARCH)
DOCKER_FILE=Dockerfile

default: build test tag push

check:
	@if [[ "${BUILD_ARCH}" == "" ]]; then \
		echo 'BUILD_ARCH is unset (MUST BE SET !)' && \
		echo 'Sample usage: BUILD_ARCH=amd64 DOCKER_REGISTRY=docker.io make' && \
        exit 1; \
	fi
	@if [[ "${DOCKER_REGISTRY}" == "" ]]; then \
		echo 'DOCKER_REGISTRY is unset (MUST BE SET !)' && \
		echo 'Sample usage: BUILD_ARCH=amd64 DOCKER_REGISTRY=docker.io make' && \
        exit 1; \
	fi
	@which manifest-tool > /dev/null || (echo "Ensure that you've got the manifest-tool utility in your path. Could be downloaded from  https://github.com/estesp/manifest-tool/releases/download/" && exit 2)
	@echo "DOCKER_REGISTRY: $(DOCKER_REGISTRY)"

build: check
	rm -rf docker || true
	git clone https://github.com/phpmyadmin/docker
	cd docker && git checkout tags/$(DOCKER_IMAGE_VERSION)
	cd docker/apache && \
	docker build -t $(DOCKER_IMAGE_NAME):latest -f $(DOCKER_FILE) .

test: check
	docker run --rm $(DOCKER_IMAGE_NAME) /bin/echo "Success."
	docker run --rm $(DOCKER_IMAGE_NAME) uname -a

tag: check
	docker tag $(DOCKER_IMAGE_NAME):latest $(DOCKER_IMAGE_TAGNAME)

push-images: check
	docker push $(DOCKER_IMAGE_TAGNAME)
	# docker push $(DOCKER_REGISTRY)/$(DOCKER_IMAGE_NAME):latest

push: push-images

rmi: check
	docker rmi -f $(DOCKER_IMAGE_TAGNAME)

rebuild: rmi build
