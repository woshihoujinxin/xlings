#!/bin/bash

# 严格模式：遇到错误立即退出，使用未定义变量时报错
set -euo pipefail

# 全局变量
readonly QI_RUN_DIR="$(pwd)"
readonly QI_INSTALL_DIR=".xlings_software_install"
readonly SOFTWARE_URL0="https://vip.123pan.cn/1825134841/32180721"
readonly SOFTWARE_URL1="https://github.com/woshihoujinxin/xlings/archive/refs/heads/dev.zip"
readonly SOFTWARE_URL2="https://gitee.com/houjinxin/xlings/repository/archive/dev.zip"
readonly ZIP_FILE="software.zip"
readonly XLINGS_DIR="xlings-dev"
readonly INSTALL_SCRIPT="tools/install.unix.sh"

# 颜色定义
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
PURPLE='\033[35m'
RESET='\033[0m'

# 错误处理函数
error_exit() {
    echo -e "${RED}错误: $1${RESET}" >&2
    cleanup
    exit 1
}

# 清理函数
cleanup() {
    if [ -d "$QI_RUN_DIR/$QI_INSTALL_DIR" ]; then
        echo -e "${YELLOW}清理临时文件...${RESET}"
        cd "$QI_RUN_DIR"
        rm -rf "$QI_INSTALL_DIR"
    fi
}

# 信号处理
trap 'error_exit "安装被中断"' INT TERM

