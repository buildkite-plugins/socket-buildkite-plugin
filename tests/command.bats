#!/usr/bin/env bats

load "$BATS_PLUGIN_PATH/load.bash"

# Uncomment to debug stub failures
# export SOCKET_STUB_DEBUG=/dev/tty

setup() {
  export SOCKET_SECURITY_API_KEY="test-token"
  export BUILDKITE_PLUGIN_SOCKET_INSTALL="false"
  export BUILDKITE_PIPELINE_SLUG="my-repo"
  export BUILDKITE_BRANCH="main"
}

@test "Runs socket scan create --no-interactive --report by default" {
  stub socket "scan create --no-interactive --report --repo=my-repo --branch=main . : echo scan complete"

  run "$PWD/hooks/command"

  assert_success
  assert_output --partial "scan create --no-interactive --report --repo=my-repo --branch=main ."
  assert_output --partial "scan complete"

  unstub socket
}

@test "Derives the repo name from BUILDKITE_REPO" {
  unset BUILDKITE_PIPELINE_SLUG
  export BUILDKITE_REPO="https://github.com/buildkite/cli.git"

  stub socket "scan create --no-interactive --report --repo=cli --branch=main . : echo ok"

  run "$PWD/hooks/command"

  assert_success
  assert_output --partial "--repo=cli"

  unstub socket
}

@test "Derives the repo name from an ssh BUILDKITE_REPO" {
  unset BUILDKITE_PIPELINE_SLUG
  export BUILDKITE_REPO="git@github.com:buildkite/cli.git"

  stub socket "scan create --no-interactive --report --repo=cli --branch=main . : echo ok"

  run "$PWD/hooks/command"

  assert_success
  assert_output --partial "--repo=cli"

  unstub socket
}

@test "An explicit repo option overrides BUILDKITE_REPO" {
  export BUILDKITE_REPO="https://github.com/buildkite/cli.git"
  export BUILDKITE_PLUGIN_SOCKET_REPO="custom-name"

  stub socket "scan create --no-interactive --report --repo=custom-name --branch=main . : echo ok"

  run "$PWD/hooks/command"

  assert_success
  assert_output --partial "--repo=custom-name"

  unstub socket
}

@test "Omits --report when report is false" {
  export BUILDKITE_PLUGIN_SOCKET_REPORT="false"

  stub socket "scan create --no-interactive --repo=my-repo --branch=main . : echo scan complete"

  run "$PWD/hooks/command"

  assert_success
  refute_output --partial "--report"

  unstub socket
}

@test "Annotates the build with Markdown findings when enabled" {
  export BUILDKITE_PLUGIN_SOCKET_ANNOTATE="true"
  export BUILDKITE_JOB_ID="job-123"

  stub socket "scan create --no-interactive --report --repo=my-repo --branch=main --markdown . : printf '%s\n' '# Scan Policy Report' '' 'No findings'"
  stub buildkite-agent "annotate --style success --context socket-job-123 : test \"\$BUILDKITE_ANNOTATION_SCOPE\" = build && cat"

  run "$PWD/hooks/command"

  assert_success
  assert_output --partial "# Scan Policy Report"
  assert_output --partial "No findings"

  unstub socket
  unstub buildkite-agent
}

@test "Annotates failed findings and preserves the scan exit status" {
  export BUILDKITE_PLUGIN_SOCKET_ANNOTATE="true"
  export BUILDKITE_JOB_ID="job-456"

  stub socket "scan create --no-interactive --report --repo=my-repo --branch=main --markdown . : printf '%s\n' '# Scan Policy Report' '' 'Policy violation'; exit 7"
  stub buildkite-agent "annotate --style error --context socket-job-456 : test \"\$BUILDKITE_ANNOTATION_SCOPE\" = build && cat"

  run "$PWD/hooks/command"

  [ "${status}" -eq 7 ]
  assert_output --partial "Policy violation"

  unstub socket
  unstub buildkite-agent
}

@test "Fails the build when annotation creation fails" {
  export BUILDKITE_PLUGIN_SOCKET_ANNOTATE="true"
  export BUILDKITE_JOB_ID="job-999"

  stub socket "scan create --no-interactive --report --repo=my-repo --branch=main --markdown . : echo '# Scan Policy Report'"
  stub buildkite-agent "annotate --style success --context socket-job-999 : cat >/dev/null; exit 5"

  run "$PWD/hooks/command"

  [ "${status}" -eq 5 ]
  assert_output --partial "Failed to create the Socket build annotation."

  unstub socket
  unstub buildkite-agent
}

