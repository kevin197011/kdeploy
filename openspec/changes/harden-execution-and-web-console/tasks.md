## 1. Implementation
- [ ] 1.1 Add per-host execution timeout handling in Runner and ensure futures cannot block global collection
- [ ] 1.2 Extend command execution to support optional retry-on-nonzero-exit with configurable policy
- [ ] 1.3 Expand structured output to include command + exit status in JSON/text failure paths
- [ ] 1.4 Enforce JOB_CONSOLE_TOKEN requirement in Web Auth layer
- [ ] 1.5 Restrict task file paths for Web execution to a configured safe base directory
- [ ] 1.6 Update Web documentation for new security requirements
- [ ] 1.7 Add/adjust tests for new behavior
