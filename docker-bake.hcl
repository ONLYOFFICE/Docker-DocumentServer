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

target "documentserver" {
    dockerfile = PRODUCT_EDITION == "" ? "Dockerfile" : "Dockerfile.enterprise"
    tags = [
           "docker.io/${COMPANY_NAME}/${PREFIX_NAME}${PRODUCT_NAME}${PRODUCT_EDITION}:${TAG}"
           ]
    platforms = ["${PLATFORM}"]
    # The package base URL is a secret read from the PACKAGE_BASEURL environment variable, so it is not recorded in the provenance.
    secret = ["id=package_baseurl,env=PACKAGE_BASEURL"]
    args = {
        "COMPANY_NAME": "${COMPANY_NAME}"
        "PRODUCT_NAME": "${PRODUCT_NAME}"
        "PRODUCT_EDITION": "${PRODUCT_EDITION}"
        "PACKAGE_VERSION": "${PACKAGE_VERSION}"
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
