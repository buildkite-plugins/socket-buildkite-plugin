#!/usr/bin/env bash

# Shared utility functions for the Socket Buildkite plugin

set -euo pipefail

# Usage: log_info "Starting scan"
log_info() {
  echo "[INFO]: $*"
}

# Usage: log_success "Scan passed"
log_success() {
  echo "[SUCCESS]: $*"
}

# Usage: log_warning "No API token supplied"
log_warning() {
  echo "[WARNING]: $*"
}

# Usage: log_error "Scan failed"
log_error() {
  echo "[ERROR]: $*" >&2
}

# Usage: if command_exists socket; then echo "available"; fi
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Usage: if is_debug_mode; then echo "debug"; fi
is_debug_mode() {
  [[ "${BUILDKITE_PLUGIN_DEBUG:-false}" =~ (true|on|1) ]]
}

# Usage: enable_debug_if_requested (call early in your hook scripts)
enable_debug_if_requested() {
  if is_debug_mode; then
    log_info "Debug mode enabled"
    set -x
  fi
}
