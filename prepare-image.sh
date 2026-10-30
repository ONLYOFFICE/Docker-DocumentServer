#!/bin/bash
# Image build step: pre-generate fonts, themes and js cache and enable static gzip, so the first start has nothing to generate.

# shellcheck source=run-document-server.sh
source "$(dirname "${BASH_SOURCE[0]}")/run-document-server.sh"

init_config
generate_fonts
[ -s "${FONTS_FINGERPRINT_FILE}" ] || { echo "ERROR: fonts were not generated"; exit 1; }

sed -i 's/#*\s*\(gzip_static\).*/\1 on;/g' "${NGINX_ONLYOFFICE_PATH}/includes/ds-docservice.conf"
