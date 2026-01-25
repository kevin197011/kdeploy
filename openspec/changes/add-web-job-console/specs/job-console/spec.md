## ADDED Requirements

### Requirement: Job management UI
The system SHALL provide a web UI for admins to manage jobs.

#### Scenario: Create or edit a job in the UI
- **WHEN** an admin opens the job creation page and saves a job definition
- **THEN** the job is persisted and appears in the job list

### Requirement: Run management UI
The system SHALL provide a web UI to start runs and view run history and details.

#### Scenario: Start a run from the UI
- **WHEN** an admin selects a job and clicks "Run" with execution parameters
- **THEN** a new run is created and shown in the run list

#### Scenario: View run details
- **WHEN** an admin opens a run detail page
- **THEN** the UI shows overall run status and per-host results including steps and errors

