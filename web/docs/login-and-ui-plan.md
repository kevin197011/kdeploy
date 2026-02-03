# 后台执行界面 · 认证登录与 UI 规划

目标：在现有 Web Job Console 上增加**登录页**与 **Session 认证**，整体风格**简洁、优雅**，不引入新框架。

---

## 1. 认证方案

### 1.1 现状

- 已支持 `JOB_CONSOLE_TOKEN`：设置后，所有请求需带 `Authorization: Bearer <token>`，否则 401。
- 无登录页：浏览器访问直接返回 `unauthorized`，体验差。

### 1.2 目标

- **Token 登录页**：用户打开任意受保护页面时，未登录则跳转到 `/login`；在登录页输入与 `JOB_CONSOLE_TOKEN` 相同的 Token，提交后写入 Session，再跳回工作台。
- **Session 优先**：已登录（Session 有效）的请求不再要求 Bearer 头；API 仍支持 Bearer，便于脚本调用。
- **登出**：提供 `/logout`，清空 Session 后跳转回 `/login`。

### 1.3 行为约定

| 条件 | 行为 |
|------|------|
| 未设置 `JOB_CONSOLE_TOKEN` | 与现有一致：不做鉴权，所有人可访问（开发便利）。 |
| 已设置 `JOB_CONSOLE_TOKEN` | 未登录访问 `/`、`/jobs`、`/runs` 等 → 302 `/login`；未登录访问 `/api/*` → 401 JSON。 |
| 白名单路径（始终不鉴权） | `GET /login`、`POST /login`、静态资源（若有）。 |
| 登录成功 | Session 中标记已认证（如 `session[:authenticated] = true`），302 `/jobs`。 |
| 登出 | `GET /logout` 清空 Session，302 `/login`。 |

---

## 2. 登录页 UI（简洁优雅）

### 2.1 布局与结构

- **单页单卡**：整页居中一张卡片，内含标题、一个输入框、一个按钮。
- **无多余装饰**：无 Logo 图、无副标题、无「记住我」等，减少干扰。

### 2.2 视觉规范

| 元素 | 建议 |
|------|------|
| 背景 | 浅灰 `#f5f5f5` 或 `#f8fafc`，与现有 console 风格一致。 |
| 卡片 | 白底 `#ffffff`，圆角 8px，轻微阴影 `0 1px 3px rgba(0,0,0,0.08)`，最大宽度 360px，水平居中。 |
| 标题 | 单行「Kdeploy」或「登录」，字号 1.25rem，字重 600，颜色 `#0f172a`。 |
| 输入框 | 占满卡片内宽，padding 10px 12px，边框 `1px solid #e2e8f0`，圆角 6px；placeholder「Token」。 |
| 按钮 | 主色 `#0366d6`（与现有链接色一致），白字，padding 10px 16px，圆角 6px，无边框；hover 略深。 |
| 字体 | 沿用现有 `ui-sans-serif, system-ui, -apple-system`。 |
| 错误提示 | 仅当 Token 错误时在卡片内显示一行小字「Token 无效」，颜色 `#b91c1c` 或 `#dc2626`。 |

### 2.3 交互

- 表单：`POST /login`，body 为 `token=xxx`（或 JSON `{"token":"xxx"}` 二选一，建议 form 简单）。
- 登录成功：302 `/jobs`。
- 登录失败：仍停留在 `/login`，显示「Token 无效」，不跳转。

### 2.4 无障碍与安全

- 输入框 `type="password"` 或 `autocomplete="one-time-code"`，避免浏览器把 Token 当普通密码存。
- 按钮可设 `type="submit"`，支持回车提交。
- 不记录 Token 到前端存储（仅 Session Cookie）。

---

## 3. 执行界面（现有页面）微调

### 3.1 导航

- 在现有 layout 顶部「Jobs | Runs」右侧增加「登出」链接，指向 `GET /logout`。
- 样式与现有链接一致（颜色、无下划线），不抢眼。

### 3.2 未登录访问

- 由 Auth 中间件或 `before` 钩子统一处理：若需认证且未登录，HTML 请求 302 `/login`，API 请求 401。
- 登录后可照常使用 Jobs、Runs、执行、取消、重跑等，逻辑不变。

---

## 4. 技术实现要点

### 4.1 Session

- 在 `config.ru` 或 App 中启用 `Rack::Session::Cookie`，例如：
  - `secret`: 从 `ENV['SESSION_SECRET']` 读取，未设置则用 `SecureRandom.hex(32)`（仅开发）。
  - `same_site: :lax`，`httponly: true`，提高安全性。

### 4.2 Auth 中间件（lib/auth.rb）

- 若未设置 `JOB_CONSOLE_TOKEN`：直接 `@app.call(env)`，与现在一致。
- 若已设置：
  - 白名单：`GET /login`、`POST /login`、`GET /logout` → 直接放行。
  - 其他请求：先看 `env['rack.session'][:authenticated]` 是否为 true；若否，再看 `Authorization: Bearer <token>` 是否等于 `JOB_CONSOLE_TOKEN`。
  - 通过则 `@app.call(env)`；不通过则 HTML 返回 302 `/login`，API 返回 401 JSON。

### 4.3 路由（app/app.rb）

- `GET /login`：若已登录则 302 `/jobs`，否则 `erb :login`。
- `POST /login`：从 params 取 token，与 `ENV['JOB_CONSOLE_TOKEN']` 比较；成功则 `session[:authenticated] = true`，302 `/jobs`；失败则 401 或 200+ 渲染 login 并带错误信息（建议 200+ 错误信息，避免表单重复提交问题）。
- `GET /logout`：`session.clear` 或 `session[:authenticated] = nil`，302 `/login`。

### 4.4 视图

- 新增 `views/login.erb`：仅包含登录卡片（标题 + 表单 + 可选错误信息），不套 layout 或套一个极简 layout（无 Jobs/Runs 导航），避免未登录时出现业务导航。

---

## 5. 涉及文件清单

| 文件 | 变更 |
|------|------|
| `config.ru` | 启用 `Rack::Session::Cookie`（若当前无 session）。 |
| `lib/auth.rb` | 支持 session；白名单 `/login`、`POST /login`、`/logout`；未登录 HTML→302 `/login`，API→401。 |
| `app/app.rb` | 增加 `GET /login`、`POST /login`、`GET /logout`。 |
| `views/login.erb` | 新建，登录表单 + 错误提示，样式内联或与 layout 一致。 |
| `views/layout.erb` | 在导航区增加「登出」链接（仅当配置了 token 时显示或始终显示均可）。 |

---

## 6. 验收要点

- 未设置 `JOB_CONSOLE_TOKEN` 时，行为与当前一致，无登录页强制跳转。
- 设置 `JOB_CONSOLE_TOKEN` 后，未登录访问 `/jobs` 会跳转到 `/login`；在登录页输入正确 Token 后进入 Jobs，刷新仍保持登录；点击登出后回到登录页。
- API 调用仍可用 `Authorization: Bearer <token>`，不依赖 Cookie。
- 登录页与执行界面风格统一：简洁、无多余图标、字体与配色符合上述规范。

---

*规划文档，实现前可据此拆分 task 或直接按上述步骤开发。*
