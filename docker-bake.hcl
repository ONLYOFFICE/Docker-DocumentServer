variable "TAG" {
    default = ""
}

variable "SHORTER_TAG" {
    default = ""
}

variable "SHORTEST_TAG" {
    default = ""
}

variable "PULL_TAG" {
    default = ""
}

variable "COMPANY_NAME" {
    default = ""
}

variable "PREFIX_NAME" {
    default = ""
}

variable "PRODUCT_EDITION" {
    default = ""
}

variable "PRODUCT_NAME" {
    default = ""
}

variable "PACKAGE_VERSION" {
    default = ""
}

variable "PLATFORM" {
    default = ""
}

variable "PACKAGE_BASEURL" {
    default = ""
}

variable "PACKAGE_FILE" {
    default = ""
}

variable "BUILD_CHANNEL" {
    default = ""
}

variable "PUSH_MAJOR" {
    default = "false"
}

variable "LATEST" {
    default = "false"
}

target "documentserver" {
    dockerfile = PRODUCT_EDITION == "" ? "Dockerfile" : "Dockerfile.enterprise"
    tags = [
           "docker.io/${COMPANY_NAME}/${PREFIX_NAME}${PRODUCT_NAME}${PRODUCT_EDITION}:${TAG}"
           ]
    platforms = ["${PLATFORM}"]
    args = {
        "COMPANY_NAME": "${COMPANY_NAME}"
        "PRODUCT_NAME": "${PRODUCT_NAME}"
        "PRODUCT_EDITION": "${PRODUCT_EDITION}"
        "PACKAGE_VERSION": "${PACKAGE_VERSION}"
        "PACKAGE_BASEURL": "${PACKAGE_BASEURL}"
        "PLATFORM": "${PLATFORM}"
    }
}

target "documentserver-nonexample" {
    target = "documentserver-nonexample"
    dockerfile = "production.dockerfile"
    tags = [ "docker.io/${COMPANY_NAME}/${PRODUCT_NAME}${PREFIX_NAME}${PRODUCT_EDITION}:${TAG}-nonexample" ]
    platforms = ["linux/amd64", "linux/arm64"]
    args = {
        "PULL_TAG": "${PULL_TAG}"
        "COMPANY_NAME": "${COMPANY_NAME}"
        "PRODUCT_NAME": "${PRODUCT_NAME}"
        "PRODUCT_EDITION": "${PRODUCT_EDITION}"
    } 
}

target "documentserver-stable-rebuild" {
    target = "documentserver-stable-rebuild"
    dockerfile = "production.dockerfile"
    tags = [
        "docker.io/${COMPANY_NAME}/${PREFIX_NAME}${PRODUCT_NAME}${PRODUCT_EDITION}:${TAG}",
        equal("",PREFIX_NAME) ? "docker.io/${COMPANY_NAME}/${PREFIX_NAME}${PRODUCT_NAME}${PRODUCT_EDITION}:${SHORTER_TAG}": "",
        equal("true",PUSH_MAJOR) ? "docker.io/${COMPANY_NAME}/${PREFIX_NAME}${PRODUCT_NAME}${PRODUCT_EDITION}:${SHORTEST_TAG}": "",
        equal("",PREFIX_NAME) && equal("true",LATEST) ? "docker.io/${COMPANY_NAME}/${PREFIX_NAME}${PRODUCT_NAME}${PRODUCT_EDITION}:latest": "",
        equal("-ee",PRODUCT_EDITION) && equal("",PREFIX_NAME) ? "docker.io/${COMPANY_NAME}4enterprise/${PREFIX_NAME}${PRODUCT_NAME}${PRODUCT_EDITION}:${TAG}": "",
    ]
    platforms = ["linux/amd64", "linux/arm64"]
    args = {
        "PULL_TAG": "${PULL_TAG}"
        "COMPANY_NAME": "${COMPANY_NAME}"
        "PRODUCT_NAME": "${PRODUCT_NAME}"
        "PRODUCT_EDITION": "${PRODUCT_EDITION}"
    }
}
