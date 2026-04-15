## ADDED Requirements
### Requirement: UI Login
The Web Job Console SHALL require username/password login for UI access.

#### Scenario: Unauthenticated UI request
- **WHEN** a user visits the UI without a valid session
- **THEN** the system redirects to the login page

#### Scenario: Successful login
- **WHEN** valid credentials are submitted
- **THEN** a session is created and UI access is granted
