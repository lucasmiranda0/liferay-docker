#!/bin/bash

function check_usage {
	if [ -e document_library ]
	then
		return
	fi

	if [ -e /opt/liferay/data ]
	then
		lcd /opt/liferay/data
	else
		echo "Run this script from the Liferay data directory which contains the document_library directory."

		exit 1
	fi
}

function calculate_results {
	rm -fr "${RESULTS_DIR}"

	mkdir -p "${RESULTS_DIR}"

	lcd document_library

	local pwd=$(pwd)

	for company_id in *
	do
		if [ ! -d "${pwd}/${company_id}" ]
		then
			continue
		fi

		lcd "${pwd}/${company_id}"

		mkdir -p "${RESULTS_DIR}/${company_id}"

		lcd "${pwd}/${company_id}/0"

		for dir in adaptive document_preview document_thumbnail
		do
			generated_dir_size "${dir}" >> "${RESULTS_DIR}/${company_id}/generated_files"
		done

		lcd "${pwd}/${company_id}"

		for repository_id in *
		do
			if [[ "${repository_id}" -eq 0 ]] || [ ! -d "${pwd}/${company_id}/${repository_id}" ] || [[ $(find "${pwd}/${company_id}/${repository_id}" -maxdepth 1 -mindepth 1 | wc -l 2>/dev/null) -eq 0 ]]
			then
				continue
			fi

			lcd "${pwd}/${company_id}/${repository_id}"

			for file_entry_id in *
			do
				lcd "${pwd}/${company_id}/${repository_id}/${file_entry_id}"

				if [[ $(find . -maxdepth 1 -mindepth 1 | wc -l) -gt 0 ]]
				then
					for file_version in *
					do
						local file_path="${company_id}/${repository_id}/${file_entry_id}/${file_version}"

						local full_type=$(file_entry_id -b "${file_version}")

						local type=${full_type%% *}

						if [[ ${type} == "Zip" ]]
						then
							if (! unzip -l "${file_version}" &>/dev/null)
							then
								type="BrokenZip"
							elif (unzip -l "${file_version}" | grep manifest.xml &>/dev/null)
							then
								type="LAR"

								if [[ $(find "${file_version}" -ctime +29 | wc -l) -gt 0 ]]
								then
									echo "${file_path}" >> "${RESULTS_DIR}/${company_id}/lar_30_days"
								elif [[ $(find "${file_version}" -ctime +6 | wc -l) -gt 0 ]]
								then
									echo "${file_path}" >> "${RESULTS_DIR}/${company_id}/lar_7_days"
								fi
							fi
						fi

						if [[ ${type} == "ISO" ]]
						then
							if (echo "${full_type}" | grep MP4 &>/dev/null)
							then
								type=MP4
							fi
						fi

						local md5=$(md5sum "${file_version}" | sed -e "s/\ .*//")
						local size=$(stat --printf="%s" "${file_version}")

						echo "${size} ${md5}" >> "${RESULTS_DIR}/${company_id}/type_${type}"
						echo "${file_path} ${type} ${size} ${md5} ${full_type})" >> "${RESULTS_DIR}/${company_id}/all"
					done
				fi
			done
		done
	done
}

function generated_dir_size {
	local size=$(du -s "${1}" 2>/dev/null)

	if [ -n "${size}" ]
	then
		size=$(echo "${size}" | sed -e s/[^0-9]*//g)
		size=$((size / 1024))

		local count=$(find "${1}" -type f | wc -l)

		echo "${1},${count},${count},${size},${size}"
	fi
}

function lcd {
	cd "${1}" || exit 3
}

function main {
	RESULTS_DIR=/tmp/inspect_document_library_results

	check_usage

	if [ -e ${RESULTS_DIR} ]
	then
		echo "Not calculating again because ${RESULTS_DIR} exists from a previous run."
	else
		calculate_results
	fi

	print_data
}

function print_data {
	lcd "${RESULTS_DIR}"

	for companyId in *
	do
		lcd "${company_id}"

		echo "CSV data for company ${company_id}:"
		echo ""
		echo "Type,Count,Unique Count,Size MB,Unique Size MB"

		cat generated_files

		for type in type_*
		do
			type=${type#type_}

			echo -en "${type},"

			local count=$(wc -l "type_${type}" | sed -e "s/\ .*//")

			echo -en "${count},"

			local unique=$(sed -e "s/.*\ //" < "type_${type}"| sort | uniq | wc -l)

			echo -en "${unique},"

			local size=$(sed -e "s/\ .*//" < "type_${type}"| tr '\n' '+' | sed -e "s/\+$/\n/" | bc)

			size=$((size / 1048576))

			echo -en "${size},"

			local unique_size=$(sort < "type_${type}"| uniq | sed -e "s/\ .*//" | tr '\n' '+' | sed -e "s/\+$/\n/" | bc)

			unique_size=$((unique_size / 1048576))

			echo -en "${unique_size}"

			echo ""
		done

		echo ""

		if [ -e lar_7_days ]
		then
			echo "LAR files older than 7 days:"

			cat lar_7_days
		fi

		if [ -e lar_30_days ]
		then
			echo "LAR files older than 30 days:"

			cat lar_30_days
		fi

		lcd "${RESULTS_DIR}"
	done
}

main