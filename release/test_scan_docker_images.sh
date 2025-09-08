#!/bin/bash

source ../_test_common.sh
source ./scan_docker_images.sh

function main {
	set_up

	if [ "${#}" -eq 1 ]
	then
		if [ "${1}" == "test_scan_docker_images_with_invalid_image" ]
		then
			"${1}"

			tear_down
		else
			tear_down

			"${1}"
		fi
	else
		test_scan_docker_images_with_invalid_image

		test_scan_docker_images_with_comma_separated_arguments
		test_scan_docker_images_with_spaced_arguments

		tear_down

		test_scan_docker_images_without_parameters
	fi
}

function set_up {
	export LIFERAY_IMAGE_NAMES="liferay/dxp:test-image"
	export LIFERAY_PRISMA_CLOUD_ACCESS_KEY="key"
	export LIFERAY_PRISMA_CLOUD_SECRET="secret"

	docker pull liferay/dxp:2024.q2.2 &> /dev/null
	docker pull liferay/dxp:2025.q1.5-lts &> /dev/null
}

function tear_down {
	unset LIFERAY_IMAGE_NAMES
	unset LIFERAY_PRISMA_CLOUD_ACCESS_KEY
	unset LIFERAY_PRISMA_CLOUD_SECRET

	docker rmi liferay/dxp:2024.q2.2 &> /dev/null
	docker rmi liferay/dxp:2025.q1.5-lts &> /dev/null
}

function test_scan_docker_images_with_invalid_image {
	assert_equals \
		"$(./scan_docker_images.sh | cut --delimiter=' ' --fields=2-)" \
		"[ERROR] Unable to find liferay/dxp:test-image locally."
}

function test_scan_docker_images_with_comma_separated_arguments {
	LIFERAY_IMAGE_NAMES="liferay/dxp:2025.q1.5-lts,liferay/dxp:2024.q2.2"

	check_usage_scan_docker_images "${LIFERAY_IMAGE_NAMES}"

	assert_equals \
		"$(echo ${LIFERAY_IMAGE_NAMES})" \
		"liferay/dxp:2025.q1.5-lts,liferay/dxp:2024.q2.2"
}

function test_scan_docker_images_with_spaced_arguments {
	LIFERAY_IMAGE_NAMES="liferay/dxp:2025.q1.5-lts liferay/dxp:2024.q2.2"

	check_usage_scan_docker_images "${LIFERAY_IMAGE_NAMES}"

	assert_equals \
		"$(echo ${LIFERAY_IMAGE_NAMES})" \
		"liferay/dxp:2025.q1.5-lts,liferay/dxp:2024.q2.2"
}

function test_scan_docker_images_without_parameters {
	assert_equals \
		"$(./scan_docker_images.sh)" \
		"$(cat test-dependencies/expected/test_scan_docker_images_without_parameters_output.txt)"
}

main "${@}"