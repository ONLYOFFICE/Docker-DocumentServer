variable "TAG" {
    default = ""
}

variable "SHORTER_TAG" {
    default = ""
}

variable "SHORTEST_TAG" {
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

variable "DOCKERFILE" {
    default = ""
}

variable "PLATFORM" {
    default = ""
}

variable "PACKAGE_URL" {
    default = ""
}

variable "DEVELOP_BUILD" {
    default = ""
}

target "documentserver" {
    target = "documentserver"
    dockerfile= "${DOCKERFILE}"
    tags = [
           "docker.io/${COMPANY_NAME}/${PREFIX_NAME}${PRODUCT_NAME}${PRODUCT_EDITION}:${TAG}",
           notequal("",DEVELOP_BUILD) ? "docker.io/${COMPANY_NAME}/${PREFIX_NAME}${PRODUCT_NAME}${PRODUCT_EDITION}:latest": "",
           ]
    platforms = ["${PLATFORM}"]
    args = {
        "PRODUCT_EDITION": "${PRODUCT_EDITION}"
        "PRODUCT_NAME": "${PRODUCT_NAME}"
        "COMPANY_NAME": "${COMPANY_NAME}"
        "PACKAGE_URL": "${PACKAGE_URL}"
        "PLATFORM": "${PLATFORM}"
    }
}

target "documentserver-stable" {
    target = "documentserver-stable"
    dockerfile= "Dockerfile.production"
    tags = ["docker.io/${COMPANY_NAME}/${PREFIX_NAME}${PRODUCT_NAME}${PRODUCT_EDITION}:${TAG}",
            "docker.io/${COMPANY_NAME}/${PREFIX_NAME}${PRODUCT_NAME}${PRODUCT_EDITION}:${SHORTER_TAG}",
            "docker.io/${COMPANY_NAME}/${PREFIX_NAME}${PRODUCT_NAME}${PRODUCT_EDITION}:${SHORTEST_TAG}",
            "docker.io/${COMPANY_NAME}/${PREFIX_NAME}${PRODUCT_NAME}${PRODUCT_EDITION}:latest"]
    platforms = ["linux/amd64", "linux/arm64"]
    args = {
        "TAG": "${TAG}"
        "COMPANY_NAME": "${COMPANY_NAME}"
        "PRODUCT_NAME": "${PRODUCT_NAME}"
        "PRODUCT_EDITION": "${PRODUCT_EDITION}"
    }
}

target "documentserver-nonexample" {
    target = "documentserver-nonexample"
    dockerfile = "Dockerfile.production"
    tags = [ "docker.io/${COMPANY_NAME}/${PRODUCT_NAME}${PREFIX_NAME}${PRODUCT_EDITION}:${TAG}-nonexample" ]
    platforms = ["linux/amd64", "linux/arm64"]
    args = {
        "TAG": "${TAG}"
        "COMPANY_NAME": "${COMPANY_NAME}"
        "PRODUCT_NAME": "${PRODUCT_NAME}"
        "PRODUCT_EDITION": "${PRODUCT_EDITION}"
    } 
}
