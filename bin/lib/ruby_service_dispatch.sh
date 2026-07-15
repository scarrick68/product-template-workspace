#!/usr/bin/env bash
# Shared dispatch helpers for shell scripts that execute workspace Ruby services.

require_ruby_or_fail() {
	if command -v ruby >/dev/null 2>&1; then
		return 0
	fi

	echo "[FAIL] Ruby is required but was not found in PATH."
	echo "       Install Ruby (mise/rbenv/asdf/Homebrew), then verify with: ruby --version. We recommend Mise but any Ruby version manager should work."
	exit 1
}

ruby_compatible_with_required_version() {
	local required_version="$1"

	ruby -e 'required = ARGV[0]
current = RUBY_VERSION

required_parts = required.split(".").map(&:to_i)
current_parts = current.split(".").map(&:to_i)

compatible =
	current_parts[0] == required_parts[0] &&
	current_parts[1] == required_parts[1] &&
	current_parts[2] >= required_parts[2]

exit(compatible ? 0 : 1)
' "$required_version"
}

require_compatible_ruby_or_fail() {
	local required_version="$1"

	require_ruby_or_fail

	if ruby_compatible_with_required_version "$required_version"; then
		return 0
	fi

	echo "[FAIL] Ruby $(ruby -e 'print RUBY_VERSION') is not compatible with required Ruby ${required_version}."
	echo "       Install a compatible Ruby and ensure it is first in PATH before retrying."
	exit 1
}

run_workspace_service_with_ruby() {
	local script_dir="$1"
	local require_path="$2"
	local service_class="$3"

	exec ruby - "$script_dir" "$require_path" "$service_class" <<'RUBY'
script_dir, require_path, service_class = ARGV
require File.expand_path(require_path, script_dir)
klass = service_class.split("::").reduce(Object) { |scope, name| scope.const_get(name) }
exit klass.new.call
RUBY
}
