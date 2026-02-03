## ADDED Requirements
### Requirement: Web Console Authentication
The Web Job Console SHALL require a bearer token when serving UI or API requests.

#### Scenario: Missing token
- **WHEN** a request is made without `Authorization: Bearer <token>`
- **THEN** the system responds with 401
