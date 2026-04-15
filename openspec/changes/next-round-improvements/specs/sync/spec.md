## ADDED Requirements
### Requirement: Sync Parallelism
The system SHALL allow configuring parallelism for directory sync uploads.

#### Scenario: Parallel sync enabled
- **WHEN** sync parallelism is configured
- **THEN** uploads use the configured parallelism level

### Requirement: Fast Sync Reporting
The system SHALL report whether fast sync was used for a sync operation.

#### Scenario: Fast sync path used
- **WHEN** fast sync is enabled and used
- **THEN** the result indicates fast sync usage
