#!/bin/bash

source ../_liferay_common.sh
source _git.sh
source _github.sh
source _jira.sh
source _product.sh
source _product_info_json.sh
source _promotion.sh
source _releases_json.sh

function add_property {
	local new_key="${1}"
	local new_value="${2}"
	local search_key="${3}"

	sed -i "/${search_key}/a\	\\${new_key}=${new_value}" "build.properties"
}

function check_supported_versions {
	local supported_version="$(echo "${_PRODUCT_VERSION}" | cut -d '.' -f 1,2)"

	if [ -z $(grep "${supported_version}" "${_RELEASE_ROOT_DIR}"/supported-"${LIFERAY_RELEASE_PRODUCT_NAME}"-versions.txt) ]
	then
		lc_log ERROR "Unable to find ${supported_version} in supported-${LIFERAY_RELEASE_PRODUCT_NAME}-versions.txt."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function check_usage {
	if [ -z "${LIFERAY_RELEASE_PREPARE_NEXT_RELEASE_BRANCH}" ] || [ -z "${LIFERAY_RELEASE_RC_BUILD_TIMESTAMP}" ] || [ -z "${LIFERAY_RELEASE_VERSION}" ]
	then
		print_help
	fi

	if [ -z "${LIFERAY_RELEASE_PRODUCT_NAME}" ]
	then
		LIFERAY_RELEASE_PRODUCT_NAME=dxp
	fi

	set_product_version "${LIFERAY_RELEASE_VERSION}" "${LIFERAY_RELEASE_RC_BUILD_TIMESTAMP}"

	lc_cd "$(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)")"

	_RELEASE_ROOT_DIR="${PWD}"

	_BASE_DIR="$(dirname "${_RELEASE_ROOT_DIR}")"

	_PROJECTS_DIR="/opt/dev/projects/github"

	if [ ! -d "${_PROJECTS_DIR}" ]
	then
		_PROJECTS_DIR="${_RELEASE_ROOT_DIR}/dev/projects"
	fi

	_PROMOTION_DIR="${_RELEASE_ROOT_DIR}/release-data/promotion/files"

	rm -fr "${_PROMOTION_DIR}"

	mkdir -p "${_PROMOTION_DIR}"

	lc_cd "${_PROMOTION_DIR}"

	LIFERAY_COMMON_LOG_DIR="${_PROMOTION_DIR%/*}"
}

