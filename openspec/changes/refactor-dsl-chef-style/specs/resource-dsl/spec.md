## ADDED Requirements

### Requirement: package resource
The system SHALL provide a `package` resource that installs system packages. The resource SHALL compile to an equivalent `run` command (e.g., `apt-get install -y` for apt platform).

#### Scenario: Install package with default action
- **WHEN** a task block calls `package "nginx"`
- **THEN** the system appends a run step equivalent to `apt-get update && apt-get install -y nginx` (or platform-appropriate command)

#### Scenario: Install package with version
- **WHEN** a task block calls `package "nginx", version: "1.18"`
- **THEN** the system appends a run step that installs the specified version when the platform supports it

#### Scenario: Install package with platform override
- **WHEN** a task block calls `package "nginx", platform: :yum`
- **THEN** the system generates a yum-based install command (e.g., `yum install -y nginx`)

### Requirement: service resource
The system SHALL provide a `service` resource that manages systemd services. The resource SHALL compile to equivalent `run` commands (e.g., `systemctl start`, `systemctl enable`).

#### Scenario: Start and enable service
- **WHEN** a task block calls `service "nginx", action: [:enable, :start]`
- **THEN** the system appends run steps equivalent to `systemctl enable nginx` and `systemctl start nginx`

#### Scenario: Restart service
- **WHEN** a task block calls `service "nginx", action: :restart`
- **THEN** the system appends a run step equivalent to `systemctl restart nginx`

#### Scenario: Stop and disable service
- **WHEN** a task block calls `service "nginx", action: [:stop, :disable]`
- **THEN** the system appends run steps equivalent to `systemctl stop nginx` and `systemctl disable nginx`

### Requirement: template resource
The system SHALL provide a `template` resource that renders an ERB template and uploads it to a remote path. The resource SHALL compile to an equivalent `upload_template` step.

#### Scenario: Deploy template with variables
- **WHEN** a task block calls `template "/etc/nginx/nginx.conf" do source "./config/nginx.conf.erb"; variables(port: 3000); end`
- **THEN** the system appends an upload_template step with the given source, destination, and variables

#### Scenario: Template with block syntax
- **WHEN** a task block calls `template "/etc/app.conf" do source "./config/app.erb"; variables(domain: "example.com"); end`
- **THEN** the system appends an upload_template step preserving the variables hash

### Requirement: file resource
The system SHALL provide a `file` resource that uploads a local file to a remote path. The resource SHALL compile to an equivalent `upload` step.

#### Scenario: Upload file
- **WHEN** a task block calls `file "/etc/nginx/conf.d/app.conf", source: "./config/app.conf"`
- **THEN** the system appends an upload step from the source path to the destination path

### Requirement: directory resource
The system SHALL provide a `directory` resource that ensures a remote directory exists. The resource SHALL compile to an equivalent `run` command (e.g., `mkdir -p`).

#### Scenario: Create directory
- **WHEN** a task block calls `directory "/etc/nginx/conf.d"`
- **THEN** the system appends a run step equivalent to `mkdir -p /etc/nginx/conf.d`

#### Scenario: Create directory with mode
- **WHEN** a task block calls `directory "/var/log/app", mode: "0755"`
- **THEN** the system appends run steps to create the directory and set the specified mode when supported

### Requirement: Resource and primitive coexistence
The system SHALL allow task blocks to mix resource DSL methods with primitive commands (`run`, `upload`, `upload_template`, `sync`) in any order.

#### Scenario: Mixed resource and primitive
- **WHEN** a task block calls `package "nginx"`, then `run "nginx -t"`, then `service "nginx", action: :restart`
- **THEN** the task produces an ordered command list reflecting the call order, with resources compiled to primitives
