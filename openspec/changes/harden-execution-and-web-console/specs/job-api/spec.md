## ADDED Requirements
### Requirement: Task File Path Restrictions
The Web API SHALL restrict task file execution to a configured base directory.

#### Scenario: Task file outside base directory
- **WHEN** a job attempts to execute a task file outside the configured base directory
- **THEN** the system rejects the request