function commit_to_branch_and_send_pull_request {
	git add "${1}"

	git commit --message "${2}"

	local repository_name=$(echo "${5}" | cut -d '/' -f 2)

	git push --force "git@github.com:liferay-release/${repository_name}.git" "${3}"

	gh pr create \
		--base "${4}" \
		--body "Created by liferay-docker/release/release_gold.sh." \
		--head "liferay-release:${3}" \
		--repo "${5}" \
		--title "${6}"

	if [ "${?}" -ne 0 ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function get_tag_name {
	if [ "${LIFERAY_RELEASE_PRODUCT_NAME}" == "dxp" ]
	then
		echo "${_ARTIFACT_VERSION}"
	elif [ "${LIFERAY_RELEASE_PRODUCT_NAME}" == "portal" ]
	then
		echo "${_PRODUCT_VERSION}"
	fi
}

function main {
	if [[ " ${@} " =~ " --test " ]]
	then
		return
	fi

	check_usage

	# check_supported_versions

	# init_gcs

	# lc_time_run promote_packages

	# lc_time_run tag_release

	# promote_boms xanadu

	# if [[ ! $(echo "${_PRODUCT_VERSION}" | grep "q") ]] &&
	#    [[ ! $(echo "${_PRODUCT_VERSION}" | grep "7.4") ]]
	# then
	# 	lc_log INFO "Do not update product_info.json for quarterly and 7.4 releases."

	# 	lc_time_run generate_product_info_json

	# 	lc_time_run upload_product_info_json
	# fi

	# lc_time_run generate_releases_json

	# lc_time_run test_boms

	# lc_time_run add_patcher_project_version

	# if [ -d "${_RELEASE_ROOT_DIR}/dev/projects" ]
	# then
	# 	lc_background_run clone_repository liferay-portal-ee

	# 	lc_wait
	# fi

	# lc_time_run clean_portal_repository

	# #lc_time_run prepare_next_release_branch

	# #lc_time_run update_release_info_date

	# _PROJECTS_DIR="/home/me/dev/projects"
	LIFERAY_RELEASE_PRODUCT_NAME="dxp"
	_PRODUCT_VERSION="2025.q1.0-lts"
	LIFERAY_RELEASE_RC_BUILD_TIMESTAMP="1739837301"
	reference_new_releases

	#lc_time_run upload_to_docker_hub
}

function prepare_branch_to_commit {
	lc_cd "${_PROJECTS_DIR}/liferay-portal-ee"

	git restore .

	git checkout master &> /dev/null

	git branch --delete --force "${1}" &> /dev/null

	git fetch --no-tags git@github.com:liferay/liferay-portal-ee.git "${1}":"${1}" &> /dev/null

	git checkout "${1}" &> /dev/null

	if [ "$(git rev-parse --abbrev-ref HEAD 2> /dev/null)" != "${1}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function prepare_branch_to_commit_from_master {
	lc_cd "${1}"

	git checkout master

	git fetch git@github.com:liferay/liferay-jenkins-ee.git master

	git reset --hard FETCH_HEAD

	git push --delete git@github.com:liferay-release/liferay-jenkins-ee.git "${2}"

	git branch --delete --force "${2}"

	git checkout -b "${2}"

	git push git@github.com:liferay-release/liferay-jenkins-ee.git "${2}" --force

	if [ "$(git rev-parse --abbrev-ref HEAD)" != "${2}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function prepare_next_release_branch {
	if [ ! $(echo "${LIFERAY_RELEASE_PREPARE_NEXT_RELEASE_BRANCH}" | grep -i "true") ] ||
	   [[ "${_PRODUCT_VERSION}" != *q* ]]
	then
		lc_log INFO "Skipping the preparation of the next release branch."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	if [[ ! " ${@} " =~ " --test " ]]
	then
		rm -fr releases.json

		LIFERAY_COMMON_DOWNLOAD_SKIP_CACHE="true" lc_download "https://releases.liferay.com/releases.json" releases.json
	fi

	local product_group_version="$(echo "${_PRODUCT_VERSION}" | cut -d '.' -f 1,2)"

	local latest_quarterly_product_version="$(\
		jq -r ".[] | \
			select(.productGroupVersion == \"${product_group_version}\" and .promoted == \"true\") | \
			.targetPlatformVersion" releases.json)"

	if [[ ! " ${@} " =~ " --test " ]]
	then
		rm -fr releases.json
	fi

	if [ "${_PRODUCT_VERSION}" != "${latest_quarterly_product_version}" ]
	then
		lc_log INFO "The ${_PRODUCT_VERSION} version is not the latest quartely release. Skipping the preparation of the next release branch."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local quarterly_release_branch="release-${product_group_version}"

	prepare_branch_to_commit "${quarterly_release_branch}"

	if [ "${?}" -eq "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
	then
		lc_log ERROR "Unable to prepare the next release branch."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	else
		local next_project_version_suffix="$(echo "${_PRODUCT_VERSION}" | cut -d '.' -f 3)"

		next_project_version_suffix=$((next_project_version_suffix + 1))

		if [[ "${_PRODUCT_VERSION}" == *q1* ]]
		then
			if [[ "$(echo "${_PRODUCT_VERSION}" | cut -d '.' -f 1)" -ge 2025 ]]
			then
				next_project_version_suffix="${next_project_version_suffix} LTS"
			fi
		fi

		sed -i \
			-e "s/release.info.version.display.name\[master-private\]=.*/release.info.version.display.name[master-private]=${product_group_version^^}.${next_project_version_suffix}/" \
			"${_PROJECTS_DIR}/liferay-portal-ee/release.properties"

		sed -i \
			-e "s/release.info.version.display.name\[release-private\]=.*/release.info.version.display.name[release-private]=${product_group_version^^}.${next_project_version_suffix}/" \
			"${_PROJECTS_DIR}/liferay-portal-ee/release.properties"

		if [[ ! " ${@} " =~ " --test " ]]
		then
			commit_to_branch_and_send_pull_request \
				"${_PROJECTS_DIR}/liferay-portal-ee/release.properties" \
				"Prepare ${product_group_version}.${next_project_version_suffix}" \
				"${quarterly_release_branch}" \
				"${quarterly_release_branch}" \
				"brianchandotcom/liferay-portal-ee" \
				"Prep next"

			if [ "${?}" -eq "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
			then
				lc_log ERROR "Unable to commit to the release branch."

				return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
			else
				lc_log INFO "The next release branch was prepared successfully."
			fi
		fi
	fi
}

function print_help {
	echo "Usage: LIFERAY_RELEASE_RC_BUILD_TIMESTAMP=<timestamp> LIFERAY_RELEASE_VERSION=<version> ${0}"
	echo ""
	echo "The script reads the following environment variables:"
	echo ""
	echo "    LIFERAY_RELEASE_GCS_TOKEN (optional): *.json file containing the token to authenticate with Google Cloud Storage"
	echo "    LIFERAY_RELEASE_GITHUB_PAT (optional): GitHub personal access token used to tag releases"
	echo "    LIFERAY_RELEASE_NEXUS_REPOSITORY_PASSWORD (optional): Nexus user's password"
	echo "    LIFERAY_RELEASE_NEXUS_REPOSITORY_USER (optional): Nexus user with the right to upload BOM files"
	echo "    LIFERAY_RELEASE_PATCHER_PORTAL_EMAIL_ADDRESS: Email address to the release team's Liferay Patcher user"
	echo "    LIFERAY_RELEASE_PATCHER_PORTAL_PASSWORD: Password to the release team's Liferay Patcher user"
	echo "    LIFERAY_RELEASE_PREPARE_NEXT_RELEASE_BRANCH: Set to \"true\" to prepare the next release branch. The default is \"false\"."
	echo "    LIFERAY_RELEASE_PRODUCT_NAME (optional): Set to \"portal\" for CE. The default is \"DXP\"."
	echo "    LIFERAY_RELEASE_RC_BUILD_TIMESTAMP: Timestamp of the build to publish"
	echo "    LIFERAY_RELEASE_VERSION: DXP or portal version of the release to publish"
	echo ""
	echo "Example: LIFERAY_RELEASE_PREPARE_NEXT_RELEASE_BRANCH=true LIFERAY_RELEASE_RC_BUILD_TIMESTAMP=1695892964 LIFERAY_RELEASE_VERSION=2023.q3.0 ${0}"

	exit "${LIFERAY_COMMON_EXIT_CODE_HELP}"
}

function reference_new_releases {
	if [[ "${_PRODUCT_VERSION}" != *q* ]]
	then
		lc_log INFO "Skipping the update to the references in the liferay-jenkins-ee repository."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	if [[ ! " ${@} " =~ " --test " ]]
	then
		prepare_branch_to_commit_from_master "${_PROJECTS_DIR}/liferay-jenkins-ee/commands" "new_releases_branch"
	fi

	if [ "${?}" -ne 0 ]
	then
		lc_log ERROR "Unable to prepare the next release references branch."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local base_url="http://mirrors.lax.liferay.com/releases.liferay.com"
	local previous_product_version="$(grep "portal.latest.bundle.version\[master\]=" "build.properties" | cut -d "=" -f 2)"

	for component in osgi sql tools
	do
		add_property \
			"portal.${component}.zip.url\[${_PRODUCT_VERSION}\]" \
			"${base_url}/${LIFERAY_RELEASE_PRODUCT_NAME}/${_PRODUCT_VERSION}/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-${component}-${_PRODUCT_VERSION}-${LIFERAY_RELEASE_RC_BUILD_TIMESTAMP}.zip" \
			"portal.${component}.zip.url\[${previous_product_version}\]="
	done

	add_property \
		"plugins.war.zip.url\[${_PRODUCT_VERSION}\]" \
		"http://release-1/1/userContent/liferay-release-tool/7413/plugins.war.latest.zip" \
		"plugins.war.zip.url\[${previous_product_version}\]="

	add_property \
		"	portal.bundle.tomcat\[${_PRODUCT_VERSION}\]" \
		"${base_url}/${LIFERAY_RELEASE_PRODUCT_NAME}/${_PRODUCT_VERSION}/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-tomcat-${_PRODUCT_VERSION}-${LIFERAY_RELEASE_RC_BUILD_TIMESTAMP}.7z" \
		"portal.bundle.tomcat\[${previous_product_version}\]="

	add_property \
		"portal.license.url\[${_PRODUCT_VERSION}\]" \
		"http://www.liferay.com/licenses/license-portaldevelopment-developer-cluster-7.0de-liferaycom.xml" \
		"portal.license.url\[${previous_product_version}\]="

	add_property \
		"portal.version.latest\[${_PRODUCT_VERSION}\]" \
		"${_PRODUCT_VERSION}" \
		"portal.version.latest\[${previous_product_version}\]="

	add_property \
		"portal.war.url\[${_PRODUCT_VERSION}\]" \
		"${base_url}/${LIFERAY_RELEASE_PRODUCT_NAME}/${_PRODUCT_VERSION}/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-${_PRODUCT_VERSION}-${LIFERAY_RELEASE_RC_BUILD_TIMESTAMP}.war" \
		"portal.war.url\[${previous_product_version}\]="

	add_property \
		"portal.latest.bundle.version\[${_PRODUCT_VERSION}\]" \
		"${_PRODUCT_VERSION}" \
		"portal.latest.bundle.version\[${previous_product_version}\]="

	replace_property \
		"portal.latest.bundle.version\[master\]" \
		"${_PRODUCT_VERSION}" \
		"portal.latest.bundle.version\[master\]=${previous_product_version}"

	local previous_quarterly_release_branch="$(\
		grep "portal.latest.bundle.version" \
			"build.properties" | \
			tail -1 | \
			cut -d '[' -f 2 | \
			cut -d ']' -f 1)"

	local quarterly_release_branch="release-$(echo "${_PRODUCT_VERSION}" | cut -d '.' -f 1,2)"

	if [ "${quarterly_release_branch}" == "${previous_quarterly_release_branch}" ]
	then
		replace_property \
			"portal.latest.bundle.version\[${quarterly_release_branch}\]" \
			"${_PRODUCT_VERSION}" \
			"portal.latest.bundle.version\[${quarterly_release_branch}\]=${previous_product_version}"

		replace_property \
			"portal.version.latest\[${quarterly_release_branch}\]" \
			"${_PRODUCT_VERSION}" \
			"portal.version.latest\[${quarterly_release_branch}\]=${previous_product_version}"
	else
		add_property \
			"portal.latest.bundle.version\[${quarterly_release_branch}\]" \
			"${_PRODUCT_VERSION}" \
			"portal.latest.bundle.version\[${previous_quarterly_release_branch}\]="

		add_property \
			"portal.version.latest\[${quarterly_release_branch}\]" \
			"${_PRODUCT_VERSION}" \
			"portal.version.latest\[${previous_quarterly_release_branch}\]="
	fi

	if [[ ! " ${@} " =~ " --test " ]]
	then
		# local issue_key="$(\
		# 	add_jira_issue \
		# 		"60a3f462391e56006e6b661b" \
		# 		"Release Tester" \
		# 		"Task" \
		# 		"LRCI" \
		# 		"Add release references for ${_PRODUCT_VERSION}" \
		# 		"customfield_10001" \
		# 		"04c03e90-c5a7-4fda-82f6-65746fe08b83")"

		if [ "${issue_key}" == "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
		then
			lc_log ERROR "Unable to create the Jira issue."

			return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi

		commit_to_branch_and_send_pull_request \
			"${_PROJECTS_DIR}/liferay-jenkins-ee/commands/build.properties" \
			"${issue_key} Add release references for ${_PRODUCT_VERSION}" \
			"new_releases_branch" \
			"master" \
			"kiwm/liferay-jenkins-ee" \
			"${issue_key} Add release references for ${_PRODUCT_VERSION}."

		if [ "${?}" -ne 0 ]
		then
			lc_log ERROR "Unable to send pull request with references to the next release."

			return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		else
			lc_log INFO "Pull request with references to the next release was sent successfully."
		fi

		local pull_request_url="$(\
			gh pr view liferay-release:new_releases_branch \
				--jq ".url" \
				--json "url" \
				--repo "kiwm/liferay-jenkins-ee")"

		# add_jira_issue_comment "Related pull request: ${pull_request_url}" "${issue_key}"
	fi
}

function replace_property {
	local new_key="${1}"
	local new_value="${2}"
	local search_key="${3}"

	sed -i "s/${search_key}/${new_key}=${new_value}/" "build.properties"
}

function tag_release {
	if [ -z "${LIFERAY_RELEASE_GITHUB_PAT}" ]
	then
		lc_log INFO "Set the environment variable \"LIFERAY_RELEASE_GITHUB_PAT\"."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local release_properties_file=$(lc_download "https://releases.liferay.com/${LIFERAY_RELEASE_PRODUCT_NAME}/${_PRODUCT_VERSION}/release.properties")

	if [ $? -ne 0 ]
	then
		lc_log ERROR "Unable to download release.properties."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local git_hash=$(lc_get_property "${release_properties_file}" git.hash.liferay-portal-ee)

	if [ -z "${git_hash}" ]
	then
		lc_log ERROR "Unable to get property \"git.hash.liferay-portal-ee.\""

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local repository=liferay-portal-ee

	if [ "${LIFERAY_RELEASE_PRODUCT_NAME}" == "portal" ]
	then
		repository=liferay-portal
	fi

	local tag_name="$(get_tag_name)"

	for repository_owner in brianchandotcom liferay
	do
		local tag_data=$(
			cat <<- END
			{
				"message": "",
				"object": "${git_hash}",
				"tag": "${tag_name}",
				"type": "commit"
			}
			END
		)

		if [ $(invoke_github_api_post "${repository_owner}" "${repository}/git/tags" "${tag_data}") -eq "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}" ]
		then
			lc_log ERROR "Unable to create tag ${tag_name} in ${repository_owner}/${repository}."

			return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
		fi

		local ref_data=$(
			cat <<- END
			{
				"message": "",
				"ref": "refs/tags/${tag_name}",
				"sha": "${git_hash}"
			}
			END
		)

		if [ $(invoke_github_api_post "${repository_owner}" "${repository}/git/refs" "${ref_data}") -eq "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}" ]
		then
			lc_log ERROR "Unable to create tag reference for ${tag_name} in ${repository_owner}/${repository}."

			return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
		fi
	done

	if [[ "${_PRODUCT_VERSION}" == 7.4.*-u* ]]
	then
		local temp_branch="release-$(echo "${_PRODUCT_VERSION}" | sed -r "s/-u/\./")"

		if [ $(invoke_github_api_delete "brianchandotcom" "${repository}/git/refs/heads/${temp_branch}") -eq "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}" ]
		then
			lc_log ERROR "Unable to delete temp branch ${temp_branch} in ${LIFERAY_RELEASE_REPOSITORY_OWNER}/${repository}."

			return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
		fi
	fi
}

function test_boms {
	if [[ "${_PRODUCT_VERSION}" == 7.4.*-u* ]]
	then
		lc_log INFO "Skipping test BOMs for ${_PRODUCT_VERSION}."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	rm -f "${HOME}/.liferay/workspace/releases.json"

	mkdir -p "temp_dir_test_boms"

	lc_cd "temp_dir_test_boms"

	if [[ "${_PRODUCT_VERSION}" == *q* ]]
	then
		blade init -v "${LIFERAY_RELEASE_PRODUCT_NAME}-${_PRODUCT_VERSION}"
	else
		local product_group_version=$(echo "${_PRODUCT_VERSION}" | cut -d '.' -f 1,2)
		local product_version_suffix=$(echo "${_PRODUCT_VERSION}" | cut -d '-' -f 2)

		blade init -v "${LIFERAY_RELEASE_PRODUCT_NAME}-${product_group_version}-${product_version_suffix}"
	fi

	export LIFERAY_RELEASES_MIRRORS="https://releases.liferay.com"

	sed -i "s/version: \"10.1.0\"/version: \"10.1.2\"/" "temp_dir_test_boms/settings.gradle"

	for module in api mvc-portlet
	do
		blade create -t "${module}" "test-${module}"

		local build_result=$(blade gw build)

		if [[ "${build_result}" == *"BUILD SUCCESSFUL"* ]]
		then
			lc_log INFO "The BOMs for the module ${module} were successfully tested."
		else
			lc_log ERROR "The BOMs for the module ${module} were incorrectly generated."

			break
		fi
	done

	lc_cd ".."

	pgrep --full --list-name temp_dir_test_boms | awk '{print $1}' | xargs --no-run-if-empty kill -9

	rm -fr "temp_dir_test_boms"

	if [[ "${build_result}" != *"BUILD SUCCESSFUL"* ]]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function update_release_info_date {
	if [ ! $(echo "${LIFERAY_RELEASE_PREPARE_NEXT_RELEASE_BRANCH}" | grep -i "true") ] ||
	   [[ "${_PRODUCT_VERSION}" != *q* ]] ||
	   [[ "$(echo "${_PRODUCT_VERSION}" | cut -d '.' -f 3)" -eq 0 ]] ||
	   [[ "$(echo "${_PRODUCT_VERSION}" | cut -d '.' -f 1)" -lt 2024 ]]
	then
		lc_log INFO "Skipping the release info update."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local product_group_version="$(echo "${_PRODUCT_VERSION}" | cut -d '.' -f 1,2)"

	local quarterly_release_branch="release-${product_group_version}"

	prepare_branch_to_commit "${quarterly_release_branch}"

	if [ "${?}" -eq "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
	then
		lc_log ERROR "Unable to update the release date."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	sed -i \
		-e "s/release.info.date=.*/release.info.date=$(date -d "next monday" +"%B %-d, %Y")/" \
		release.properties

	if [[ ! " ${@} " =~ " --test " ]]
	then
		commit_to_branch_and_send_pull_request \
			"${_PROJECTS_DIR}/liferay-portal-ee/release.properties" \
			"Update the release info date for ${_PRODUCT_VERSION}" \
			"${quarterly_release_branch}" \
			"${quarterly_release_branch}" \
			"brianchandotcom/liferay-portal-ee" \
			"Prep next"

		if [ "${?}" -eq "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
		then
			lc_log ERROR "Unable to commit to the release branch."

			return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		else
			lc_log INFO "The release date was updated successfully."
		fi
	fi
}

main "${@}"