@test "Fails the build and publishes a notice when report capture fails" {
  export BUILDKITE_PLUGIN_SOCKET_ANNOTATE="true"
  export BUILDKITE_JOB_ID="job-capture-failed"
  export ANNOTATION_CAPTURE="${BATS_TEST_TMPDIR}/annotation.md"
  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  cat > "${BATS_TEST_TMPDIR}/bin/tee" <<'EOF'
#!/usr/bin/env bash
cat
printf 'partial report' > "$1"
exit 9
EOF
  chmod +x "${BATS_TEST_TMPDIR}/bin/tee"
  export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"

  stub socket "scan create --no-interactive --report --repo=my-repo --branch=main --markdown . : echo '# Scan Policy Report'"
  stub buildkite-agent "annotate --style error --context socket-job-capture-failed : cat > \"\$ANNOTATION_CAPTURE\""

  run "$PWD/hooks/command"

  [ "${status}" -eq 9 ]
  assert_output --partial "Failed to capture the Socket report"
  grep -q "could not be captured" "${ANNOTATION_CAPTURE}"

  unstub socket
  unstub buildkite-agent
}

@test "Rejects JSON output forms when annotations are enabled" {
  export BUILDKITE_PLUGIN_SOCKET_ANNOTATE="true"

  stub socket

  for json_arg in --json --json=true -j -j=true; do
    export BUILDKITE_PLUGIN_SOCKET_ARGS="${json_arg}"

    run "$PWD/hooks/command"

    assert_failure
    assert_output --partial "annotations require Markdown output"
  done

  unstub socket
}

@test "Allows explicitly disabled JSON output when annotations are enabled" {
  export BUILDKITE_PLUGIN_SOCKET_ANNOTATE="true"
  export BUILDKITE_JOB_ID="job-json-false"

  stub socket \
    "scan create --no-interactive --report --repo=my-repo --branch=main --json=false --markdown . : echo '# Scan Policy Report'" \
    "scan create --no-interactive --report --repo=my-repo --branch=main -j=false --markdown . : echo '# Scan Policy Report'"
  stub buildkite-agent \
    "annotate --style success --context socket-job-json-false : cat >/dev/null" \
    "annotate --style success --context socket-job-json-false : cat >/dev/null"

  for json_arg in --json=false -j=false; do
    export BUILDKITE_PLUGIN_SOCKET_ARGS="${json_arg}"

    run "$PWD/hooks/command"

    assert_success
  done

  unstub socket
  unstub buildkite-agent
}

@test "Rejects report-disabling arguments when annotations are enabled" {
  export BUILDKITE_PLUGIN_SOCKET_ANNOTATE="true"

  stub socket

  for report_arg in --no-report --report=false; do
    export BUILDKITE_PLUGIN_SOCKET_ARGS="${report_arg}"

    run "$PWD/hooks/command"

    assert_failure
    assert_output --partial "annotations require policy reporting"
  done

  unstub socket
}

@test "Rejects annotations when report is disabled" {
  export BUILDKITE_PLUGIN_SOCKET_ANNOTATE="true"
  export BUILDKITE_PLUGIN_SOCKET_REPORT="false"

  run "$PWD/hooks/command"

  assert_failure
  assert_output --partial "requires 'report: true'"
}

@test "Appends Markdown mode after user-provided arguments" {
  export BUILDKITE_PLUGIN_SOCKET_ANNOTATE="true"
  export BUILDKITE_PLUGIN_SOCKET_ARGS="--no-markdown"
  export BUILDKITE_JOB_ID="job-789"

  stub socket "scan create --no-interactive --report --repo=my-repo --branch=main --no-markdown --markdown . : echo '# Scan Policy Report'"
  stub buildkite-agent "annotate --style success --context socket-job-789 : cat"

  run "$PWD/hooks/command"

  assert_success

  unstub socket
  unstub buildkite-agent
}

