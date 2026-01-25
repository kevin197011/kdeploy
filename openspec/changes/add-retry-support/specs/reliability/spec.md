## ADDED Requirements

### Requirement: Retry configuration and precedence
The system SHALL support configurable retry behavior for task execution steps.

#### Scenario: Default is no retry
- **WHEN** a user runs `kdeploy execute ...` without specifying retries
- **THEN** the system does not retry failed steps

#### Scenario: CLI overrides config file
- **WHEN** `.kdeploy.yml` sets `retries: 1` and the user passes `--retries 3`
- **THEN** the effective retry count is `3`

#### Scenario: Config file overrides code default
- **WHEN** `.kdeploy.yml` sets `retry_delay: 2`
- **THEN** the effective retry delay is `2` seconds unless CLI overrides it

### Requirement: Retry applies to network-related operations
The system SHALL apply retries to network-related operations including SSH execution and file transfer operations.

#### Scenario: Retry applies to run (SSH)
- **WHEN** a `run` step fails with a network-related error
- **THEN** the system retries up to the configured count with the configured delay

#### Scenario: Retry applies to upload/sync/template
- **WHEN** an `upload`, `upload_template`, or `sync` step fails with a network-related error
- **THEN** the system retries up to the configured count with the configured delay

