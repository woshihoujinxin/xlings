#!/bin/bash

# 安全与错误处理
set -euo pipefail
trap 'echo "[xlings]: interrupted"; exit 1' INT TERM

# 目录解析
RUN_DIR="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# 颜色
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
PURPLE='\033[35m'
CYAN='\033[36m'
RESET='\033[0m'

# 基本日志函数
log() { echo -e "${PURPLE}[xlings]:${RESET} $*"; }
ok()  { echo -e "${GREEN}[xlings]:${RESET} $*"; }
warn(){ echo -e "${YELLOW}[xlings]:${RESET} $*"; }
err() { echo -e "${RED}[xlings]:${RESET} $*"; }

# 系统检测
UNAME="$(uname)"
XMAKE_BIN_URL_LINUX="https://gitee.com/sunrisepeak/xlings-pkg/raw/master/xmake-3.0.0-linux-x86_64"
XMAKE_BIN_URL_MACOS="https://gitee.com/sunrisepeak/xlings-pkg/raw/master/xmake-3.0.0-macosx-arm64"

# 选择下载源与符号链接位置
XMAKE_BIN_URL="$XMAKE_BIN_URL_LINUX"
XLINGS_SYMLINK="/usr/bin/xlings"
if [ "$UNAME" = "Darwin" ]; then
  XMAKE_BIN_URL="$XMAKE_BIN_URL_MACOS"
  XLINGS_SYMLINK="/usr/local/bin/xlings"
fi

# XLINGS_HOME：仅在未设置时赋值
if [ -z "${XLINGS_HOME:-}" ]; then
  if [ "$UNAME" = "Darwin" ]; then
    XLINGS_HOME="$HOME"
  else
    XLINGS_HOME="/home/xlings"
  fi
fi

# 路径基于 XLINGS_HOME
XLINGS_DATA_DIR="$XLINGS_HOME/.xlings_data"
XLINGS_BIN_DIR="$XLINGS_DATA_DIR/bin"
XMAKE_BIN="xmake" # 默认使用系统 xmake，若无则下载到 bin/xmake

log "start detect environment and try to auto config..."
log "UNAME=$UNAME"
log "XLINGS_HOME=$XLINGS_HOME"
log "XLINGS_SYMLINK=$XLINGS_SYMLINK"
log "XMAKE_BIN_URL=$XMAKE_BIN_URL"

# 确保缓存与可执行目录存在
mkdir -p "$XLINGS_BIN_DIR"

# 1) 检查或安装 xmake
install_xmake_if_needed() {
  if command -v xmake &>/dev/null; then
    ok "xmake installed"
    XMAKE_BIN="xmake"
    return
  fi

  log "start install xmake..."
  XMAKE_BIN="$ROOT_DIR/bin/xmake"
  mkdir -p "$ROOT_DIR/bin"
  curl -sSL "$XMAKE_BIN_URL" -o "$XMAKE_BIN"
  chmod +x "$XMAKE_BIN"

  if [ "$UNAME" = "Darwin" ]; then
    # 去除隔离属性，可能不存在，忽略错误
    xattr -d com.apple.quarantine "$XMAKE_BIN" || true
  fi

  if ! "$XMAKE_BIN" --version &>/dev/null; then
    err "xmake install failed or not executable"
    exit 1
  fi
  ok "xmake ready: $XMAKE_BIN"
}

# 2) 以非 root 运行；如是 root，设置环境变量提示允许
prepare_root_env() {
  if [ "${UID:-$(id -u)}" -eq 0 ]; then
    warn "running as root is not recommended; set XMAKE_ROOT=y to continue"
    export XMAKE_ROOT=y
  fi
}

# 3) 安装 xlings 核心
install_xlings_core() {
  cd "$ROOT_DIR/core"
  log "invoke xmake to install xlings core..."
  "$XMAKE_BIN" xlings unused self enforce-install

  # 创建符号链接：需要 sudo
  log "create symlink: $XLINGS_SYMLINK -> $XLINGS_BIN_DIR/xlings"
  sudo ln -sf "$XLINGS_BIN_DIR/xlings" "$XLINGS_SYMLINK"

  # 更新 PATH
  export PATH="$XLINGS_BIN_DIR:$PATH"
  ok "PATH updated: $XLINGS_BIN_DIR added"
}

# 4) 初始化：安装 xvm、创建 xim、xinstall 等
run_xlings_init() {
  # 优先使用刚安装的 xlings 可执行；若 PATH 未生效，尝试直接执行
  if command -v xlings &>/dev/null; then
    log "run: xlings self init"
    xlings self init
  elif [ -x "$XLINGS_BIN_DIR/xlings" ]; then
    log "run: $XLINGS_BIN_DIR/xlings self init"
    "$XLINGS_BIN_DIR/xlings" self init
  else
    err "xlings not found after installation; PATH may not be refreshed"
    return 1
  fi
}

# 主流程
main() {
  install_xmake_if_needed
  prepare_root_env
  install_xlings_core
  run_xlings_init || warn "init step did not complete; please refresh shell and retry"

  ok "xlings installed"
  echo
  echo -e "\t    run [${YELLOW} xlings help ${RESET}] get more information"
  echo -e "\t after restart ${YELLOW} cmd/shell ${RESET} to refresh environment"
  echo

  cd "$RUN_DIR"
}

main "$@"