#!/bin/bash

source release_gold.sh --source-only

function delete_tag {
    local curl_response=$(\
        curl "https://api.github.com/repos/${LIFERAY_RELEASE_USER_REPOSITORY}/${LIFERAY_RELEASE_REPOSITORY_NAME}/git/refs/tags/${LIFERAY_RELEASE_VERSION}" \
            --header "Accept: application/vnd.github+json" \
            --header "Authorization: Bearer ${LIFERAY_RELEASE_GITHUB_PAT}" \
            --include \
            --request DELETE \
            --silent)

    if [ $(echo "${curl_response}" | awk '/^HTTP/{print $2}') -ne 204 ]
    then
        echo "Failed to delete tag ${LIFERAY_RELEASE_VERSION}."

        exit
    fi

    echo "Deleted tag ${LIFERAY_RELEASE_VERSION}."
}

function main {
    set_up

    # test_tag_dxp_release

    tear_down
}

function run_test {
    ${1}

    if [ $? -gt 0 ]
    then
        echo "Test failed."

        exit
    fi

    echo "Test passed."
}

function set_up {
    export _PRODUCT_VERSION="2024.q1.8"
    # export _PROJECTS_DIR="$HOME/dev/projects"
    export LIFERAY_COMMON_EXIT_CODE_SKIPPED=4
    # export LIFERAY_RELEASE_GITHUB_PAT=""
    export LIFERAY_RELEASE_PRODUCT_NAME="dxp"
    export LIFERAY_RELEASE_REPOSITORY_NAME="liferay-portal-ee"
    export LIFERAY_RELEASE_USER_REPOSITORY="lucasmiranda0"
    export LIFERAY_RELEASE_VERSION="test_tag"
}

function tear_down {
    delete_tag

    unset _PRODUCT_VERSION
    unset _PROJECTS_DIR
    unset LIFERAY_COMMON_EXIT_CODE_SKIPPED
    unset LIFERAY_RELEASE_GITHUB_PAT
    unset LIFERAY_RELEASE_PRODUCT_NAME
    unset LIFERAY_RELEASE_REPOSITORY_NAME
    unset LIFERAY_RELEASE_USER_REPOSITORY
    unset LIFERAY_RELEASE_VERSION
}

function test_tag_dxp_release {
    run_test tag_release
}

main