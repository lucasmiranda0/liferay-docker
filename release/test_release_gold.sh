#!/bin/bash

source ../_test_common.sh
source _github.sh

function main {
	set_up

	test_invoke_github_api_post

	tear_down
}

function set_up {
	export LIFERAY_COMMON_EXIT_CODE_OK=0
	export LIFERAY_COMMON_EXIT_CODE_SKIPPED=4
	export LIFERAY_RELEASE_REPOSITORY_OWNER="lucasmiranda0"
	export LIFERAY_RELEASE_VERSION="test-tag"
}

function tear_down {
	invoke_github_api_delete "liferay-portal-ee/git/refs/tags/${LIFERAY_RELEASE_VERSION}"

	unset LIFERAY_COMMON_EXIT_CODE_OK
	unset LIFERAY_COMMON_EXIT_CODE_SKIPPED
	unset LIFERAY_RELEASE_REPOSITORY_OWNER
	unset LIFERAY_RELEASE_VERSION
}

function test_invoke_github_api_post {
	local ref_data=$(
		cat <<- END
		{
			"message": "",
			"ref": "refs/tags/${LIFERAY_RELEASE_VERSION}",
			"sha": "77ae292bf9d7fe847a8b5b237ca52f064cc67a8c"
		}
		END
	)

	local tag_data=$(
		cat <<- END
		{
			"message": "",
			"object": "77ae292bf9d7fe847a8b5b237ca52f064cc67a8c",
			"tag": "${LIFERAY_RELEASE_VERSION}",
			"type": "commit"
		}
		END
	)

	assert_equals \
		"$(invoke_github_api_post "liferay-portal-ee/git/tags" "${tag_data}")" \
		"${LIFERAY_COMMON_EXIT_CODE_OK}" \
		"$(invoke_github_api_post "liferay-portal-ee/git/refs" "${ref_data}")" \
		"${LIFERAY_COMMON_EXIT_CODE_OK}"
}

main