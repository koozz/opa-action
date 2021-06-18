# Sample policy files

To test while developing and for illustrative purpose there is a policy that can
be applied to `Dockerfile`s and a policy for the GitHub workflows.

## docker.rego

Defined with the rego `package docker` and testable by specifying docker as the
namespace i.e. `conftest --namespace docker ...`.

## workflows.rego

Defined with the rego `package workflows` and testable by specifying workflows
as the namespace i.e. `conftest --namespace workflows ...`.
