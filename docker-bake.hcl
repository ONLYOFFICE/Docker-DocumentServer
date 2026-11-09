variable "TAG" {
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
