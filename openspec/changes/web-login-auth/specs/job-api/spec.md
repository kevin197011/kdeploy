## ADDED Requirements
### Requirement: API Token Authentication
The Web API SHALL require a Bearer token for all API requests.

#### Scenario: Missing token
- **WHEN** an API request is made without a valid Bearer token
- **THEN** the system responds with 401
