PACKAGE_VERSION := $(PRODUCT_VERSION).$(BUILD_NUMBER)

ifeq ($(GIT_BRANCH), origin/develop)
DOCKER_TAGS += $(PACKAGE_VERSION)
DOCKER_TAGS += latest
else
DOCKER_TAGS += $(PACKAGE_VERSION)-$(subst /,-,$(GIT_BRANCH))
endif

DOCKER_REPO = $(COMPANY_NAME)/4testing-$(PRODUCT_NAME)

COLON := __colon__
DOCKER_TARGETS := $(foreach TAG,$(DOCKER_TAGS),$(DOCKER_REPO)$(COLON)$(TAG))

.PHONY: all clean clean-docker deploy docker

$(DOCKER_TARGETS): $(DEB_REPO_DATA)
	sed "s|{{GIT_BRANCH}}|$(GIT_BRANCH)|"  -i Dockerfile
	sed 's/{{PACKAGE_VERSION}}/'$(PACKAGE_VERSION)'/'  -i Dockerfile

	sudo docker build -t $(subst $(COLON),:,$@) . &&\
	mkdir -p $$(dirname $@) &&\
	echo "Done" > $@

all: $(DOCKER_TARGETS)

clean:
	rm -rfv $(DOCKER_TARGETS)
		
clean-docker:
	sudo docker rmi -f $$(sudo docker images -q $(COMPANY_NAME)/*) || exit 0

deploy: $(DOCKER_TARGETS)
	$(foreach TARGET,$(DOCKER_TARGETS),sudo docker push $(subst $(COLON),:,$(TARGET));)
