# ADR-0002: Prefer workload identity over any stored credential

- **Status**: Accepted, partially implemented. See "What this repository actually
  does".
- **Date**: 2026-08-01

## Context

Infrastructure code is where credentials get created. A module that provisions a
database generates an administrator password. A module that provisions a host
takes an SSH key pair name. A module that integrates a third-party service is
handed an access key. Each becomes a value to be stored, handed to something,
rotated on a schedule, and revoked when someone leaves.

The usual response is to automate that lifecycle: a secrets manager, a rotation
function, an expiry policy, an alert for when rotation fails. All real
engineering, and often the wrong engineering, because it accepts a requirement
that could have been removed.

Every major cloud platform now offers an identity a workload carries by virtue of
running where it runs — an instance profile, a managed identity, a service account
attached to a pod or function. The platform mints a short-lived token, refreshes
it before expiry, and the workload never holds a durable secret. Where the target
service accepts that identity, the credential does not exist: nothing to store,
nothing to rotate, nothing to leak, nothing to revoke beyond a role binding.

The database case makes the difference concrete, and it generalises. With
platform-native identity authentication, the connection string is:

```
Server=<host>;Database=<db>;Authentication=<platform managed identity>;Encrypt=True
```

There is no confidential material in that string. It can live in versioned
configuration next to the rest of the application settings; its classification is
internal, not secret. The workload's identity token refreshes itself on the
platform's schedule, so there is no password rotation to design, no grace period
to tune, no dual-credential window to coordinate, no alert to write for a rotation
that failed at 3am. Compare the alternative: a generated password in a vault, an
expiry attribute, a rotation function with its own identity and permission to
reset the database credential, a grace period during which both values must work,
and a runbook for when the application caches the old one past that window. All of
it work that exists because the password exists.

The stance, stated plainly: **eliminating a requirement beats automating it.**
Automating custody is a good second answer for when the first is unavailable.
Knowing which situation you are in — and pushing back when a requirement arrives
as "automate the secrets" rather than "provision applications without manual
steps" — is the architect's call, and the point at which the design either sheds a
whole subsystem or acquires one.

## Decision

Modules in this repository default to platform-native identity for any access they
grant, and a stored credential is an explicitly configured departure from the
default rather than the path a caller gets by doing nothing. Where a credential
must exist, the module keeps the confidential material separate from the
non-confidential connection metadata, so that only the part that is genuinely
secret carries the cost of being secret.

## What this repository actually does

Verified against the modules as committed:

- **`modules/docker-host` eliminates SSH rather than securing it.** The instance
  profile attaches `AmazonSSMManagedInstanceCore`, so Session Manager provides
  shell access through the platform's own identity and audit path.
  `allowed_ssh_cidrs` defaults to `[]`, and the security group's SSH ingress is a
  `dynamic` block that renders zero times when the list is empty — so the default
  instance has no SSH rule at all, not an SSH rule with a narrow CIDR. The key
  pair is not the thing being protected; it is the thing being made unnecessary.
- **`modules/databricks-workspace-prerequisites` uses a cross-account role, not
  keys.** The trust policy is an `sts:AssumeRole` conditioned on an
  `sts:ExternalId`, with an inline scoped policy — the third-party integration
  pattern that carries no shared secret.
- **The elimination is incomplete, and the seam is visible.** `key_name` in
  `modules/docker-host` is a required variable with no default, so every caller
  must still name an EC2 key pair even when no SSH rule will be created. That is
  the module asking for a credential it does not use on the default path, and it
  should be optional.
- Nothing here provisions a database, so the connection-string case above is the
  reasoning this repository would apply, not something it demonstrates.

## Consequences

- Rotation, expiry and custody stop being problems to solve on the default path.
  The residual trust anchor is the role or binding itself: declarative, reviewable
  in a diff, revoked by deleting a line.
- Access becomes visible in infrastructure code rather than in a vault's access
  policy. Reviewing who can reach what is reading the repository.
- Identity-based access is harder to use from a laptop. Developers need a local
  credential-federation step, and tooling that assumed username/password may not
  support the platform's auth plugin at all. This is the most common practical
  objection and it is legitimate.

## Honest limits

- **Third-party SaaS that only accepts a static key.** Some providers offer
  nothing else. The credential exists; custody it properly (ADR-0002 in
  `cicd-pipeline-templates`) rather than pretending it can be designed away.
- **Legacy systems.** Databases and appliances with no directory integration, and
  anything running where the platform cannot attach an identity, fall back to a
  generated credential with real rotation.
- **Migration cost.** Getting an existing estate to identity-only is not a
  configuration change. Every consumer's connection code changes, directory groups
  have to be modelled and owned, and there is a long tail of batch jobs and vendor
  tools nobody can modify. Make identity the default for new workloads and migrate
  the rest on their own schedule, rather than blocking the default on the
  migration finishing.

## Alternatives considered

- **Generate credentials in Terraform and store them in a secrets manager.** The
  mainstream pattern. It works, it is auditable, and it commits you to operating
  the rotation subsystem forever.
- **Externally managed credentials injected at deploy time.** Moves custody out of
  infrastructure code without removing it, and splits the access story across two
  systems.
- **Certificate-based authentication.** A genuine middle ground where identity is
  unavailable: strong authentication with managed issuance and renewal, at the
  cost of a certificate lifecycle to operate.
