## ADDED Requirements
### Requirement: Editor Save API
The Web API SHALL save editor content to a file under JOB_CONSOLE_TASK_BASE_DIR.

#### Scenario: Save deploy.rb
- **WHEN** a user saves the editor content
- **THEN** the content is persisted to the configured base directory
