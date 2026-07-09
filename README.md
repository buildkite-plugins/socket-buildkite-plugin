# Socket Buildkite Plugin

A [Buildkite plugin](https://buildkite.com/docs/pipelines/integrations/plugins) that scans your project's dependencies for supply chain risks using [Socket](https://socket.dev). It wraps the [Socket CLI](https://docs.socket.dev/docs/socket-cli) `socket scan create --report`, which creates a scan, waits for the report, and fails the build if the scan violates your organization's security or license policy.

## Example

Add the following to your `pipeline.yml`:

```yaml
steps:
  - label: ":socket: Socket scan"
    plugins:
      - socket#v1.0.0: ~
```

The plugin needs a Socket API token. The simplest approach is to expose it as the `SOCKET_SECURITY_API_KEY` environment variable (for example, via Cluster secrets or agent environment), which the Socket CLI reads natively:

```yaml
steps:
  - label: ":socket: Socket scan"
    secrets:
      - SOCKET_SECURITY_API_KEY
    plugins:
      - socket#v1.0.0: ~
```

If your token lives in a differently named variable, point `api-token-env` at it:

```yaml
steps:
  - label: ":socket: Socket scan"
    plugins:
      - socket#v1.0.0:
          api-token-env: MY_SOCKET_TOKEN
          directory: ./app
          auto-manifest: true
```

## Options

### `api-token-env` (string)

Name of the environment variable that holds your Socket API token. Defaults to `SOCKET_SECURITY_API_KEY`. The plugin reads that variable and exports it as `SOCKET_SECURITY_API_KEY` for the CLI.

### `directory` (string)

Directory to scan. Defaults to `.`.

### `report` (boolean)

Wait for the report and fail the build if the scan violates your security or license policy. Defaults to `true`. Set to `false` to create a scan without gating the build.

### `auto-manifest` (boolean)

Auto-generate manifest files for ecosystems that require it (for example, Gradle or sbt). Defaults to `false`.

### `repo` (string)

Repository name to associate the scan with. Defaults to the repository name
derived from `$BUILDKITE_REPO` (for example, `cli` from
`https://github.com/buildkite/cli.git`), falling back to `$BUILDKITE_PIPELINE_SLUG`.

### `branch` (string)

Branch name to associate the scan with. Defaults to `$BUILDKITE_BRANCH`.

### `version` (string)

Version of the [`socket`](https://www.npmjs.com/package/socket) npm package to install when the CLI is not already present. Defaults to `latest`.

### `install` (boolean)

Install the Socket CLI via `npm install -g` if it is not already on the agent's `PATH`. Defaults to `true`. Set to `false` if you pre-install the CLI on your agents.

### `args` (string or array)

Additional arguments passed through to `socket scan create`.

```yaml
steps:
  - label: ":socket: Socket scan"
    plugins:
      - socket#v1.0.0:
          args:
            - --json
```

## Requirements

- `node` and `npm` available on the agent (used to install the Socket CLI when `install` is enabled).
- A Socket API token. See [Create Socket API Key for CI/CD](https://docs.socket.dev/docs/create-socket-api-key-for-cicd).

## Developing

Run the tests with the Buildkite plugin tester:

```bash
docker compose run --rm tests
```

Lint the plugin:

```bash
docker compose run --rm lint
```

## License

MIT (see [LICENSE](LICENSE)).
