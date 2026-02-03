## 1. 资源 DSL 基础框架
- [x] 1.1 在 `lib/kdeploy/dsl.rb` 中新增 `package` 方法，编译为 apt `run` 命令
- [x] 1.2 在 `lib/kdeploy/dsl.rb` 中新增 `service` 方法，编译为 systemctl `run` 命令
- [x] 1.3 在 `lib/kdeploy/dsl.rb` 中新增 `template` 方法，编译为 `upload_template` 步骤
- [x] 1.4 在 `lib/kdeploy/dsl.rb` 中新增 `file` 方法，编译为 `upload` 步骤
- [x] 1.5 在 `lib/kdeploy/dsl.rb` 中新增 `directory` 方法，编译为 mkdir `run` 命令

## 2. 平台与参数扩展
- [x] 2.1 为 `package` 支持 `platform: :yum`，生成 yum 命令
- [x] 2.2 为 `package` 支持 `version:` 参数（apt/yum 语法）
- [x] 2.3 为 `directory` 支持 `mode:` 参数（chmod 步骤）

## 3. 测试与验证
- [x] 3.1 为 `package`、`service`、`template`、`file`、`directory` 编写 DSL 单元测试（验证编译输出）
- [x] 3.2 为混合资源+原语任务编写 Runner 集成测试
- [x] 3.3 运行 `bundle exec rspec` 和 `bundle exec rubocop` 确保通过

## 4. 文档与示例
- [x] 4.1 在 README.md 和 README_EN.md 中增加资源 DSL 用法说明与示例
- [x] 4.2 可选：将 `sample/tasks/nginx.rb` 部分任务迁移为资源风格作为示例
