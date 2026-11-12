# Security Policy

## Supported versions

| Version | Supported |
| ------- | --------- |
| 1.4.x   | Yes       |
| 1.3.x   | Best-effort |
| < 1.3   | Best-effort only |

## Reporting a vulnerability

Please open a [GitHub Security Advisory](https://github.com/kevin197011/kdeploy/security/advisories/new)
or email the maintainer listed in the gemspec. Do **not** file a public issue for
unfixed vulnerabilities that could lead to remote code execution or credential theft.

We aim to acknowledge reports within 7 days.

## Important defaults

Kdeploy defaults `verify_host_key` to `accept_new` (first-seen host keys are
recorded). For locked-down fleets prefer `always`. Use `never` only on ephemeral
lab hosts:

```yaml
verify_host_key: accept_new   # default
# verify_host_key: always
# verify_host_key: never      # labs only
```

Also prefer SSH keys and NOPASSWD sudo over embedding `password` / `sudo_password`
in task files. Treat deploy task files as secrets if they contain credentials.

## Scope

Kdeploy executes operator-supplied shell over SSH. Malicious task files are out of
scope; protect who can edit and run your deploy definitions.
