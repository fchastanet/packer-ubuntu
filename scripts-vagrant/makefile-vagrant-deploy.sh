#!/usr/bin/env bash
set -o errexit

USER="$1"
BOX="$2"
BOX_VERSION="$3"
BOX_VERSION_DESCRIPTION_FILE="$4"
BOX_VERSION_DESKTOP_DESCRIPTION_FILE="$5"
CLOUD_TOKEN="$6"
BOX_DIR="$7"
BOX_FILE="$8"
BOX_PACKED="$9"
BASE_URL="https://app.vagrantup.com/api/v1"
PROVIDER_NAME="virtualbox"
SECONDS=0

echo "Creating the box for ${USER}/${PROVIDER_NAME}/${BOX} ..."
curl -sS \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer ${CLOUD_TOKEN}" \
    ${BASE_URL}/boxes \
    --data '{ "box": { "username": "'${USER}'", "name": "'${BOX}'", "is_private": false } }'

echo
echo "Creating the version ${BOX_VERSION}..."
tmpfile="$(mktemp /tmp/abc-script.XXXXXX)"

# escape \n from md files
function escapeDescriptionFile() {
    echo "$(echo "${1}" | sed ':a;N;$!ba;s/\n/\\n/g')"
}
imageDesc=$(imageDesktopDesc="$(cat "${BOX_VERSION_DESKTOP_DESCRIPTION_FILE}")" envsubst < "${BOX_VERSION_DESCRIPTION_FILE}")
imageDesc="$(escapeDescriptionFile "${imageDesc}")"
printf '{ "version": { "version": "%s", "description": "%s" } }' "${BOX_VERSION}" "${imageDesc}" > "${tmpfile}"

curl -sS \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer ${CLOUD_TOKEN}" \
    ${BASE_URL}/box/${USER}/${BOX}/versions \
    --data-binary "$(cat ${tmpfile})"

echo
echo "Creating the provider ${PROVIDER_NAME} ..."
curl -sS \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer ${CLOUD_TOKEN}" \
    "${BASE_URL}/box/${USER}/${BOX}/version/${BOX_VERSION}/providers" \
    --data "$(printf '{ "provider": { "name": "%s" } }' "${PROVIDER_NAME}")"

# check if a release has already been uploaded
function releaseUploaded() {
    echo
    echo "Check if uploaded file really exists"
    boxUrl="https://app.vagrantup.com/${USER}/boxes/${BOX}/versions/${BOX_VERSION}/providers/${PROVIDER_NAME}.box"
    if curl --header "Authorization: Bearer ${CLOUD_TOKEN}" --output /dev/null --silent --head --fail "${boxUrl}"; then
        echo "*** File '${boxUrl}' is reachable and exists..."
        return 0
    else
        echo "*** File '${boxUrl}' does not exists !!!"
        return 1
    fi
}

if releaseUploaded; then
    echo
    echo "Release already uploaded, no need to upload again"
else
    echo
    echo "Receiving the upload url..."
    response=$(curl -s \
        --header "Authorization: Bearer ${CLOUD_TOKEN}" \
        "${BASE_URL}/box/${USER}/${BOX}/version/${BOX_VERSION}/provider/${PROVIDER_NAME}/upload")

    # Extract the upload URL from the response (requires the jq command)
    uploadPath=$(echo "${response}" | grep -w \"upload_path\" | tail -1 | cut -d\" -f4)

    echo "Perform the upload..."
    time curl "${uploadPath}" -o logs/upload.log --progress-bar --request PUT --upload-file "${BOX_DIR}/${BOX_FILE}"
fi

echo
echo "Release the version"
curl -sS \
  --header "Authorization: Bearer ${CLOUD_TOKEN}" \
  "${BASE_URL}/box/${USER}/${BOX}/version/${BOX_VERSION}/release" \
  --request PUT

# check existence of the release and box file existence
if releaseUploaded; then
    echo "${BOX}:${BOX_VERSION} uploaded on $(date)" "${BOX_DIR}/deployed"
    duration=$(eval "echo $(date -ud "@$SECONDS" +'$((%s/3600/24)) days %H hours %M minutes %S seconds')")
    echo "Box ${BOX_PACKED} deployed at $(date)" >> logs/box-$(BOX_PACKED)-created
    echo "Box ${BOX_PACKED} deployment has taken ${duration}" >> logs/box-${BOX_PACKED}-created
else
    exit 1
fi
