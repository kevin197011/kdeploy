## ADDED Requirements
### Requirement: Step-level Timeout
The system SHALL allow configuring a timeout for individual execution steps.

#### Scenario: Step timeout exceeded
- **WHEN** a step exceeds the configured timeout
- **THEN** the step is marked failed with a timeout error
