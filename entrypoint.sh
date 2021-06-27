#!/bin/sh
#
# Entrypoint for the container.
#
# Prerequisites
# - conftest on $PATH
# - jq on $PATH
# - curl on $PATH
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
comment=""
POLICIES=$(conftest parse "${CONFIG}" --combine | jq -cr '.[].contents.path')
for rego in $(conftest parse "${CONFIG}" --combine | jq -cr '.[].contents.rego[]'); do
	package=$(echo "${rego}" | jq -r '.package')
	sources=$(echo "${rego}" | jq -r '.sources')
	no_fail=$(echo "${rego}" | jq -r '.no_fail')
	flags=""
	if [ "${no_fail}" = "true" ]; then
		flags="--no-fail"
	fi

	# shellcheck disable=SC2086
	output=$(conftest test -o "stdout" ${sources} -p "${POLICIES}" -n "${package}" --combine=false ${flags})
	status=$?

	echo
	echo "Testing '${sources}' against policies in package '${package}'"
	echo "${output}"

	if [ ${status} -ne 0 ]; then
		if [ "${no_fail}" != "true" ]; then
			exitcode=${status}
		fi

		# Store output for GitHub PR comment
		comment="${comment}<details>\n"
		comment="${comment}	<summary>\n"
		comment="${comment}		<code>Testing '${sources}' against policies in package '${package}</code>\n"
		comment="${comment}	</summary>\n"
		comment="${comment}	\`\`\`\n"
		comment="${comment}	${output}\n"
		comment="${comment}	\`\`\`\n"
		comment="${comment}</details>\n"
	fi
done

# Last note and post a comment to the PR it's a PR
if [ -n "${comment}" ]; then
	echo
	echo "Some policy checks have failed."

	if [ "${GITHUB_EVENT_NAME}" = pull_request ]; then
		COMMENT_BODY="#### Some policy checks have failed\n${comment}"
		PAYLOAD=$(echo '{}' | jq --arg body "${COMMENT_BODY}" '.body = $body')
  	COMMENTS_URL=$(jq -r .pull_request.comments_url <"${GITHUB_EVENT_PATH}")
		curl -sS \
			-H "Authorization: token ${GITHUB_TOKEN}" \
			-H 'Content-Type: application/json' \
			-d "${PAYLOAD}" \
			"${COMMENTS_URL}"
	fi
fi

exit ${exitcode}
