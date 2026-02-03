## ADDED Requirements
### Requirement: Task Result Reporting
The CLI SHALL report host execution failures with sufficient context, including the failed command and exit status when available.

#### Scenario: Command fails with nonzero exit
- **WHEN** a run step exits with a nonzero status
- **THEN** the CLI output includes the command and exit status
