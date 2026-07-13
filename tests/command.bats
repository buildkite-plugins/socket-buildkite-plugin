#!/usr/bin/env bats

load "$BATS_PLUGIN_PATH/load.bash"

# Uncomment to debug stub failures
# export SOCKET_STUB_DEBUG=/dev/tty

setup() {
  export SOCKET_SECURITY_API_KEY="test-token"
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
