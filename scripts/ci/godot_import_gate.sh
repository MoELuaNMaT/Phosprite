#!/usr/bin/env bash
set -euo pipefail

godot_bin="${1:-godot}"
log_file="${RUNNER_TEMP:-/tmp}/phosprite-godot-import-${GITHUB_RUN_ID:-local}-${GITHUB_RUN_ATTEMPT:-0}.log"

set +e
"${godot_bin}" --headless --path . -v --import 2>&1 | tee "${log_file}"
godot_status=${PIPESTATUS[0]}
set -e

if [[ ${godot_status} -ne 0 ]]; then
  echo "::error::Godot import exited with status ${godot_status}."
  exit "${godot_status}"
fi

if grep -E 'SCRIPT ERROR: (Parse Error|Compile Error)|Failed to load script .*Parse error' "${log_file}" >/dev/null; then
  echo "::error::Godot import reported GDScript parse/compile errors."
  grep -E 'SCRIPT ERROR: (Parse Error|Compile Error)|Failed to load script .*Parse error' "${log_file}" || true
  exit 1
fi
