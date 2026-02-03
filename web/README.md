# Kdeploy Web Job Console (MVP)

基于 `kdeploy` 执行引擎的最小可用 Web 作业管理后台。

## 运行方式

1) 安装依赖（项目根目录）：

```bash
bundle install
```

2) 初始化数据库（默认 SQLite 文件）：

```bash
bundle exec ruby web/bin/migrate
```

3) 启动服务：

```bash
bundle exec rackup -p 4567 web/config.ru
```

打开 `http://localhost:4567`。

## 环境变量

- `JOB_CONSOLE_DB`: 数据库 URL
  - 示例：`sqlite::memory:`（测试用）
  - 示例：`sqlite:///absolute/path/job_console.sqlite3`
- `JOB_CONSOLE_TOKEN`: **必填**，开启 API/页面鉴权（Bearer token）
  - 请求头：`Authorization: Bearer <token>`
- `JOB_CONSOLE_TASK_BASE_DIR`: **必填**，允许执行的任务文件基准目录
  - 示例：`/Users/me/deployments`
- `JOB_CONSOLE_PERMITTED_HOSTS`: 允许的 Host 列表（逗号分隔）
  - 示例：`localhost,example.org,.example.org`
- `JOB_CONSOLE_MAX_QUEUE`: 队列最大长度（默认 100）
- `JOB_CONSOLE_MAX_RUNNING`: 最大并发执行数（默认 1，即单任务串行）
- `JOB_CONSOLE_HOST_TIMEOUT`: 单 host 执行超时（秒，默认不启用）
- `JOB_CONSOLE_RETRY_ON_NONZERO`: 非零退出码重试开关（true/false，默认 false）

## API（示例）

```bash
curl -H "Authorization: Bearer $JOB_CONSOLE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"demo","task_file_path":"sample/deploy.rb"}' \
  http://localhost:4567/api/jobs
```
