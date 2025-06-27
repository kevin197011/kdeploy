创建一个kdeploy运维部署工具类似chef puppet ansible agentless的工具
- 采用ruby gem的方式编写生成二进制执行文件
- 采用DSL的方式生成运维框架
- 轻量级，执行并发控制
- 可以批量执行shell
- 主机清单及登录用户，ssh端口，ssh证书配置都采用inventory.yml, 支持主机群组配置
- 支持dochere的方式配置shell脚本执行
- 支持erb模版文件