# OPA-action

OPA stands for **O**PA **P**ull-Request **A**ssessor and is a GitHub Action that
checks files against policies (configured in the same repo). It's using the
original OPA ([Open Policy Agent](https://www.openpolicyagent.org/)) through the
use of [Conftest](https://conftest.dev).

## Usage

Start using this OPA-action in three simple steps:

1. [Create your policies](#create-your-policies)
2. [Create a configuration](#create-a-configuration)
3. [Trigger GitHub Action](#trigger-github-action)

### Create your policies

Create a folder (i.e. `policies`) with your policy files written in the Rego
language. For sample policies, check out the
[Conftest examples](https://github.com/open-policy-agent/conftest/tree/master/examples)
or write your own using [Rego](https://www.openpolicyagent.org/docs/latest/policy-language/),
the OPA Policy Language.

### Create a configuration

Configure in either `.opa-action.yaml` or `.github/opa-action.yaml` where your
policy files can be found (`path`, the folder you created in the step before)
followed by pairs of files or filepatterns (`sources`) and the package/namespace
(`package`) the files should be tested against and optionally if this should not
fail the check (`no_fail`, default or absense means 'false' and will fail the
check on errors).

```yaml
---
path: policy
rego:
  - sources: "Dockerfile"
    package: "docker"
    no_fail: true
  - sources: ".github/workflows/*.yml"
    package: "workflows"
```

### Trigger GitHub Action

Add the GitHub Action to your workflows, either on its own as a separate
workflow or add it as an action between the code checkout and the rest of your
existing workflow.

```yaml
---
name: Policy check

on:
  pull_request:
    branches: 
      - main

jobs:
  policy-check:
    runs-on: ubuntu-latest
    steps:
      - name: Check out code
        uses: actions/checkout@v2
      - name: OPA Pull-Request Assessor
        uses: koozz/opa-action@latest
```

If your satisfied, follow best practices and pin the action to a specific
version.

## License

Apache License, Version 2.0
