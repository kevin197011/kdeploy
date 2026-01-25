## ADDED Requirements

### Requirement: JSON output for execute
The system SHALL support emitting machine-readable JSON output for `execute`.

#### Scenario: JSON output contains per-host results
- **WHEN** a user runs `kdeploy execute deploy.rb deploy_web --format json`
- **THEN** the command prints valid JSON
- **AND THEN** the JSON includes per-host `status`

#### Scenario: JSON output contains per-step data
- **WHEN** a task includes `run/upload/upload_template/sync` steps
- **THEN** the JSON includes an ordered list of steps with `type` and `duration` per step

### Requirement: JSON output for dry-run
The system SHALL support emitting JSON for dry-run planned steps without executing network side-effects.

#### Scenario: dry-run JSON contains planned steps and no network execution
- **WHEN** a user runs `kdeploy execute deploy.rb deploy_web --dry-run --format json`
- **THEN** the command prints valid JSON including planned steps per host
- **AND THEN** the system does not open SSH/SCP connections