@test "Truncates oversized annotations while retaining the full job log" {
  export BUILDKITE_PLUGIN_SOCKET_ANNOTATE="true"
  export BUILDKITE_JOB_ID="job-large"
  export ANNOTATION_CAPTURE="${BATS_TEST_TMPDIR}/annotation.md"

  stub socket "scan create --no-interactive --report --repo=my-repo --branch=main --markdown . : awk 'BEGIN { print \"# Scan Policy Report\"; for (i = 0; i < 30000; i++) print \"Finding \" i \": abcdefghijklmnopqrstuvwxyz\" }'"
  stub buildkite-agent "annotate --style success --context socket-job-large : cat > \"\$ANNOTATION_CAPTURE\""

  run "$PWD/hooks/command"

  assert_success
  assert_output --partial "Finding 29999"
  [ "$(wc -c < "${ANNOTATION_CAPTURE}")" -lt 1048576 ]
  grep -q "truncated to fit Buildkite" "${ANNOTATION_CAPTURE}"

  unstub socket
  unstub buildkite-agent
}

@test "Adds --auto-manifest when enabled" {
  export BUILDKITE_PLUGIN_SOCKET_AUTO_MANIFEST="true"

  stub socket "scan create --no-interactive --report --auto-manifest --repo=my-repo --branch=main . : echo ok"

  run "$PWD/hooks/command"

  assert_success
  assert_output --partial "--auto-manifest"

  unstub socket
}

@test "Uses a custom directory" {
  export BUILDKITE_PLUGIN_SOCKET_DIRECTORY="./app"

  stub socket "scan create --no-interactive --report --repo=my-repo --branch=main ./app : echo ok"

  run "$PWD/hooks/command"

  assert_success
  assert_output --partial "./app"

  unstub socket
}

@test "Passes through extra args" {
  export BUILDKITE_PLUGIN_SOCKET_ARGS_0="--json"
  export BUILDKITE_PLUGIN_SOCKET_ARGS_1="--markdown"

  stub socket "scan create --no-interactive --report --repo=my-repo --branch=main --json --markdown . : echo ok"

  run "$PWD/hooks/command"

  assert_success
  assert_output --partial "--json --markdown"

  unstub socket
}

@test "Runs non-interactively" {
  stub socket "scan create --no-interactive --report --repo=my-repo --branch=main . : echo ok"

  run "$PWD/hooks/command"

  assert_success
  assert_output --partial "--no-interactive"

  unstub socket
}

@test "Passes --org when set" {
  export BUILDKITE_PLUGIN_SOCKET_ORG="buildkite"

  stub socket "scan create --no-interactive --report --org=buildkite --repo=my-repo --branch=main . : echo ok"

  run "$PWD/hooks/command"

  assert_success
  assert_output --partial "--org=buildkite"

  unstub socket
}

@test "Reads the token from a custom env var" {
  unset SOCKET_SECURITY_API_KEY
  export MY_SOCKET_TOKEN="custom-token"
  export BUILDKITE_PLUGIN_SOCKET_API_TOKEN_ENV="MY_SOCKET_TOKEN"

  stub socket "scan create --no-interactive --report --repo=my-repo --branch=main . : echo ok"

  run "$PWD/hooks/command"

  assert_success

  unstub socket
}

@test "Fails when no API token is present" {
  unset SOCKET_SECURITY_API_KEY

  run "$PWD/hooks/command"

  assert_failure
  assert_output --partial "No Socket API token found"
}

@test "Fails the build when the scan violates policy" {
  stub socket "scan create --no-interactive --report --repo=my-repo --branch=main . : echo policy violation; exit 1"

  run "$PWD/hooks/command"

  assert_failure
  assert_output --partial "policy violation"

  unstub socket
}


# Fake only npm acquisition: the installed CLI is distinct from the stale PATH
# executable, and records its prefix so cleanup can be verified after the hook.
prepare_install() {
  export BUILDKITE_PLUGIN_SOCKET_INSTALL="true"
  export INSTALL_RECORD="${BATS_TEST_TMPDIR}/install-prefix"
  export NPM_RECORD="${BATS_TEST_TMPDIR}/npm-args"
  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  cat > "${BATS_TEST_TMPDIR}/bin/npm" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$NPM_RECORD"
[[ "$1" = install && "$2" = -g && "$3" = --prefix ]] || exit 90
printf '%s' "$4" > "$INSTALL_RECORD"
[[ "${FAIL_INSTALL:-false}" != true ]] || exit 42
mkdir -p "$4/bin"
printf '#!/usr/bin/env bash\necho selected-cli "$@"\n' > "$4/bin/socket"
chmod +x "$4/bin/socket"
EOF
  cat > "${BATS_TEST_TMPDIR}/bin/socket" <<'EOF'
#!/usr/bin/env bash
echo stale-path-cli
exit 91
EOF
  chmod +x "${BATS_TEST_TMPDIR}/bin/"*
  export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
}

