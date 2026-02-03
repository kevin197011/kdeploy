## ADDED Requirements
### Requirement: JSON Output
The system SHALL include per-step error context in JSON output, including command and exit status when available.

#### Scenario: Step failure in JSON output
- **WHEN** a step fails during execution
- **THEN** the JSON output includes the step command and exit status
