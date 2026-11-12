# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.4.1] - 2026-11-12

### Added

- `--report PATH` JSON execution report (`version`, `generated_at`, per-task hosts/steps)
- `--tags` task filter; `task ..., tags:`
- `vars` / `--extra-vars` with `%{name}` interpolation in steps
- `wait_port` / `wait_http` readiness steps (local probes)
- `on_failure { ... }` cleanup steps after a failed host step
- CI: Ruby 3.1/3.2/3.3 matrix; lab workflow on `docker/lab` / `lib` PRs

### Changed

- Default `verify_host_key` is `accept_new` (was `never`)
- Task plans are `{ commands:, on_failure: }` via per-invocation `TaskContext` (parallel-safe)

### Fixed

- Host timeout clock / abort path; sudo multi-line packing; inventory warnings (carry-over from 1.3.5+)

## [1.3.5] - 2026-11-12

### Added

- Open-source packaging: `LICENSE`, `CHANGELOG.md`, `SECURITY.md`
- CI: RSpec + RuboCop before RubyGems publish; weekly Docker lab workflow
- Safer timeout handling (`Executor#abort!`), sudo password hardening, inventory warnings

### Changed

- Rakefile default task is `spec` (no longer auto bump/push)

### Fixed

- Missing SSH exit status treated as failure
- Auth / argument errors no longer retried as transport failures
- Sudo upload paths escaped; inventory cleared between `execute` loads
- Host timeout clock starts when work is scheduled

## [1.3.0] - 2026-07-07

### Added

- `docker/lab` multi-distro Compose integration lab

## [1.2.0] - 2026-07-07

### Changed

- Project focused on CLI gem (Web Job Console removed)

## [1.1.0] - 2026-07-07

### Fixed

- Exit code 1 when no hosts match
- Config load from task directory; `KDEPLOY_*` env overrides

## [1.0.0] - 2026-07-07

### Added

- Initial public CLI: DSL, Runner, SSH/SCP sync, dry-run, JSON output

[Unreleased]: https://github.com/kevin197011/kdeploy/compare/v1.4.1...HEAD
[1.4.1]: https://github.com/kevin197011/kdeploy/compare/v1.3.5...v1.4.1
[1.3.5]: https://github.com/kevin197011/kdeploy/compare/v1.3.4...v1.3.5
[1.3.0]: https://github.com/kevin197011/kdeploy/releases/tag/v1.3.0
[1.2.0]: https://github.com/kevin197011/kdeploy/releases/tag/v1.2.0
[1.1.0]: https://github.com/kevin197011/kdeploy/releases/tag/v1.1.0
[1.0.0]: https://github.com/kevin197011/kdeploy/releases/tag/v1.0.0
