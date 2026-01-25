## ADDED Requirements

### Requirement: Cancel semantics
The system SHALL support cancel semantics for runs.

#### Scenario: Cancelled run does not execute
- **WHEN** a run is cancelled while queued
- **THEN** the worker does not execute the run and the run remains `cancelled`

#### Scenario: Best-effort cancel for running run
- **WHEN** a run is cancelled while running
- **THEN** the system records a cancellation request and the run transitions to `cancelled` or `failed` based on implementation constraints

### Requirement: Rerun semantics
The system SHALL support creating a new run by copying parameters from an existing run.

#### Scenario: Rerun copies parameters
- **WHEN** a rerun is created
- **THEN** the new run uses the same job/task/limit/parallel/retries/format parameters as the source run

### Requirement: Resource limits
The system SHALL enforce maximum queued and maximum running runs.

#### Scenario: Enforce max running
- **WHEN** the number of running runs equals the configured maximum
- **THEN** new runs remain queued or are rejected (as defined by the API contract)

