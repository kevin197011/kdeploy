## ADDED Requirements

### Requirement: Host definition
The system SHALL allow users to define one or more hosts in a task file via a Ruby DSL.

#### Scenario: Define a host with SSH key
- **WHEN** a task file calls `host "web01", user: "ubuntu", ip: "10.0.0.1", key: "~/.ssh/id_rsa"`
- **THEN** the host named `web01` is registered and available for task targeting

#### Scenario: Define a host with password and custom port
- **WHEN** a task file calls `host "web02", user: "admin", ip: "10.0.0.2", password: "pw", port: 2222`
- **THEN** the host named `web02` is registered with authentication and port configuration

### Requirement: Role definition
The system SHALL allow users to assign a role name to a list of host names.

#### Scenario: Define a role for multiple hosts
- **WHEN** a task file calls `role :web, %w[web01 web02]`
- **THEN** tasks targeting `roles: :web` include `web01` and `web02`

### Requirement: Task definition and targeting
The system SHALL allow users to define tasks and target execution by explicit hosts (`on:`) and/or roles (`roles:`).

#### Scenario: Task targets a role
- **WHEN** a task is defined as `task :deploy, roles: :web do ... end`
- **THEN** the task targets only hosts associated with the `:web` role

#### Scenario: Task targets explicit hosts
- **WHEN** a task is defined as `task :maintenance, on: %w[web01] do ... end`
- **THEN** the task targets only `web01`

#### Scenario: Task without targets defaults to all hosts
- **WHEN** a task is defined without `roles:` and without `on:`
- **THEN** the task targets all defined hosts

### Requirement: Task command collection
The system SHALL collect ordered command steps defined inside a task block using DSL commands: `run`, `upload`, `upload_template`, and `sync`.

#### Scenario: Task collects run and upload steps
- **WHEN** a task block calls `run "echo hello"` and `upload "./a", "/tmp/a"`
- **THEN** the task produces an ordered command list preserving the call order

### Requirement: Modular task inclusion
The system SHALL allow users to split tasks across multiple Ruby files and include them from a main task file.

#### Scenario: Include a tasks file with role assignment
- **WHEN** a main task file calls `include_tasks "tasks/nginx.rb", roles: :web`
- **THEN** tasks newly defined in `tasks/nginx.rb` are assigned to `roles: :web` unless they already declare `roles:` or `on:`

#### Scenario: Included task files resolve relative paths from the caller file
- **WHEN** `include_tasks "tasks/nginx.rb"` is called from `deploy.rb`
- **THEN** the included file path is resolved relative to the directory containing `deploy.rb`

