## ADDED Requirements
### Requirement: Run History Filtering
The Web Job Console SHALL allow filtering run history by status and job name.

#### Scenario: Filter by status
- **WHEN** a user filters runs by status
- **THEN** only matching runs are displayed

#### Scenario: Filter by job name
- **WHEN** a user filters runs by job name
- **THEN** only matching runs are displayed

### Requirement: Run Detail Step Visibility
The Web Job Console SHALL display structured step output for each host in a run.

#### Scenario: View steps for a host
- **WHEN** a user opens a run detail
- **THEN** step output is shown per host with status and timing
