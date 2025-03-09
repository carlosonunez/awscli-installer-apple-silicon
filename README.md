# AWS CLI Installer for Apple Silicon Macs

Install the AWS CLI without package managers on Apple Silicon Macs.

```sh
curl https://raw.githubusercontent.com/carlosonunez/awscli-installer-apple-silicon/refs/heads/main/install.sh | bash
```

You can also install a specific version of the AWS CLI, if you'd like:

```sh
curl https://raw.githubusercontent.com/carlosonunez/awscli-installer-apple-silcon/ref/heads/main/install.sh | bash -s -- --version 2.20.0
```

## Why?

AWS [doesn't](https://github.com/aws/aws-cli/issues/7252) offer an
official way of installing v2 of the CLI on Apple Silicon Macs. The
[instructions](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
they provide are actually for Intel-based Macs, which Apple hasn't made
any of since 2022 or so!

The unofficial way of installing AWS CLI is via Homebrew. If you don't
use `brew`, however, you're going to perform [Bash
gymnastics](https://gist.github.com/magnetikonline/cf40e813b7bb87e94df955d0c80cd310)
to install the CLI.

This script gives people a clean way of installing the AWS CLI without
relying on package managers. This is ideal for endpoint device admins
who don't use Homebrew for fleet-based installations or people who
prefer to install their packages without package managers.
