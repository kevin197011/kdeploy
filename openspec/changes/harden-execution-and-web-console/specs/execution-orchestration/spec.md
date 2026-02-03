## ADDED Requirements
### Requirement: Concurrent Host Execution
The system SHALL execute tasks across multiple hosts concurrently using a bounded thread pool and SHALL collect results for every target host without blocking on a single host indefinitely.

#### Scenario: One host hangs
- **WHEN** a host exceeds the configured execution timeout
- **THEN** that host is marked failed with a timeout error
- **AND** results for other hosts are still collected and reported
