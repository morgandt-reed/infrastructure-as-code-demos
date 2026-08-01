# ADR-0001: Bootstrap is a separate phase, before Terraform runs

- **Status**: Proposed. This repository does not implement a bootstrap phase; see
  "What this repository actually does".
- **Date**: 2026-08-01

## Context

Terraform configurations in template repositories start at the point where
Terraform already works: a state backend exists, an identity with permission to
create resources exists, the provider APIs are enabled. Getting there is a
distinct phase — call it Phase 0 — with a chicken-and-egg problem at its centre.
The state bucket cannot be managed by the state stored in it, and the identity
Terraform uses cannot be created by Terraform running as that identity.

Four decisions live in that phase, each with a defensible answer worth writing
down rather than rediscovering.

**API enablement.** On GCP nothing works until the relevant services are enabled
on the project, and the failure is a permission error naming the API rather than
the missing enablement. It belongs in a script, run once, with the list checked
in — `compute`, `iam`, `iamcredentials`, `cloudresourcemanager`, `storage`,
`secretmanager`, plus one per service in the stack. AWS has no direct equivalent,
which is why the phase is easy to forget when moving from AWS to GCP.

**Two candidate IAM role sets.** The broad set is one or two wide roles — project
editor plus a security or IAM admin role — and it works on the first attempt. The
least-privilege set enumerates one admin role per service the configuration
touches. The broad set is a standing privilege-escalation path attached to a CI
identity, and it never tells you what the configuration actually needs, so that
question stays unanswerable forever. Start from the enumerated set, add roles when
a plan fails, and the resulting list documents the blast radius.

**A versioned state bucket with IAM scoped to one identity.** Versioning is the
only recovery path from a corrupted or truncated state write, and costs
effectively nothing at state-file sizes. The IAM scope matters because state is
not metadata: it holds resource attributes and, wherever a resource generates a
credential, that credential in plaintext. Read access to the bucket is read access
to those values, so it goes to the provisioning identity and nobody else.

**Federated identity instead of service-account keys.** The bootstrap script's
last step is traditionally to create a key file and tell the operator to paste it
into a CI secret, then delete the local copy — the moment the model turns into
secret custody. Workload identity federation with an attribute condition on the
calling repository (`assertion.repository == '<org>/<repo>'`, or an
environment-scoped subject) replaces it. Same decision as ADR-0001 in
`cicd-pipeline-templates`, seen from the cloud side rather than the pipeline side.

## Decision

Bootstrap is an explicit, documented, one-time phase that precedes any `terraform
init`, and its four outputs are: enabled APIs, a provisioning identity holding an
enumerated least-privilege role set, a versioned state bucket whose IAM names only
that identity, and a federated trust relationship with an attribute condition —
not a key.

## What this repository actually does

Verified against the configuration as committed, and the honest answer is that it
sidesteps the problem rather than solving it:

- `examples/complete-setup/versions.tf` ships with **local state**. The S3 backend
  block, with `encrypt = true` and a `dynamodb_table` for locking, is present but
  commented out, with a note that it should be filled in for anything shared.
- CI runs `terraform init -backend=false` in `terraform-validate.yml`, so no
  backend is ever initialised and the state question never arises in the pipeline.
- There is no bootstrap script, no state-bucket configuration, and no identity or
  federation setup anywhere in the repository. Applying the example requires an
  AWS CLI already configured by some means this repository does not describe.
- The modules do apply least-privilege reasoning *within* the resources they
  create: `modules/docker-host` attaches `CloudWatchAgentServerPolicy` and
  `AmazonSSMManagedInstanceCore` to an instance profile rather than a broad role,
  and `modules/databricks-workspace-prerequisites` builds a cross-account role
  with an `sts:ExternalId` condition and an inline scoped policy.

Closing the gap means a `bootstrap/` configuration creating the state backend and
the provisioning identity, applied with a human's own credentials, plus a CI job
that initialises the real backend via OIDC. The README's Next Steps already name
the second half of that.

## Consequences

- Phase 0 is manual and run by a human with elevated rights. That is correct — it
  is the trust anchor — but it must be documented, because an undocumented manual
  step is what breaks when the person who ran it changes team.
- The enumerated role set will be incomplete on the first run. That is the
  intended behaviour: each failure adds one role and one line of documentation.
- Bootstrap state has nowhere to live. Keeping it local and committing the
  resulting resource identifiers is acceptable for a one-time phase; migrating it
  into the bucket it created is a nice-to-have.
- Federation must be configured per repository and, with environment-scoped
  subjects, per environment. More setup than pasting one key, and it is the setup
  that makes the key unnecessary.

## Alternatives considered

- **Fold bootstrap into the main configuration with a local backend on first run,
  then migrate state.** Works, and leaves the configuration in a state a fresh
  clone cannot reproduce. Rejected for a repository meant to be read.
- **ClickOps the bootstrap in the console.** Fast, unauditable, unrepeatable
  across environments.
- **A managed remote backend that provisions itself.** Removes the state-bucket
  half of the problem and replaces it with a vendor relationship and a second
  identity boundary. Reasonable for a team; too large an assumption here.
