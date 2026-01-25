## ADDED Requirements

### Requirement: Job CRUD API
The system SHALL provide an HTTP API to create, update, list, and fetch job definitions.

#### Scenario: Create a job
- **WHEN** a client sends a request to create a job with a task file reference and default variables
- **THEN** the system persists the job and returns a job id

#### Scenario: List jobs
- **WHEN** a client requests the job list
- **THEN** the system returns a paginated list of jobs including name and last updated time

### Requirement: Run execution API
The system SHALL provide an HTTP API to start a run from a job definition and query run status and results.

#### Scenario: Start a run
- **WHEN** a client starts a run with `task_name`, `limit`, `parallel`, `retries`, and `format`
- **THEN** the system creates a run record and transitions it to `queued` (or `running` for synchronous MVP)

#### Scenario: Query run status
- **WHEN** a client queries a run by id
- **THEN** the system returns run status and timestamps

#### Scenario: Fetch run results
- **WHEN** a client requests run results
- **THEN** the system returns per-host status, steps, and errors

### Requirement: Authentication (MVP)
The system SHALL protect job and run APIs with an authentication mechanism suitable for an admin console.

#### Scenario: Unauthorized request is rejected
- **WHEN** a request is made without valid credentials
- **THEN** the system responds with an unauthorized status

