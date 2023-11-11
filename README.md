# kubectl-mns

[![Codacy Badge](https://app.codacy.com/project/badge/Grade/f7f7d8f26a24480896ade991051123a5)](https://app.codacy.com/gh/wasilak/kubectl-mns/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)

`kubectl-mns` is a powerful Kubernetes plugin that enables you to execute kubectl commands on multiple namespaces, giving you the flexibility to target any subset of namespaces, rather than all of them as with the `--all-namespaces` argument.

## Features

- Run any kubectl command across multiple namespaces.
- Choose a specific subset of namespaces for your command, rather than applying it cluster-wide.
- Execute commands with ease, simplifying administrative tasks on multiple namespaces.

## Prerequisites

Before using `kubectl-mns`, ensure you have the following prerequisites:

- `kubectl` installed and configured to connect to your Kubernetes cluster.
- Appropriate permissions to run kubectl commands on the selected namespaces within the cluster.

## Installation

To install `kubectl-mns`, follow these steps:

1. Download the [latest release](https://raw.githubusercontent.com/wasilak/kubectl-mns/main/kubectl-mns).

2. Make it executable.

    ```sh
    chmod +x kubectl-mns
    ```

3. Move it to a directory in your system's PATH, so you can use it as a kubectl plugin.

    ```sh
    mv kubectl-mns /usr/local/bin/
    ```

## Usage

`kubectl-mns` allows you to apply kubectl commands on specific namespaces. Here are some basic examples of how to use it:

- Execute a kubectl command on specific namespaces:

    ```sh
    kubectl mns ns1 ns2 ns3 -- kubectl get pods
    ```

- For a complete list of available commands and their options, run:

    ```sh
    kubectl mns --help
    ```

## Contributing

If you'd like to contribute to this project, please fork and create a PR.

## License

This project is licensed under the Apache 2.0 License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

Special thanks to the Kubernetes community and all the contributors who have made this project possible.

## Contact

If you have any questions, issues, or feedback, please feel free to open an issue on the [GitHub repository](https://github.com/wasilak/kubectl-mns). We'd love to hear from you!

Empower your Kubernetes management with `kubectl-mns`
