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

variable "DOCKERFILE" {
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

### ↓ Variables for UCS build ↓

variable "BASE_VERSION" {
    default     = ""
}

variable "PACKAGE_SUFFIX" {
    default     = ""
}

variable "PG_VERSION" {
    default     = ""
}

variable "UCS_REBUILD" {
    default = ""
}

variable "UCS_PREFIX" {
    default = ""
}

### ↑ Variables for UCS build ↑

target "documentserver" {
    target = "documentserver"
    dockerfile = "${DOCKERFILE}"
    tags = [
           "docker.io/danilaworker/${PREFIX_NAME}${PRODUCT_NAME}${PRODUCT_EDITION}:${TAG}",
           equal("nightly",BUILD_CHANNEL) ? "docker.io/danilaworker/${PREFIX_NAME}${PRODUCT_NAME}${PRODUCT_EDITION}:latest": "",
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

