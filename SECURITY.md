# Security policy

Notchest runs locally on your Mac and touches sensitive surfaces: optional
clipboard history, local CLI logs, macOS permissions, and optional local
services. Reports are welcome and handled seriously.

## Reporting a vulnerability

Please report privately — do not open a public issue for security problems:

1. Open GitHub's private report at
   `https://github.com/H0777/Notchest/security/advisories/new`, or
2. Use **Report a vulnerability** in the repository's Security tab.

Include what you found, how to reproduce it, affected versions, and any
impact you assessed. You will hear back within a few days.

## Scope

- The Notchest app, helper, site sources, and CI workflows in this repository.
- Third-party services are only relevant through how Notchest handles their
  data locally.

## Expectations

- The project is not notarized yet; unsigned builds are expected to trigger a
  one-time Gatekeeper confirmation. Reports about that prompt are not
  vulnerabilities.
- Please avoid automated scanning noise without a demonstrated impact.
