## ADDED Requirements

### Requirement: Run state machine
The system SHALL track each run using a state machine with clearly defined transitions.

#### Scenario: Successful run
- **WHEN** a run completes with no host failures
- **THEN** the run transitions to `succeeded`

#### Scenario: Failed run
- **WHEN** any host result is failed
- **THEN** the run transitions to `failed`

### Requirement: Persisted run records
The system SHALL persist run metadata and per-host results for audit and troubleshooting.

#### Scenario: Persist run and per-host results
- **WHEN** a run is executed
- **THEN** the system stores start/end timestamps and per-host status and errors

### Requirement: Execution parameter mapping
The system SHALL map run parameters to the underlying kdeploy engine execution options.

#### Scenario: Map limit/parallel/retries
- **WHEN** a run is created with `limit`, `parallel`, and `retries`
- **THEN** the execution uses the corresponding kdeploy options for host filtering and concurrency and retry behavior

### Requirement: Logs and output formats
The system SHALL store and expose run output in both human-readable text and machine-readable JSON formats.

#### Scenario: Store text and JSON outputs
- **WHEN** a run is executed
- **THEN** the system stores both text output and JSON output for later retrieval (as configured)