# 显示欢迎信息
show_banner() {
    cat << 'EOF'

 __   __  _      _                     
 \ \ / / | |    (_)    pre-v0.0.4
  \ V /  | |     _  _ __    __ _  ___ 
   > <   | |    | || '_ \  / _  |/ __|
  / . \  | |____| || | | || (_| |\__ \
 /_/ \_\ |______|_||_| |_| \__, ||___/
                            __/ |     
                           |___/      

repo:  https://github.com/d2learn/xlings
forum: https://forum.d2learn.org

---
EOF
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 测量网络延迟
measure_latency() {
    local url="$1"
    local domain
    domain=$(echo "$url" | sed -e 's|^[^/]*//||' -e 's|/.*$||')
    
    # 使用更简单的方法测试连通性
    if command_exists curl; then
        # 测试连接时间，超时5秒
        if curl -s --connect-timeout 5 --max-time 10 -o /dev/null "$url" 2>/dev/null; then
            echo "0"  # 连接成功
        else
            echo "999999"  # 连接失败
        fi
    else
        echo "999999"
    fi
}

# 选择下载源（先检查响应与内容类型，15秒无响应或返回网页则换源）
select_fastest_url() {
    echo -e "${BLUE}测试下载源可用性...${RESET}" >&2

    local urls=("$SOFTWARE_URL0" "$SOFTWARE_URL1" "$SOFTWARE_URL2")
    for url in "${urls[@]}"; do
        # 头部检查：HTTP 2xx/3xx 且 Content-Type 非 text/html
        local headers
        headers="$(curl -sI --connect-timeout 5 --max-time 15 "$url" || true)"
        if echo "$headers" | grep -Eqi 'HTTP/.* (200|30[0-9])' && ! echo "$headers" | grep -Eqi 'Content-Type:\s*text/html' ; then
            echo -e "${GREEN}使用源: ${RESET}$url" >&2
            echo "$url"
            return
        else
            echo -e "${YELLOW}源不可用或返回网页，切换: ${RESET}$url${YELLOW} -> 下一个源${RESET}" >&2
        fi
    done

    echo -e "${YELLOW}源检测均失败，回退到 GitHub${RESET}" >&2
    echo "$SOFTWARE_URL1"
}

# 安装工具函数
install_tool() {
    local tool="$1"
    echo -e "${YELLOW}正在安装 $tool...${RESET}"
    
    if command_exists apt-get; then
        sudo apt-get update -qq && sudo apt-get install -y "$tool"
    elif command_exists yum; then
        sudo yum install -y "$tool"
    elif command_exists dnf; then
        sudo dnf install -y "$tool"
    elif command_exists zypper; then
        sudo zypper install -y "$tool"
    elif command_exists pacman; then
        sudo pacman -S --noconfirm "$tool"
    elif command_exists brew; then
        brew install "$tool"
    else
        error_exit "无法安装 $tool，请手动安装后重试"
    fi
}

# 检查并安装必要工具
check_and_install_tool() {
    local tool="$1"
    if ! command_exists "$tool"; then
        echo -e "${YELLOW}$tool 未安装，正在尝试安装...${RESET}"
        install_tool "$tool"
        if ! command_exists "$tool"; then
            error_exit "安装 $tool 失败，请手动安装后重试"
        fi
        echo -e "${GREEN}$tool 安装成功${RESET}"
    else
        echo -e "${GREEN}$tool 已安装${RESET}"
    fi
}

# 检查系统依赖
check_dependencies() {
    echo -e "${BLUE}检查系统依赖...${RESET}"
    check_and_install_tool curl
    check_and_install_tool unzip
    check_and_install_tool git
}

# 下载和安装函数
download_and_install() {
    local software_url="$1"
    
    # 清理旧的安装目录
    if [ -d "$QI_INSTALL_DIR" ]; then
        echo -e "${YELLOW}清理旧的安装文件...${RESET}"
        rm -rf "$QI_INSTALL_DIR"
    fi

    # 创建临时目录
    mkdir -p "$QI_INSTALL_DIR"
    cd "$QI_INSTALL_DIR" || error_exit "无法进入临时目录"

    # 下载软件包（带源回退）
    echo -e "${BLUE}正在下载 xlings...${RESET}"
    echo -e "${BLUE}下载地址: ${RESET}$software_url"
    echo -e "${BLUE}保存为:   ${RESET}$ZIP_FILE"
    if ! curl -L --retry 2 --connect-timeout 5 --max-time 60 --progress-bar -o "$ZIP_FILE" "$software_url"; then
        echo -e "${YELLOW}首选源下载失败，尝试轮换其他源...${RESET}" >&2
        # 构造轮换列表：优先当前选择，其它按 vip→GitHub→Gitee 顺序依次尝试
        local candidates=("$SOFTWARE_URL0" "$SOFTWARE_URL1" "$SOFTWARE_URL2")
        local tried="$software_url"
        for candidate in "${candidates[@]}"; do
            [ "$candidate" = "$software_url" ] && continue
            echo -e "${BLUE}备用下载地址: ${RESET}$candidate"
            # 下载前进行头部检查（15s）
            local headers
            headers="$(curl -sI --connect-timeout 5 --max-time 15 "$candidate" || true)"
            if ! echo "$headers" | grep -Eqi 'HTTP/.* (200|30[0-9])' || echo "$headers" | grep -Eqi 'Content-Type:\s*text/html' ; then
                echo -e "${YELLOW}备用源不可用或返回网页，继续切换...${RESET}" >&2
                continue
            fi
            if curl -L --retry 2 --connect-timeout 5 --max-time 60 --progress-bar -o "$ZIP_FILE" "$candidate"; then
                software_url="$candidate"
                break
            fi
        done
        # 若仍未成功
        if [ ! -s "$ZIP_FILE" ]; then
            error_exit "下载失败，所有源均不可用，请检查网络后重试"
        fi
    fi

    # 验证下载的文件
    if [ ! -f "$ZIP_FILE" ] || [ ! -s "$ZIP_FILE" ]; then
        error_exit "下载的文件无效或为空"
    fi

    # 解压文件
    echo -e "${BLUE}正在解压文件...${RESET}"
    echo -e "${BLUE}解压源:   ${RESET}$ZIP_FILE"
    echo -e "${BLUE}目标目录: ${RESET}$QI_INSTALL_DIR"
    if ! unzip -q "$ZIP_FILE"; then
        error_exit "解压失败，文件可能已损坏"
    fi

    # 进入解压后的目录
    echo -e "${BLUE}进入目录: ${RESET}$XLINGS_DIR"
    if ! cd "$XLINGS_DIR"; then
        error_exit "找不到解压后的目录 $XLINGS_DIR"
    fi

    # 检查安装脚本是否存在
    if [ ! -f "$INSTALL_SCRIPT" ]; then
        error_exit "找不到安装脚本 $INSTALL_SCRIPT"
    fi

    # 在 macOS 下，修补远端 install.unix.sh 中的硬编码路径为 $HOME
    # 将远端脚本的硬编码赋值改为“仅在未设置时赋值”，并统一替换硬编码路径
    # 覆盖 Linux 默认行：XLINGS_HOME="/home/xlings"
    sed -i '' 's#XLINGS_HOME="/home/xlings"#[ -z "${XLINGS_HOME:-}" ] \&\& XLINGS_HOME="$HOME"#g' "$INSTALL_SCRIPT" || true
    # 覆盖 macOS 分支行：XLINGS_HOME="/Users/xlings"
    sed -i '' 's#XLINGS_HOME="/Users/xlings"#[ -z "${XLINGS_HOME:-}" ] \&\& XLINGS_HOME="$HOME"#g' "$INSTALL_SCRIPT" || true
    # 统一替换任何硬编码的 /Users/xlings 文本为当前 $HOME（用于日志与路径）
    sed -i '' 's#/Users/xlings#'"$HOME"'#g' "$INSTALL_SCRIPT" || true

    # 显式导出环境变量，避免子脚本使用旧值
    export XLINGS_HOME="$HOME"
    export XLINGS_HOME_DIR="$HOME"

    # 运行安装脚本
    echo -e "${BLUE}正在运行安装脚本...${RESET}"
    echo -e "${BLUE}执行脚本: ${RESET}$INSTALL_SCRIPT"
    if ! source "$INSTALL_SCRIPT" disable_reopen; then
        error_exit "安装脚本执行失败"
    fi

    # 安装后校验 xlings 是否可用
    if ! command_exists xlings; then
        echo -e "${YELLOW}xlings 未在 PATH 中，尝试追加路径并重试...${RESET}" >&2
        export PATH="$XLINGS_HOME/.xlings_data/bin:$PATH"
        if ! command_exists xlings; then
            echo -e "${RED}xlings 仍不可用。请执行：${RESET} source $(detect_shell_rc) 然后重开终端或手动将以下路径加入 PATH：" >&2
            echo -e "${BLUE}$XLINGS_HOME/.xlings/bin${RESET} 和 ${BLUE}$XLINGS_HOME/.xlings_data/bin${RESET}" >&2
        fi
    fi
}

# 检测 shell 配置文件
detect_shell_rc() {
    # 优先检查当前 shell
    if [ -n "${ZSH_VERSION:-}" ]; then
        echo "$HOME/.zshrc"
    elif [ -n "${BASH_VERSION:-}" ]; then
        echo "$HOME/.bashrc"
    elif [ "$(uname)" = "Darwin" ]; then
        # macOS 默认使用 zsh
        echo "$HOME/.zshrc"
    else
        # Linux 默认使用 bash
        echo "$HOME/.bashrc"
    fi
}

# 配置环境变量
setup_environment() {
    echo -e "${BLUE}配置环境变量...${RESET}"
    
    # 设置 XLINGS_HOME_DIR
    if [ -z "${XLINGS_HOME_DIR:-}" ]; then
        if [ "$(uname)" = "Darwin" ]; then
            XLINGS_HOME_DIR="$HOME"
        else
            XLINGS_HOME_DIR="$HOME"
        fi
        export XLINGS_HOME_DIR
    fi
    
    local rc_file
    rc_file="$(detect_shell_rc)"
    
    # 确保配置文件存在
    mkdir -p "$(dirname "$rc_file")"
    touch "$rc_file"
    
    # 检查是否已经配置过
    if ! grep -q 'XLINGS_HOME_DIR' "$rc_file"; then
        echo -e "${YELLOW}添加环境变量到 $rc_file${RESET}"
        {
            echo ''
            echo '# xlings: 安装脚本添加的环境变量'
            echo "export XLINGS_HOME_DIR=\"$XLINGS_HOME_DIR\""
            echo 'export PATH="$XLINGS_HOME_DIR/.xlings/bin:$XLINGS_HOME_DIR/.xlings_data/bin:$PATH"'
        } >> "$rc_file"
    else
        echo -e "${GREEN}环境变量已配置${RESET}"
    fi
    
    # 当前会话立即生效
    export PATH="$XLINGS_HOME_DIR/.xlings/bin:$XLINGS_HOME_DIR/.xlings_data/bin:$PATH"
}

# 主函数
main() {
    show_banner
    
    echo -e "${BLUE}开始安装 xlings...${RESET}"
    
    # 检查依赖
    check_dependencies
    
    # 选择下载源
    local software_url
    software_url=$(select_fastest_url)
    
    # 下载和安装
    download_and_install "$software_url"
    
    # 配置环境
    setup_environment
    
    # 清理临时文件
    cleanup
    
    echo -e "${GREEN}安装完成！${RESET}"
    echo -e "${YELLOW}请重新启动终端或运行以下命令使环境变量生效：${RESET}"
    echo -e "${BLUE}source $(detect_shell_rc)${RESET}"
    echo -e ""
    echo -e "${BLUE}运行 'xlings help' 获取更多信息${RESET}"
}

# 运行主函数
main "$@"