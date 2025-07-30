#!/bin/bash
set -e

green() { printf "\033[32m%s\033[0m\n" "$1"; }
red()   { printf "\033[31m%s\033[0m\n" "$1"; }

# 检查并提示 bash 存在（默认就有）
if ! command -v bash >/dev/null 2>&1; then
  red "未检测到 bash，正在安装..."
  apt update -y && apt install -y bash
else
  echo "bash 已安装，继续执行"
fi

# 安装依赖（静默）
apt update -y >/dev/null 2>&1
apt install -y curl wget xz-utils jq lsof xxd >/dev/null 2>&1

# ========== 模块：流媒体解锁自测 ==========
check_streaming_unlock() {
  green "==== 流媒体解锁自测 ===="

  test_site() {
    local name=$1
    local url=$2
    local keyword=$3
    echo -n "检测 $name ... "
    html=$(curl -s --max-time 10 -A "Mozilla/5.0" "$url")
    if echo "$html" | grep -qi "$keyword"; then
      echo "✅ 解锁"
    else
      echo "❌ 限制/不可用"
    fi
  }

  test_site "Netflix" "https://www.netflix.com/title/80018499" "netflix"
  test_site "Disney+" "https://www.disneyplus.com/" "disney"
  test_site "YouTube Premium" "https://www.youtube.com/premium" "Premium"
  test_site "ChatGPT" "https://chat.openai.com/" "OpenAI"
  test_site "Twitch" "https://www.twitch.tv/" "Twitch"
  test_site "HBO Max" "https://play.hbomax.com/" "HBO"

  echo "=========================="
  read -rp "按任意键返回菜单..."
}

# ========== 模块：纯净度检测 ==========
check_ip_clean() {
  echo "==== IP 纯净度检测 ===="
  IP="$(curl -s https://api.ipify.org)"
  echo "本机公网 IP：$IP"
  echo
  check_host() {
    host=$1
    echo -n "测试连接 $host ... "
    timeout 10 curl -s --max-time 10 -I https://$host >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "✅"
    else
      echo "❌ 无法连接"
    fi
  }
  hosts=("openai.com" "api.openai.com" "youtube.com" "tiktok.com" "twitter.com" "wikipedia.org")
  for h in "${hosts[@]}"; do
    check_host "$h"
  done
  echo "========================"
  read -rp "按任意键返回菜单..."
}

# ========== 主菜单 ==========
while true; do
  clear
  green "官网：https://sadidc.cn"
  green "========= VLESS Reality 一键脚本 ========="
  echo "1) 安装并配置 VLESS Reality 节点"
  echo "2) 生成 VLESS 中转链接"
  echo "3) 开启 BBR 加速"
  echo "4) 测试流媒体解锁"
  echo "5) 检查 IP 纯净度 (无需 API Key)"
  echo "6) Ookla Speedtest 测试"
  echo "7) 卸载 Xray"
  echo "0) 退出"
  echo
  read -rp "请选择操作: " choice

  case "$choice" in
    1)
      read -rp "监听端口（如 443）: " PORT
      read -rp "节点备注（如 sadcloudUSA）: " REMARK
      bash <(curl -Ls https://github.com/XTLS/Xray-install/raw/main/install-release.sh)
      XRAY_BIN=$(command -v xray || echo "/usr/local/bin/xray")
      if [ ! -x "$XRAY_BIN" ]; then
        red "❌ Xray 安装失败"
        exit 1
      fi
      UUID=$(cat /proc/sys/kernel/random/uuid)
      KEYS=$($XRAY_BIN x25519)
      PRIV_KEY=$(echo "$KEYS" | awk '/Private/ {print $3}')
      PUB_KEY=$(echo "$KEYS" | awk '/Public/ {print $3}')
      SHORT_ID=$(head -c 4 /dev/urandom | xxd -p)
      SNI="www.cloudflare.com"
      mkdir -p /usr/local/etc/xray
      cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [{
    "port": $PORT,
    "protocol": "vless",
    "settings": { "clients": [{ "id": "$UUID", "email": "$REMARK" }], "decryption": "none" },
    "streamSettings": {
      "network": "tcp",
      "security": "reality",
      "realitySettings": {
        "show": false,
        "dest": "$SNI:443",
        "xver": 0,
        "serverNames": ["$SNI"],
        "privateKey": "$PRIV_KEY",
        "shortIds": ["$SHORT_ID"]
      }
    }
  }],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF
      systemctl daemon-reexec
      systemctl restart xray
      systemctl enable xray
      IP=$(curl -s ipv4.ip.sb || curl -s ifconfig.me)
      LINK="vless://$UUID@$IP:$PORT?type=tcp&security=reality&sni=$SNI&fp=chrome&pbk=$PUB_KEY&sid=$SHORT_ID#$REMARK"
      green "✅ 节点链接如下："
      echo "$LINK"
      read -rp "按任意键返回菜单..."
      ;;

    2)
      read -rp "请输入原始 VLESS 链接: " old_link
      read -rp "请输入中转服务器地址（IP 或域名）: " new_server
      new_link=$(echo "$old_link" | sed -E "s#(@)[^:]+#\1$new_server#")
      green "🎯 生成的新中转链接："
      echo "$new_link"
      read -rp "按任意键返回菜单..."
      ;;

    3)
      echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
      echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
      sysctl -p
      green "✅ BBR 加速已启用"
      read -rp "按任意键返回菜单..."
      ;;

    4)
      check_streaming_unlock
      ;;
    5)
      check_ip_clean
      ;;
    6)
      green "📡 Ookla Speedtest 下载并运行..."
      wget -q https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-x86_64.tgz
      tar -zxf ookla-speedtest-1.2.0-linux-x86_64.tgz
      chmod +x speedtest
      ./speedtest --accept-license --accept-gdpr
      rm -f speedtest speedtest.5 speedtest.md ookla-speedtest-1.2.0-linux-x86_64.tgz
      read -rp "按任意键返回菜单..."
      ;;
    7)
      systemctl stop xray
      systemctl disable xray
      rm -rf /usr/local/etc/xray /usr/local/bin/xray
      green "✅ Xray 已彻底卸载"
      read -rp "按任意键返回菜单..."
      ;;
    0)
      exit 0
      ;;
    *)
      red "❌ 无效选项，请重试"
      sleep 1
      ;;
  esac
done