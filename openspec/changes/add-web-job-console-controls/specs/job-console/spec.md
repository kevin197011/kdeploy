## ADDED Requirements

### Requirement: Cancel and rerun controls
The system SHALL provide UI controls to cancel and rerun runs.

#### Scenario: Cancel from run detail
- **WHEN** an admin opens a run detail page for a queued run and clicks "Cancel"
- **THEN** the run transitions to `cancelled` and the UI reflects the updated status

#### Scenario: Rerun from run detail
- **WHEN** an admin clicks "Rerun" on a run detail page
- **THEN** a new run is created and the UI navigates to the new run detail

