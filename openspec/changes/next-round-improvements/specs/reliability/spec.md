## ADDED Requirements
### Requirement: Retry Policies by Step Type
The system SHALL allow configuring retries by step type and exit code.

#### Scenario: Retry only run steps
- **WHEN** retries are configured for run steps only
- **THEN** upload/sync steps are not retried
