#!/usr/bin/env bash
# Registry and configuration helpers for multi-CA support

# This file is intended to be sourced by other scripts.
# Requires utils.sh to be sourced first for fatal/info helpers.

# XDG base directories
: "${XDG_DATA_HOME:=${HOME}/.local/share}"
: "${XDG_CONFIG_HOME:=${HOME}/.config}"

# Default roots
: "${CA_DATA_ROOT:=${XDG_DATA_HOME}/simple-ca}"
: "${CA_CONFIG_DIR:=${XDG_CONFIG_HOME}/simple_ca}"
: "${REGISTRY_PATH:=${CA_CONFIG_DIR}/config.json}"

ensure_config_dir() {
	mkdir -p "${CA_CONFIG_DIR}" || fatal "Failed to create config dir: ${CA_CONFIG_DIR}"
}

config_path() {
	printf '%s' "${REGISTRY_PATH}"
}

_have_jq() {
	command -v jq >/dev/null 2>&1
}

# Load registry JSON safely; if missing, echo minimal empty structure
load_registry() {
	if [[ -f "${REGISTRY_PATH}" ]]; then
		cat "${REGISTRY_PATH}"
	else
		printf '%s' '{"defaultCa":null,"cas":{}}'
	fi
}

save_registry() {
	ensure_config_dir
	local tmp
	tmp=$(mktemp)
	cat >"${tmp}" || fatal "Failed writing temp registry"
	mv "${tmp}" "${REGISTRY_PATH}" || fatal "Failed to save registry to ${REGISTRY_PATH}"
}

registry_get_default() {
	if _have_jq && [[ -f "${REGISTRY_PATH}" ]]; then
		jq -r '.defaultCa // empty' "${REGISTRY_PATH}" 2>/dev/null | sed '/^null$/d'
		return 0
	fi
	# Fallback: no jq or no registry → no default
	return 1
}

registry_set_default() {
	local ca_id=${1:?"ca_id required"}
	ensure_config_dir
	if _have_jq; then
		local current
		current=$(load_registry)
		echo "${current}" | jq --arg id "$ca_id" '.defaultCa=$id' | save_registry
		info "Default CA set to: ${ca_id}"
		return 0
	fi
	fatal "Setting default requires jq (install jq)" 2
}

registry_register_ca() {
	local ca_id=${1:?}
	local data_path=${2:?}
	local export_path=${3:-""}
	local created_at
	created_at=$(date -Is)
	ensure_config_dir
	if _have_jq; then
		local current
		current=$(load_registry)
		echo "${current}" | jq \
			--arg id "$ca_id" \
			--arg data "$data_path" \
			--arg export "$export_path" \
			--arg created "$created_at" \
			'.cas[$id] = {id:$id, createdAt:$created, dataPath:$data, exportPath:$export}' \
			| save_registry
		info "Registered CA '${ca_id}'"
		return 0
	fi
	# Fallback: best-effort create a minimal registry file if missing
	if [[ ! -f "${REGISTRY_PATH}" ]]; then
		cat >"${REGISTRY_PATH}" <<EOF
{"defaultCa":null,"cas":{"${ca_id}":{"id":"${ca_id}","createdAt":"${created_at}","dataPath":"${data_path}","exportPath":"${export_path}"}}}
EOF
		return 0
	fi
	fatal "Registering CA requires jq (install jq)" 2
}

registry_remove_ca() {
	local ca_id=${1:?}
	ensure_config_dir
	if _have_jq && [[ -f "${REGISTRY_PATH}" ]]; then
		local current
		current=$(load_registry)
		echo "${current}" | jq --arg id "$ca_id" 'del(.cas[$id]) | (.defaultCa == $id) as $is | (if $is then .defaultCa=null else . end)' | save_registry
		info "Removed CA '${ca_id}' from registry"
		return 0
	fi
	fatal "Removing CA requires jq (install jq)" 2
}

registry_list() {
	# Prints lines: id<TAB>dataPath<TAB>default*
	local default_id
	default_id=$(registry_get_default || true)
	if _have_jq && [[ -f "${REGISTRY_PATH}" ]]; then
		jq -r --arg def "$default_id" '.cas | to_entries[] | [ .key, .value.dataPath, (if .key==$def then "*" else "" end) ] | @tsv' "${REGISTRY_PATH}" 2>/dev/null
		return 0
	fi
	# Fallback: scan data root
	local root="${CA_DATA_ROOT}/cas"
	if [[ -d "$root" ]]; then
		for p in "$root"/*; do
			[[ -d "$p" ]] || continue
			local id
			id=$(basename "$p")
			local mark=""
			[[ "$id" == "$default_id" ]] && mark="*"
			printf '%s\t%s\t%s\n' "$id" "$p" "$mark"
		done
	fi
}