@test "Installs latest by default instead of reusing a PATH socket" {
  prepare_install
  unset BUILDKITE_PLUGIN_SOCKET_INSTALL

  run "$PWD/hooks/command"

  assert_success
  assert_output --partial "selected-cli scan create"
  refute_output --partial "stale-path-cli"
  [ "$(tail -1 "$NPM_RECORD")" = socket@latest ]
  [ ! -e "$(cat "$INSTALL_RECORD")" ]
}

@test "Installs an explicit pin instead of reusing a PATH socket" {
  prepare_install
  export BUILDKITE_PLUGIN_SOCKET_VERSION="1.2.3"

  run "$PWD/hooks/command"

  assert_success
  assert_output --partial "selected-cli scan create"
  [ "$(tail -1 "$NPM_RECORD")" = socket@1.2.3 ]
  [ ! -e "$(cat "$INSTALL_RECORD")" ]
}

@test "Does not fall back to a PATH socket when installation fails" {
  prepare_install
  export FAIL_INSTALL=true

  run "$PWD/hooks/command"

  [ "$status" -eq 42 ]
  refute_output --partial "stale-path-cli"
  refute_output --partial "selected-cli"
  [ ! -e "$(cat "$INSTALL_RECORD")" ]
}

@test "Fails clearly when install is disabled and socket is missing" {
  stub socket
  rm -f "$(command -v socket)"

  run "$PWD/hooks/command"

  assert_failure
  assert_output --partial "Socket CLI not found and install is disabled"
}


@test "Installs the selected CLI when no socket is on PATH" {
  prepare_install
  rm "${BATS_TEST_TMPDIR}/bin/socket"

  run "$PWD/hooks/command"

  assert_success
  assert_output --partial "selected-cli scan create"
  [ ! -e "$(cat "$INSTALL_RECORD")" ]
}

@test "Cleans up the installed CLI after annotation success or scan failure" {
  prepare_install
  export BUILDKITE_PLUGIN_SOCKET_ANNOTATE=true
  export BUILDKITE_JOB_ID=install-cleanup
  stub buildkite-agent \
    "annotate --style success --context socket-install-cleanup : cat >/dev/null" \
    "annotate --style error --context socket-install-cleanup : cat >/dev/null"

  run "$PWD/hooks/command"

  assert_success
  [ ! -e "$(cat "$INSTALL_RECORD")" ]

  # Make the installed CLI fail; cleanup must preserve the scan status.
  sed -i.bak 's/echo selected-cli/exit 7; echo selected-cli/' "${BATS_TEST_TMPDIR}/bin/npm"

  run "$PWD/hooks/command"

  [ "$status" -eq 7 ]
  [ ! -e "$(cat "$INSTALL_RECORD")" ]
  unstub buildkite-agent
}

@test "Cleans up the installation prefix when the hook receives TERM" {
  prepare_install
  cat > "${BATS_TEST_TMPDIR}/bin/npm" <<'EOF'
#!/usr/bin/env bash
printf '%s' "$4" > "$INSTALL_RECORD"
mkdir -p "$4/bin"
# Remain in the install long enough for the test to cancel the hook.
sleep 2
EOF

  "$PWD/hooks/command" > "${BATS_TEST_TMPDIR}/cancel.log" 2>&1 &
  local hook_pid=$!
  local ready=false
  local attempt
  for attempt in {1..100}; do
    if [[ -s "$INSTALL_RECORD" ]] && [[ -d "$(cat "$INSTALL_RECORD")/bin" ]]; then
      ready=true
      break
    fi
    sleep 0.05
  done
  kill -TERM "$hook_pid"
  local cancel_status=0
  wait "$hook_pid" || cancel_status=$?

  [ "$ready" = true ]
  [ "$cancel_status" -eq 143 ]
  [ ! -e "$(cat "$INSTALL_RECORD")" ]
}
