## ADDED Requirements
### Requirement: Optional Fast Sync Path
The system SHALL allow an optional fast sync mode (e.g., rsync or parallel upload) while preserving the existing default behavior.

#### Scenario: Fast sync enabled
- **WHEN** fast sync is enabled in configuration
- **THEN** directory synchronization uses the fast sync path
