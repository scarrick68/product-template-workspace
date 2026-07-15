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

run_workspace_service_with_mise_ruby() {
	local ruby_version="$1"
	local script_dir="$2"
	local require_path="$3"
	local service_class="$4"

	exec mise exec "ruby@${ruby_version}" -- ruby - "$script_dir" "$require_path" "$service_class" <<'RUBY'
script_dir, require_path, service_class = ARGV
require File.expand_path(require_path, script_dir)
klass = service_class.split("::").reduce(Object) { |scope, name| scope.const_get(name) }
exit klass.new.call
RUBY
}
