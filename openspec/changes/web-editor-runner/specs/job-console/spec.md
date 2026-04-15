## ADDED Requirements
### Requirement: Single-page Editor
The Web Console SHALL provide a single-page editor with Ruby syntax highlighting and a Run action.

#### Scenario: Edit deploy.rb
- **WHEN** a user opens the console
- **THEN** they see an editor with the current deploy.rb contents

#### Scenario: Run from editor
- **WHEN** a user clicks Run
- **THEN** execution starts asynchronously and output is displayed in a modal
