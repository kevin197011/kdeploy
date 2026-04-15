## ADDED Requirements
### Requirement: Failure Output Context
The CLI SHALL include the failed command, exit status, and stderr (when available) in failure output.

#### Scenario: Command fails with nonzero exit
- **WHEN** a run step exits with a nonzero status
- **THEN** the CLI output includes command, exit status, and stderr
