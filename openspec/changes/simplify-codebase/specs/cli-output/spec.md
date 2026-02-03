## MODIFIED Requirements

### Requirement: Output format selection
The system SHALL support selecting an output format for `execute`. The text output SHALL display all steps for each host in order, without deduplication.

#### Scenario: default output format
- **WHEN** a user runs `kdeploy execute deploy.rb deploy_web` without specifying a format
- **THEN** the output format is human-readable text

#### Scenario: All steps displayed in order
- **WHEN** a task produces multiple steps (run, upload, template, sync) per host
- **THEN** each step is displayed in execution order
- **AND THEN** steps are not deduplicated (identical steps appear as many times as executed)
