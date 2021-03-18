COMPANY_NAME ?= ONLYOFFICE
GIT_BRANCH ?= develop
PRODUCT_NAME ?= DocumentServer
PRODUCT_VERSION ?= 0.0.0
BUILD_NUMBER ?= 0
ONLYOFFICE_VALUE ?= onlyoffice
S3_BUCKET ?= repo-doc-onlyoffice-com
RELEASE_BRANCH ?= unstable

COMPANY_NAME_LOW = $(shell echo $(COMPANY_NAME) | tr A-Z a-z)
PRODUCT_NAME_LOW = $(shell echo $(PRODUCT_NAME) | tr A-Z a-z)
COMPANY_NAME_LOW_ESCAPED = $(subst -,,$(COMPANY_NAME_LOW))

PACKAGE_NAME := $(COMPANY_NAME_LOW)-$(PRODUCT_NAME_LOW)
PACKAGE_VERSION := $(PRODUCT_VERSION)-$(BUILD_NUMBER)
PACKAGE_URL := http://$(S3_BUCKET).s3.amazonaws.com/$(COMPANY_NAME_LOW)/$(RELEASE_BRANCH)/ubuntu/$(PACKAGE_NAME)_$(PACKAGE_VERSION)_amd64.deb

UPDATE_LATEST := false

ifneq (,$(findstring develop,$(GIT_BRANCH)))
DOCKER_TAG += $(subst -,.,$(PACKAGE_VERSION))
DOCKER_TAGS += latest
else ifneq (,$(findstring release,$(GIT_BRANCH)))
DOCKER_TAG += $(subst -,.,$(PACKAGE_VERSION))
else ifneq (,$(findstring hotfix,$(GIT_BRANCH)))
DOCKER_TAG += $(subst -,.,$(PACKAGE_VERSION))
else
DOCKER_TAG += $(subst -,.,$(PACKAGE_VERSION))-$(subst /,-,$(GIT_BRANCH))
endif

DOCKER_TAGS += $(DOCKER_TAG)

DOCKER_REPO = $(COMPANY_NAME_LOW_ESCAPED)/4testing-$(PRODUCT_NAME_LOW)

COLON := __colon__
DOCKER_TARGETS := $(foreach TAG,$(DOCKER_TAGS),$(DOCKER_REPO)$(COLON)$(TAG))

DOCKER_ARCH := $(COMPANY_NAME_LOW)-$(PRODUCT_NAME_LOW)_$(PACKAGE_VERSION).tar.gz

DOCKER_ARCH_URI := $(COMPANY_NAME_LOW)/$(RELEASE_BRANCH)/docker/$(notdir $(DOCKER_ARCH))

.PHONY: all clean clean-docker deploy docker publish

$(DOCKER_TARGETS): $(DEB_REPO_DATA)
	docker pull ubuntu:20.04
	docker build \
		--build-arg PACKAGE_URL=$(PACKAGE_URL) \
		--build-arg COMPANY_NAME=$(COMPANY_NAME_LOW) \
		--build-arg PRODUCT_NAME=$(PRODUCT_NAME_LOW) \
		--build-arg ONLYOFFICE_VALUE=$(ONLYOFFICE_VALUE) \
		-t $(subst $(COLON),:,$@) . &&\
	mkdir -p $$(dirname $@) &&\
	echo "Done" > $@

$(DOCKER_ARCH): $(DOCKER_TARGETS)
	docker save $(DOCKER_REPO):$(DOCKER_TAG) | \
		gzip > $@

all: $(DOCKER_TARGETS)

clean:
	rm -rfv $(DOCKER_TARGETS) $(DOCKER_ARCH)
		
clean-docker:
	docker rmi -f $$(docker images -q $(COMPANY_NAME_LOW)/*) || exit 0

deploy: $(DOCKER_TARGETS)
	$(foreach TARGET,$(DOCKER_TARGETS), \
		for i in {1..3}; do \
			docker push $(subst $(COLON),:,$(TARGET)) && break || sleep 1m; \
		done;)

publish: $(DOCKER_ARCH)
	aws s3 cp --no-progress --acl public-read \
		$(DOCKER_ARCH) s3://$(S3_BUCKET)/$(DOCKER_ARCH_URI)
