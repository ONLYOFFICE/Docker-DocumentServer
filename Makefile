COMPANY_NAME ?= ONLYOFFICE
GIT_BRANCH ?= develop
PRODUCT_NAME ?= DocumentServer
PRODUCT_EDITION ?= 
PRODUCT_VERSION ?= 0.0.0
BUILD_NUMBER ?= 0
ONLYOFFICE_VALUE ?= onlyoffice
S3_BUCKET ?= repo-doc-onlyoffice-com
RELEASE_BRANCH ?= unstable

COMPANY_NAME_LOW = $(shell echo $(COMPANY_NAME) | tr A-Z a-z)
PRODUCT_NAME_LOW = $(shell echo $(PRODUCT_NAME) | tr A-Z a-z)
COMPANY_NAME_LOW_ESCAPED = $(subst -,,$(COMPANY_NAME_LOW))

PACKAGE_NAME := $(COMPANY_NAME_LOW)-$(PRODUCT_NAME_LOW)$(PRODUCT_EDITION)
PACKAGE_VERSION := $(PRODUCT_VERSION)-$(BUILD_NUMBER)
PACKAGE_BASEURL := https://s3.eu-west-1.amazonaws.com/$(S3_BUCKET)/$(COMPANY_NAME_LOW)/$(RELEASE_BRANCH)/ubuntu

ifeq ($(RELEASE_BRANCH),$(filter $(RELEASE_BRANCH),unstable testing))
	DOCKER_TAG := $(subst -,.,$(PACKAGE_VERSION))
else
	DOCKER_TAG := $(subst -,.,$(PACKAGE_VERSION))-$(subst /,-,$(GIT_BRANCH))
endif

DOCKER_IMAGE := $(subst -,,$(COMPANY_NAME_LOW))/4testing-$(PRODUCT_NAME_LOW)$(PRODUCT_EDITION)
DOCKER_DUMMY := $(COMPANY_NAME_LOW)-$(PRODUCT_NAME_LOW)$(PRODUCT_EDITION)__$(DOCKER_TAG).dummy
DOCKER_ARCH := $(COMPANY_NAME_LOW)-$(PRODUCT_NAME_LOW)_$(PACKAGE_VERSION).tar.gz
DOCKER_ARCH_URI := $(COMPANY_NAME_LOW)/$(RELEASE_BRANCH)/docker/$(notdir $(DOCKER_ARCH))

.PHONY: all clean clean-docker image deploy docker publish

$(DOCKER_DUMMY):
	docker pull ubuntu:20.04
	docker build \
		--build-arg COMPANY_NAME=$(COMPANY_NAME_LOW) \
		--build-arg PRODUCT_NAME=$(PRODUCT_NAME_LOW) \
		--build-arg PRODUCT_EDITION=$(PRODUCT_EDITION) \
		--build-arg PACKAGE_VERSION=$(PACKAGE_VERSION) \
		--build-arg PACKAGE_BASEURL=$(PACKAGE_BASEURL) \
		--build-arg TARGETARCH=amd64 \
		--build-arg ONLYOFFICE_VALUE=$(ONLYOFFICE_VALUE) \
		-t $(DOCKER_IMAGE):$(DOCKER_TAG) . && \
	mkdir -p $$(dirname $@) && \
	echo "Done" > $@

$(DOCKER_ARCH): $(DOCKER_DUMMY)
	docker save $(DOCKER_IMAGE):$(DOCKER_TAG) | \
		gzip > $@

all: image

clean:
	rm -rfv *.dummy *.tar.gz
		
clean-docker:
	docker rmi -f $$(docker images -q $(COMPANY_NAME_LOW)/*) || exit 0

image: $(DOCKER_DUMMY)

deploy: $(DOCKER_DUMMY)
	for i in {1..3}; do \
		docker push $(DOCKER_IMAGE):$(DOCKER_TAG) && break || sleep 1m; \
	done
ifeq ($(RELEASE_BRANCH),unstable)
	docker tag $(DOCKER_IMAGE):$(DOCKER_TAG) $(DOCKER_IMAGE):latest
	for i in {1..3}; do \
		docker push $(DOCKER_IMAGE):latest && break || sleep 1m; \
	done
endif

publish: $(DOCKER_ARCH)
	aws s3 cp --no-progress --acl public-read \
		$(DOCKER_ARCH) s3://$(S3_BUCKET)/$(DOCKER_ARCH_URI)
