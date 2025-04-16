#!/bin/bash

source ../_test_common.sh

function main {
	setup

	test_scan_with_invalid_image

	teardown

	test_scan_without_parameters
}

function setup {
	export LIFERAY_IMAGE_NAMES="liferay/dxp:no-image"
	export LIFERAY_PRISMA_ACCESS_KEY="key"
	export LIFERAY_PRISMA_SECRET="secret"
}

function teardown {
	unset LIFERAY_IMAGE_NAMES
	unset LIFERAY_PRISMA_ACCESS_KEY
	unset LIFERAY_PRISMA_SECRET
}

function test_scan_with_invalid_image {
	assert_equals \
		"$(./scan_docker_images.sh | cut -d ' ' -f 2-)" \
		"[ERROR] Unable to find liferay/dxp:no-image locally."
}

function test_scan_without_parameters {
	assert_equals \
		"$(./scan_docker_images.sh)" \
		"$(cat test-dependencies/expected/scan_docker_without_parameters_output.txt)"
}

main