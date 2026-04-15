# Change: Web UI Username/Password Login with Token-only API

## Why
当前 Web Console 使用统一 token 保护 UI 和 API，不符合“账号密码登录 + token 仅用于 API”的使用需求，需要分离 UI 登录与 API 调用认证。

## What Changes
- Web UI: 使用账号密码登录并建立 session。
- API: 仍使用 Bearer token 认证。
- Auth middleware 区分 UI 与 API 访问路径。

## Impact
- Affected specs: job-console, job-api
- Affected code:
  - web/lib/auth.rb
  - web/app/app.rb
  - web/views/*
  - web/README.md
