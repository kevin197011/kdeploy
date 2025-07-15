#!/usr/bin/env bash
set -e

# 检查并安装 Ruby
install_ruby() {
  if command -v ruby >/dev/null 2>&1; then
    echo "Ruby 已安装: $(ruby -v)"
    return
  fi
  echo "未检测到 Ruby，开始自动安装..."
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update
      sudo apt-get install -y ruby-full build-essential
    elif command -v yum >/dev/null 2>&1; then
      sudo yum install -y ruby
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y ruby
    else
      echo "请手动安装 Ruby (未检测到常见包管理器)"
      exit 1
    fi
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v brew >/dev/null 2>&1; then
      brew install ruby
    else
      echo "请手动安装 Homebrew 后再安装 Ruby"
      exit 1
    fi
  else
    echo "不支持的操作系统，请手动安装 Ruby"
    exit 1
  fi
}

# 安装 kdeploy gem
install_kdeploy() {
  if gem list kdeploy -i >/dev/null 2>&1; then
    echo "kdeploy 已安装: $(gem list kdeploy)"
  else
    echo "正在安装 kdeploy..."
    gem install kdeploy
  fi
}

main() {
  install_ruby
  install_kdeploy
  kdeploy init deploy
  cd deploy
  kdeploy execute deploy.rb deploy_web
}

main "$@"

echo "\n全部完成！你可以用 kdeploy --version 查看版本。"
