#!/usr/bin/env bash
# Shared helper functions for bootstrapping Ruby toolchains from shell scripts.

read_required_ruby_version() {
	local workspace_root="$1"
	local version_file

	for version_file in "${workspace_root}/.ruby-version" "${workspace_root}/repos/api-template/.ruby-version"; do
		if [[ -f "$version_file" ]]; then
			local value
			value="$(tr -d '\\r\\n' < "$version_file")"
			value="${value#ruby }"
			value="${value#ruby-}"
			value="${value#v}"
			if [[ -n "$value" ]]; then
				echo "$value"
				return
			fi
		fi
	done

	echo "3.4.0"
}

prompt_yes_no() {
	local prompt="$1"
	read -r -p "$prompt [y/N]: " answer
	case "${answer,,}" in
		y|yes) return 0 ;;
		*) return 1 ;;
	esac
}

ensure_brew_in_path() {
	if command -v brew >/dev/null 2>&1; then
		eval "$(brew shellenv)"
		return 0
	fi

	if [[ -x /opt/homebrew/bin/brew ]]; then
		eval "$(/opt/homebrew/bin/brew shellenv)"
	elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
		eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
	elif [[ -x /usr/local/bin/brew ]]; then
		eval "$(/usr/local/bin/brew shellenv)"
	fi

	command -v brew >/dev/null 2>&1
}
