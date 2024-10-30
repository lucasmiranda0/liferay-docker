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
	export LIFERAY_RELEASE_REPOSITORY_OWNER="liferay-release"
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
			"sha": "bc425dc709b850edaeaa392147145955720664a6"
		}
		END
	)

	local tag_data=$(
		cat <<- END
		{
			"message": "",
			"object": "bc425dc709b850edaeaa392147145955720664a6",
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