## MODIFIED Requirements

### Requirement: Execute tasks from a task file
The system SHALL load a Ruby task file, resolve target hosts for each selected task, and execute task steps on the selected hosts in order. The Runner SHALL iterate over commands directly without grouping; no intermediate progress messages SHALL be printed during execution.

#### Scenario: Execute a single named task
- **WHEN** a user runs `kdeploy execute deploy.rb deploy_web`
- **THEN** only `deploy_web` is executed

#### Scenario: Execute all tasks in a file
- **WHEN** a user runs `kdeploy execute deploy.rb` without a task name
- **THEN** all tasks defined in the file are executed

#### Scenario: Commands executed in order without grouping
- **WHEN** a task defines steps A, B, C
- **THEN** the Runner executes A, then B, then C in sequence
- **AND THEN** no `[Progress: X/Y]` or `[Step X/Y]` messages are printed during execution
