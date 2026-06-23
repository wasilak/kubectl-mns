# kubectl-mns

[![Codacy Badge](https://app.codacy.com/project/badge/Grade/f7f7d8f26a24480896ade991051123a5)](https://app.codacy.com/gh/wasilak/kubectl-mns/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)
[![Tests](https://github.com/wasilak/kubectl-mns/actions/workflows/tests.yml/badge.svg)](https://github.com/wasilak/kubectl-mns/actions/workflows/tests.yml)

A kubectl plugin that runs any kubectl command across multiple namespaces in a single invocation. Instead of running the same command N times, list the namespaces and the command once — output is labeled per namespace so you can immediately see where each result comes from.

## Features

- Run any kubectl command across a subset of namespaces (not cluster-wide like `--all-namespaces`)
- Per-namespace output labels: `=== namespace: <ns> ===`
- Continues past per-namespace failures (e.g. RBAC denial) — reports the error and moves on
- Forwards `--context` and `--kubeconfig` to every kubectl call
- Strips `--all-namespaces` / `-A` from the forwarded command (the plugin manages namespaces itself)
- Shell-safe: array-based execution, properly quoted expansions (ShellCheck clean)

## Prerequisites

- `kubectl` installed and configured
- Appropriate permissions on the target namespaces

## Installation

1. Download the [latest release](https://raw.githubusercontent.com/wasilak/kubectl-mns/main/kubectl-mns).

2. Make it executable and place it on your `PATH`:

    ```sh
    chmod +x kubectl-mns
    mv kubectl-mns /usr/local/bin/
    ```

Verify with `kubectl mns --help`.

## Usage

Run a command across specific namespaces:

```sh
kubectl mns ns1 ns2 ns3 -- get pods
```

Default to the `default` namespace if none specified:

```sh
kubectl mns -- get pods
```

Forward global flags to every kubectl invocation:

```sh
kubectl mns --context my-ctx ns1 ns2 -- get pods
kubectl mns --kubeconfig /path/to/config ns1 -- get deployments
```

Per-namespace failures are reported and skipped:

```
=== namespace: ns1 ===
NAME    READY   STATUS    RESTARTS   AGE
app-1   1/1     Running   0          5m
Error: kubectl failed for namespace ns2
=== namespace: ns3 ===
NAME    READY   STATUS    RESTARTS   AGE
app-3   1/1     Running   0          3m
```

Help:

```sh
kubectl mns -h
kubectl mns --help
```

## Testing

The test suite uses [bats-core](https://github.com/bats-core/bats-core) with a kubectl stub on `PATH` — no live cluster needed.

```sh
bats test/kubectl-mns.bats
```

CI runs the suite on every push and PR via `.github/workflows/tests.yml`.

## Contributing

Fork the repo, create a branch, open a PR. Run `bats test/kubectl-mns.bats` and `shellcheck kubectl-mns` before submitting.

## License

Apache 2.0 — see [LICENSE](LICENSE).