#!/bin/bash

source ../_liferay_common.sh

# Function to scan images using twistcli
function scan_docker_images {
	local image_names=("$@") # Capture all arguments as an array
	local CONSOLE="https://europe-west3.cloud.twistlock.com/eu-1614931"
	local API_URL="https://api.eu.prismacloud.io"

	# Retrieve credentials from environment variables (assuming Jenkins sets them)
	PRISMA_ACCESS_KEY=""
	PRISMA_SECRET=""

	# Authenticate and retrieve token
	auth_response=$(curl -s -X POST \
		-H "Content-Type: application/json" \
		-d "{\"username\":\"$PRISMA_ACCESS_KEY\",\"password\":\"$PRISMA_SECRET\"}" \
		"${API_URL}/login")

	TOKEN=$(echo "$auth_response" | jq -r '.token')

	# Download twistcli
	curl -s -H "x-redlock-auth: $TOKEN" -o twistcli "${CONSOLE}/api/v1/util/twistcli"
	chmod +x ./twistcli

	# Scan each image
	for image_name in "${image_names[@]}"; do
		local sanitized_image_name=$(echo "$image_name" | sed 's/[^a-zA-Z0-9]/_/g')
		local vulnerabilities_file="vulnerabilities_${sanitized_image_name}.json"

		# Scan the image
		scan_output=$(./twistcli images scan \
			--address "$CONSOLE" \
			--docker-address "/run/user/1000/docker.sock" \
			--user "$PRISMA_ACCESS_KEY" \
			--password "$PRISMA_SECRET" \
			"$image_name")

		echo "Scan output for $image_name:"
		echo "$scan_output"
	done

	# Remove twistcli
	rm -f ./twistcli
}

# Usage example: scan_docker_images [NAME OF LOCAL DOCKER IMAGE],
# e.g. scan_docker_images liferay/dxp:2025.q1.2-lts
lc_time_run scan_docker_images "${@}"