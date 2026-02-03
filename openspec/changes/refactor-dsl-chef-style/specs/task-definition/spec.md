## MODIFIED Requirements

### Requirement: Task command collection
The system SHALL collect ordered command steps defined inside a task block using DSL commands: `run`, `upload`, `upload_template`, `sync`, and resource DSL methods (`package`, `service`, `template`, `file`, `directory`). Resource methods SHALL compile to equivalent primitive commands before execution.

#### Scenario: Task collects run and upload steps
- **WHEN** a task block calls `run "echo hello"` and `upload "./a", "/tmp/a"`
- **THEN** the task produces an ordered command list preserving the call order

#### Scenario: Task collects resource steps
- **WHEN** a task block calls `package "nginx"` and `service "nginx", action: [:enable, :start]`
- **THEN** the task produces an ordered command list where each resource compiles to one or more run/upload commands, preserving the call order
