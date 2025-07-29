#!/bin/bash

set -e

green() { echo -e "\033[32m$1\033[0m"; }
red()   { echo -e "\033[31m$1\033[0m"; }

echo
green "博客：blog.sddlol.ggff.net"
green "========= Xray 一键安装脚本 ========="
echo "1. 安装 VLESS + Reality"
echo "2. 设置中转模式（VLESS 中转）"
echo "3. 退出"
echo "======================================"
read -p "请选择模式 [1-3]: " MODE

if [[ "$MODE" == "3" ]]; then
  exit 0
fi

# 公共输入
read -p "请输入监听端口（如 443）: " PORT
read -p "请输入备注名称（将作为用户标识）: " REMARK

# 安装依赖
green "[1/5] 安装依赖..."
apt update -y >/dev/null 2>&1
apt install -y curl wget xz-utils jq >/dev/null 2>&1

# 安装 Xray
green "[2/5] 安装 Xray..."
bash <(curl -Ls https://github.com/XTLS/Xray-install/raw/main/install-release.sh)

XRAY_BIN=$(command -v xray || echo "/usr/local/bin/xray")
[ ! -x "$XRAY_BIN" ] && red "❌ 未找到 xray" && exit 1

CONFIG_PATH="/usr/local/etc/xray/config.json"

# ===== Reality 模式 =====
if [[ "$MODE" == "1" ]]; then
  green "[3/5] 配置 Reality 模式..."

  UUID=$(cat /proc/sys/kernel/random/uuid)
  KEYS=$($XRAY_BIN x25519)
  PRIV_KEY=$(echo "$KEYS" | grep "Private key" | awk '{print $3}')
  PUB_KEY=$(echo "$KEYS" | grep "Public key" | awk '{print $3}')
  SHORT_ID=$(head -c 4 /dev/urandom | xxd -p)
  SNI="www.cloudflare.com"

  cat > $CONFIG_PATH <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [{
    "port": $PORT,
    "protocol": "vless",
    "settings": {
      "clients": [{
        "id": "$UUID",
        "email": "$REMARK"
      }],
      "decryption": "none"
    },
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

# 启动
green "[4/5] 启动 Xray..."
systemctl daemon-reexec
systemctl restart xray
systemctl enable xray

IP=$(curl -s ipv4.ip.sb || curl -s ifconfig.me)
VLESS_LINK="vless://$UUID@$IP:$PORT?type=tcp&security=reality&sni=$SNI&fp=chrome&pbk=$PUB_KEY&sid=$SHORT_ID#$REMARK"

green "[5/5] 安装完成 ✅"
green "====== VLESS Reality 节点链接 ======"
echo "$VLESS_LINK"
green "===================================="

# ===== 中转模式 =====
elif [[ "$MODE" == "2" ]]; then
  read -p "请输入目标 VLESS 链接（将中转至此节点）: " ORIGIN

  # 使用正则提取 host 和 port
  DST_HOST=$(echo "$ORIGIN" | sed -n 's|.*@\(.*\):\([0-9]*\)\?.*|\1|p')
  DST_PORT=$(echo "$ORIGIN" | sed -n 's|.*@.*:\([0-9]*\)\?.*|\1|p')

  if [[ -z "$DST_HOST" || -z "$DST_PORT" ]]; then
    red "❌ 无法识别目标链接，请检查格式"
    exit 1
  fi

  green "[3/5] 设置中转到 $DST_HOST:$DST_PORT"

  cat > $CONFIG_PATH <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [{
    "port": $PORT,
    "protocol": "vless",
    "settings": {
      "clients": [{
        "id": "00000000-0000-0000-0000-000000000000",
        "email": "$REMARK"
      }],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "tcp"
    }
  }],
  "outbounds": [{
    "protocol": "vless",
    "settings": {
      "vnext": [{
        "address": "$DST_HOST",
        "port": $DST_PORT,
        "users": [{
          "id": "00000000-0000-0000-0000-000000000000",
          "encryption": "none"
        }]
      }]
    },
    "streamSettings": {
      "network": "tcp"
    }
  }]
}
EOF

  systemctl restart xray
  systemctl enable xray

  green "[5/5] 中转已设置 ✅"
  IP=$(curl -s ipv4.ip.sb || curl -s ifconfig.me)
  green "请将客户端的链接地址改为：$IP:$PORT"
  echo "原始链接：$ORIGIN"
  green "已完成中转，你的 IP 为中转入口，指向 $DST_HOST:$DST_PORT"
fi