## ADDED Requirements

### Requirement: Configuration loading and precedence
The system SHALL load configuration from `.kdeploy.yml` by searching from the current working directory upward, and apply precedence rules for runtime options.

#### Scenario: Configuration file discovery
- **WHEN** a user runs `kdeploy execute ...` from a nested directory
- **THEN** the system searches parent directories until it finds `.kdeploy.yml` or reaches the filesystem root

#### Scenario: Option precedence
- **WHEN** `.kdeploy.yml` sets `parallel: 5` and the user passes `--parallel 10`
- **THEN** the effective parallelism is `10`

### Requirement: Execute tasks from a task file
The system SHALL load a Ruby task file, resolve target hosts for each selected task, and execute the task steps on the selected hosts.

#### Scenario: Execute a single named task
- **WHEN** a user runs `kdeploy execute deploy.rb deploy_web`
- **THEN** only `deploy_web` is executed

#### Scenario: Execute all tasks in a file
- **WHEN** a user runs `kdeploy execute deploy.rb` without a task name
- **THEN** all tasks defined in the file are executed

### Requirement: Limit execution to a host subset
The system SHALL support limiting execution to a subset of the task's target hosts via a CLI option.

#### Scenario: Limit by host names
- **WHEN** a user runs `kdeploy execute deploy.rb deploy_web --limit web01,web02`
- **THEN** only the listed hosts are executed for `deploy_web`

### Requirement: Dry-run mode
The system SHALL support a dry-run mode that shows the planned steps per host without performing network side-effects.

#### Scenario: Dry-run prints planned steps
- **WHEN** a user runs `kdeploy execute deploy.rb deploy_web --dry-run`
- **THEN** the system prints the planned `run/upload/template/sync` steps per host
- **AND THEN** the system does not open SSH/SCP connections

### Requirement: Debug mode output
The system SHALL support a debug mode that prints command stdout/stderr for `run` steps to assist troubleshooting.

#### Scenario: Debug prints stdout and stderr
- **WHEN** a user runs with `--debug` and a `run` step produces stdout and stderr
- **THEN** both streams are included in the output with a clear visual distinction

### Requirement: Directory sync behavior
The system SHALL support directory synchronization with ignore/exclude patterns and an optional delete mode.

#### Scenario: Sync respects ignore and exclude patterns
- **WHEN** a task step calls `sync "./app", "/var/www/app", ignore: ["*.log"], exclude: ["node_modules"]`
- **THEN** matching files/directories are not uploaded

#### Scenario: Sync delete removes remote extra files
- **WHEN** a task step calls `sync "./app", "/var/www/app", delete: true`
- **THEN** remote files not present in the local source are removed (subject to ignore/exclude filtering)

### Requirement: Failure handling and exit status
The system SHALL report failures with actionable context and exit with a non-zero status code when any executed host fails.

#### Scenario: Failure includes host and task context
- **WHEN** a `run` step fails on host `web01` during task `deploy_web`
- **THEN** the output includes the host name and task name alongside the error message

#### Scenario: Non-zero exit on failure
- **WHEN** any executed host result is `failed`
- **THEN** the CLI process exits with a non-zero status code

