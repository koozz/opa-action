#!/bin/sh
#
# Entrypoint for the container.
#
# Prerequisites
# - conftest on $PATH
# - jq on $PATH
#
SETTINGS_YAML="opa-action.yaml"
SETTINGS_REGO="opa-action.rego"
SETTINGS_PKG="opa_action"

# Locate the configuration file
for configuration in .${SETTINGS_YAML} .github/${SETTINGS_YAML}; do
	if [ -f "${configuration}" ]; then
		CONFIG="${configuration}"
		break
	fi
done

# Write settings.rego in container
cat > ${SETTINGS_REGO} <<REGO
package ${SETTINGS_PKG}

deny[msg] {
	not input.path
	msg = "No path to policies specified."
}

deny[msg] {
	not input.rego
	msg = "No rules defined, either configure rules or remove this action."
}

deny[msg] {
	not input.rego[i]["sources"]
	msg = sprintf("Missing 'sources' on: %s", [input.rego[i]])
}

deny[msg] {
	not input.rego[i]["package"]
	msg = sprintf("Missing 'package' on: %s", [input.rego[i]])
}

deny[msg] {
	not is_boolean(input.rego[i]["no_fail"])
	msg = sprintf("Field 'no_fail' is not a boolean: %s", [input.rego[i]])
}
REGO

# Test/dogfood the configuration file
if [ -n "${CONFIG}" ]; then
	echo "Picking up config '${CONFIG}', testing config itself first:"
	if ! conftest test "${CONFIG}" -n "${SETTINGS_PKG}" -p "${SETTINGS_REGO}"; then
		echo "Invalid config, please fix ${CONFIG}"
		exit 1
	fi
else
	cat <<-EOB
		No config found. Please create a config in either:
			- .${SETTINGS_YAML}
			- .github/${SETTINGS_YAML}
		According to the documentation on github.com/koozz/opa-action
	EOB
	exit 1
fi

# Process the configured policies in the configuration
exitcode=0
POLICIES=$(conftest parse "${CONFIG}" --combine | jq -cr '.[].contents.path')
for rego in $(conftest parse "${CONFIG}" --combine | jq -cr '.[].contents.rego[]'); do
	package=$(echo "${rego}" | jq -r '.package')
	sources=$(echo "${rego}" | jq -r '.sources')
	no_fail=$(echo "${rego}" | jq -r '.no_fail')
	flags=""
	if [ "${no_fail}" = "true" ]; then
		flags="--no-fail"
	fi

	echo "::group::Testing '${sources}' against policies in package '${package}'"
	# shellcheck disable=SC2086
	output=$(conftest test -o "stdout" ${sources} -p "${POLICIES}" -n "${package}" --combine=false ${flags})
	status=$?
	echo "${output}"

	if [ ${status} -ne 0 ]; then
		if [ "${no_fail}" != "true" ]; then
			exitcode=${status}
		fi

		# shellcheck disable=SC2086
		conftest test -o tap ${sources} -p "${POLICIES}" -n "${package}" --combine=false ${flags} | \
		grep -e "^not ok" | \
		while read -r _ _ _ _ file _ _ _ failure; do
			echo "::error file=${file}::${failure}"
		done
	fi
	echo "::endgroup::"
done

# Last note for the log
if [ ${exitcode} -ne 0 ]; then
	echo
	echo "Some policy checks have failed."
fi

exit ${exitcode}
