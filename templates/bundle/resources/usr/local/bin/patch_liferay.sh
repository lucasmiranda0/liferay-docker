#!/bin/bash

function apply_patch {
	local patch_file_name=${1}
	local patch_version=$(echo "${patch_file_name}" | awk -F"-" '{ print $NF }' | awk -F"." '{ print $1 }')

	if [ -e "/opt/liferay/patching-tool/patch-applied" ]
	then
		local installed_patch=$(cat /opt/liferay/patching-tool/patch-applied)

		if [ ! "${patch_file_name}" == "${installed_patch}" ]
		then
			echo ""
			echo "[LIFERAY] ${patch_file_name} cannot be applied on this container because ${installed_patch} is already installed. Remove ${patch_file_name} from the patching directory to disable this warning message."
		fi
	elif [ "$patch_version" -lt 7310 ] &&
	     ( /opt/liferay/patching-tool/patching-tool.sh apply "${LIFERAY_PATCHING_DIR}/${patch_file_name}" )
	then
		echo "${patch_file_name}" > /opt/liferay/patching-tool/patch-applied

		install_patch_step_2
	else
		install_patch_step_1 "${patch_file_name}"
	fi
}

function install_patch_step_1 {
	local patch_file_name="${1}"

	cp "${LIFERAY_PATCHING_DIR}/${patch_file_name}" /opt/liferay/patching-tool/patches

	if (/opt/liferay/patching-tool/patching-tool.sh install -force)
	then
		install_patch_step_2
	fi
}

function install_patch_step_2 {
	rm --force --recursive /opt/liferay/osgi/state/*

	echo ""
	echo "[LIFERAY] Patch applied successfully."
}

function main {
	if [[ $(ls --almost-all "${LIFERAY_PATCHING_DIR}"/patching-tool-*.zip 2>/dev/null) ]]
	then
		echo ""
		echo "[LIFERAY] Updating Patching Tool."

		mv /opt/liferay/patching-tool/default.properties /opt/liferay/patching-tool-default.properties
		mv /opt/liferay/patching-tool/patches /opt/liferay/patching-tool-upgrade-patches

		rm --force --recursive /opt/liferay/patching-tool

		unzip -d /opt/liferay -q "${LIFERAY_PATCHING_DIR}"/patching-tool-*

		rm --force --recursive /opt/liferay/patching-tool/patches

		mv /opt/liferay/patching-tool-default.properties /opt/liferay/patching-tool/default.properties
		mv /opt/liferay/patching-tool-upgrade-patches /opt/liferay/patching-tool/patches

		echo ""
		echo "[LIFERAY] Patching Tool updated successfully."
	fi

	if [ -n "${LIFERAY_DOCKER_HOTFIX}" ]
	then
		if (! /opt/liferay/patching-tool/patching-tool.sh version | grep --quiet "Patching-tool version: 4.")
		then
			echo "[LIFERAY] The environment variable \"LIFERAY_DOCKER_HOTFIX\" requires Patching Tool 4 and above."
		else
			/opt/liferay/patching-tool/patching-tool.sh install "${LIFERAY_DOCKER_HOTFIX}"
		fi
	elif [ -d "${LIFERAY_PATCHING_DIR}" ] && [[ $(find "${LIFERAY_PATCHING_DIR}" -maxdepth 1 -type f -name "liferay-*.zip" 2>/dev/null) ]]
	then
		if [ $(find "${LIFERAY_PATCHING_DIR}" -maxdepth 1 -type f -name "liferay-*.zip" | wc --lines) == 1 ]
		then
			local patch_file_name=$(basename "${LIFERAY_PATCHING_DIR}"/liferay-*.zip)

			apply_patch "${patch_file_name}"
		else
			local patch_file_name=$(basename $(find "${LIFERAY_PATCHING_DIR}" -maxdepth 1 -name "liferay-*.zip" -type f 2>/dev/null | sort | tail --lines=1))

			echo ""
			echo "[LIFERAY] There were multiple hotfixes in the patching folder. As only one can be installed, applying the latest one: ${patch_file_name}."

			apply_patch "${patch_file_name}"
		fi
	fi
}

main