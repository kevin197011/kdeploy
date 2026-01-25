## ADDED Requirements

### Requirement: Banner suppression
The system SHALL support a CLI option to suppress printing the banner for automation-friendly output.

#### Scenario: execute without banner
- **WHEN** a user runs `kdeploy execute deploy.rb deploy_web --no-banner`
- **THEN** the banner is not printed
- **AND THEN** the command behavior is otherwise unchanged

### Requirement: Output format selection
The system SHALL support selecting an output format for `execute`.

#### Scenario: default output format
- **WHEN** a user runs `kdeploy execute deploy.rb deploy_web` without specifying a format
- **THEN** the output format is human-readable text

