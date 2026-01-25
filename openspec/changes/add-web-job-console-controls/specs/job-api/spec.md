## ADDED Requirements

### Requirement: Cancel and rerun APIs
The system SHALL provide APIs to cancel queued runs and create reruns.

#### Scenario: Cancel a queued run
- **WHEN** a client calls `POST /api/runs/:id/cancel` for a queued run
- **THEN** the run transitions to `cancelled`

#### Scenario: Rerun a previous run
- **WHEN** a client calls `POST /api/runs/:id/rerun`
- **THEN** the system creates a new run with the same execution parameters and returns its id

### Requirement: Queue and concurrency limits
The system SHALL enforce limits for queued and running runs to protect resources.

#### Scenario: Reject when queue limit exceeded
- **WHEN** the queued run count is at the configured limit
- **THEN** creating a new run is rejected with a 429 status

