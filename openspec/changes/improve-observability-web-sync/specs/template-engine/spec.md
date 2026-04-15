## ADDED Requirements
### Requirement: Template Variable Validation
The system SHALL provide a clear error message listing missing variables required by a template.

#### Scenario: Missing template variables
- **WHEN** a template references a variable that is not provided
- **THEN** the error message lists missing variable names
