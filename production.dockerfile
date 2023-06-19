### Arguments avavlivable only for FROM instruction ### 
ARG PULL_TAG=latest
ARG COMPANY_NAME=onlyoffice
ARG PRODUCT_EDITION=
### Rebuild arguments
ARG UCS_PREFIX=
ARG IMAGE=${COMPANY_NAME}/documentserver${PRODUCT_EDITION}${UCS_PREFIX}:${PULL_TAG}

### Build main-release ###

FROM ${COMPANY_NAME}/4testing-documentserver${PRODUCT_EDITION}:${PULL_TAG} as documentserver-stable

### Rebuild stable images with secure updates 
FROM ${IMAGE} as documentserver-stable-rebuild
RUN    echo "This is rebuild" \
    && apt-get update -y \
    && apt-get upgrade -y

### Build nonexample ###
 
FROM ${COMPANY_NAME}/documentserver${PRODUCT_EDITION}:${PULL_TAG} as documentserver-nonexample

ARG COMPANY_NAME=onlyoffice
ARG PRODUCT_NAME=documentserver
ARG DS_SUPERVISOR_CONF=/etc/supervisor/conf.d/ds.conf

### Remove all documentserver-example data ###

RUN    rm -rf /var/www/$COMPANY_NAME/$PRODUCT_NAME-example \
    && rm -rf /etc/$COMPANY_NAME/$PRODUCT_NAME-example \
    && rm -f $DS_SUPERVISOR_CONF \ 
    && rm -f /etc/nginx/includes/ds-example.conf \
    && ln -s /etc/$COMPANY_NAME/$PRODUCT_NAME/supervisor/ds.conf  $DS_SUPERVISOR_CONF 
