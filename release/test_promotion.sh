#!/bin/bash

source ../_test_common.sh
source _bom.sh
source _liferay_common.sh

function main {
	set_up

	if [ "${?}" -eq "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	generate_distro_jar &> /dev/null

	test_generate_distro_jar

	tear_down
}

function set_up {
	export _RELEASE_ROOT_DIR="${PWD}"

	export _PROJECTS_DIR="${_RELEASE_ROOT_DIR}"/../..

	if [ ! -d "${_PROJECTS_DIR}/liferay-portal-ee" ]
	then
		echo -e "The directory ${_PROJECTS_DIR}/liferay-portal-ee does not exist. Run this test locally.\n"

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	export LIFERAY_RELEASE_PRODUCT_NAME="dxp"
	export LIFERAY_RELEASE_VERSION="2024.q2.0"

	export _BUILD_DIR="${_RELEASE_ROOT_DIR}/release-data/build"

	export _BUNDLES_DIR="${_RELEASE_ROOT_DIR}/release-data/dev/projects/bundles"

	export _PRODUCT_VERSION="${LIFERAY_RELEASE_VERSION}"

	lc_cd "${_RELEASE_ROOT_DIR}"

	mkdir -p release-data

	lc_cd release-data

	mkdir -p "${_RELEASE_ROOT_DIR}/release-data/build/boms"
}

function tear_down {
	rm -fr "${_RELEASE_ROOT_DIR}/release-data/build/boms"

	unset LIFERAY_RELEASE_PRODUCT_NAME
	unset LIFERAY_RELEASE_VERSION
	unset _BUILD_DIR
	unset _BUNDLES_DIR
	unset _PRODUCT_VERSION
	unset _PROJECTS_DIR
	unset _RELEASE_ROOT_DIR
}

function test_generate_distro_jar {
	assert_equals "$(find "${_RELEASE_ROOT_DIR}" -name "release.dxp.distro-${LIFERAY_RELEASE_VERSION}*.jar" | grep -c /)" 1
}

main