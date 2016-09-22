PACKAGE_VERSION := $(PRODUCT_VERSION)-$(BUILD_NUMBER)

REPO_URL := "deb http://repo-doc-onlyoffice-com.s3.amazonaws.com/ubuntu/trusty/$(COMPANY_NAME)-$(PRODUCT_NAME)/$(GIT_BRANCH)/$(PACKAGE_VERSION)/ repo/"

UPDATE_LATEST := false

ifneq (,$(findstring develop,$(GIT_BRANCH)))
UPDATE_LATEST := true
endif

ifneq (,$(findstring release,$(GIT_BRANCH)))
UPDATE_LATEST := true
endif

ifneq (,$(findstring hotfix,$(GIT_BRANCH)))
UPDATE_LATEST := true
endif

ifeq ($(UPDATE_LATEST), true)
DOCKER_TAGS += $(subst -,.,$(PACKAGE_VERSION))
DOCKER_TAGS += latest
else
DOCKER_TAGS += $(subst -,.,$(PACKAGE_VERSION))-$(subst /,-,$(GIT_BRANCH))
endif

DOCKER_REPO = $(COMPANY_NAME)/4testing-$(PRODUCT_NAME)

COLON := __colon__
DOCKER_TARGETS := $(foreach TAG,$(DOCKER_TAGS),$(DOCKER_REPO)$(COLON)$(TAG))

.PHONY: all clean clean-docker deploy docker

$(DOCKER_TARGETS): $(DEB_REPO_DATA)

	sudo docker build --build-arg REPO_URL=$(REPO_URL) --build-arg PRODUCT_NAME=$(COMPANY_NAME)-$(PRODUCT_NAME) -t $(subst $(COLON),:,$@) . &&\
	mkdir -p $$(dirname $@) &&\
	echo "Done" > $@

all: $(DOCKER_TARGETS)

clean:
	rm -rfv $(DOCKER_TARGETS)
		
clean-docker:
	sudo docker rmi -f $$(sudo docker images -q $(COMPANY_NAME)/*) || exit 0

deploy: $(DOCKER_TARGETS)
	$(foreach TARGET,$(DOCKER_TARGETS),sudo docker push $(subst $(COLON),:,$(TARGET));)
