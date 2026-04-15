## ADDED Requirements
### Requirement: Stable JSON Step Schema
The system SHALL emit a stable JSON schema for steps, including `stdout`, `stderr`, `exit_status`, and `command` when available.

#### Scenario: Step output is serialized
- **WHEN** a run step completes
- **THEN** the JSON output includes `stdout`, `stderr`, and `exit_status` fields
