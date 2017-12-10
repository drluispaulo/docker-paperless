#!/bin/bash
set -e

# Source: https://github.com/sameersbn/docker-gitlab/
map_uidgid() {
    USERMAP_ORIG_UID=$(id -u paperless)
    USERMAP_ORIG_UID=$(id -g paperless)
    USERMAP_GID=${USERMAP_GID:-${USERMAP_UID:-$USERMAP_ORIG_GID}}
    USERMAP_UID=${USERMAP_UID:-$USERMAP_ORIG_UID}
    if [[ ${USERMAP_UID} != "${USERMAP_ORIG_UID}" || ${USERMAP_GID} != "${USERMAP_ORIG_GID}" ]]; then
        echo "Mapping UID and GID for paperless:paperless to $USERMAP_UID:$USERMAP_GID"
        deluser paperless
        addgroup -g "${USERMAP_GID}" paperless
        adduser -D -u "${USERMAP_UID}" -G paperless -h /usr/src/paperless paperless
    fi
}

set_permissions() {
    # Set permissions for consumption and export directory
    for dir in PAPERLESS_CONSUMPTION_DIR PAPERLESS_EXPORT_DIR; do
      # Extract the name of the current directory from $dir for the error message
      cur_dir_name=$(echo "$dir" | awk -F'_' '{ print tolower($2); }')
      chgrp paperless "${!dir}" || {
          echo "Changing group of ${cur_dir_name} directory:"
          echo "  ${!dir}"
          echo "failed."
          echo ""
          echo "Either try to set it on your host-mounted directory"
          echo "directly, or make sure that the directory has \`o+x\`"
          echo "permissions and the files in it at least \`o+r\`."
      } >&2
      chmod g+x "${!dir}" || {
          echo "Changing group permissions of ${cur_dir_name} directory:"
          echo "  ${!dir}"
          echo "failed."
          echo ""
          echo "Either try to set it on your host-mounted directory"
          echo "directly, or make sure that the directory has \`o+x\`"
          echo "permissions and the files in it at least \`o+r\`."
      } >&2
    done
    # Set permissions for application directory
    chown -Rh paperless:paperless /usr/src/paperless
}

initialize() {
    map_uidgid
    set_permissions
}

install_languages() {
    local langs="$1"
    read -ra langs <<<"$langs"

    # Check that it is not empty
    if [ ${#langs[@]} -eq 0 ]; then
        return
    fi

    # Loop over languages to be installed
    for lang in "${langs[@]}"; do
        pkg="tesseract-ocr-data-$lang"
        if apk info -e "$pkg" > /dev/null 2>&1; then
            continue
        fi

        if ! apk info "$pkg" > /dev/null 2>&1; then
            continue
        fi

        apk add --no-cache "$pkg"
    done
}


if [[ "$1" != "/"* ]]; then
    initialize

    # Install additional languages if specified
    if [ ! -z "$PAPERLESS_OCR_LANGUAGES"  ]; then
        install_languages "$PAPERLESS_OCR_LANGUAGES"
    fi

    exec sudo -HEu paperless "/usr/src/paperless/src/manage.py" "$@"
fi

exec "$@"

