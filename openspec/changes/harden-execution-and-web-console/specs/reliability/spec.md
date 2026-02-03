## ADDED Requirements
### Requirement: Retry On Nonzero Exit
The system SHALL allow optional retries when a command exits with a nonzero status, controlled by configuration.

#### Scenario: Retry enabled for nonzero exit
- **WHEN** a command exits with status 1 and retry-on-nonzero is enabled
- **THEN** the system retries the command until retries are exhausted

#### Scenario: Retry disabled for nonzero exit
- **WHEN** a command exits with status 1 and retry-on-nonzero is disabled
- **THEN** the system fails the step without retrying
