#!/bin/bash
set -e
sudo apt update
sudo apt install --only-upgrade -y bash
#====== 彩色输出函数 (必须放前面) ======
green() { echo -e "\033[32m$1\033[0m"; }
red()   { echo -e "\033[31m$1\033[0m"; }

#====== 安装依赖 & 升级 bash ======
sudo apt update -y >/dev/null 2>&1
sudo apt install --only-upgrade -y bash >/dev/null 2>&1
sudo apt install -y curl wget xz-utils jq xxd >/dev/null 2>&1
green "✅ bash 已升级并准备就绪"

#====== 流媒体解锁检测 ======
check_streaming_unlock() {
  green "==== 流媒体解锁检测 ===="

  test_site() {
    local name=$1 url=$2 keyword=$3
    echo -n "检测 $name ... "
    html=$(curl -s --max-time 10 -A "Mozilla/5.0" "$url")
    if echo "$html" | grep -qi "$keyword"; then
      echo "✅ 解锁"
    else
      echo "❌ 未解锁"
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

#====== IP 纯净度检测 ======
check_ip_clean() {
  echo "==== IP 纯净度检测 ===="
  IP=$(curl -s https://api.ipify.org)
  echo "本机公网 IP：$IP"
  hosts=("openai.com" "api.openai.com" "youtube.com" "tiktok.com" "twitter.com" "wikipedia.org")
  for h in "${hosts[@]}"; do
    echo -n "测试 $h ... "
    if timeout 5 curl -sI https://$h >/dev/null; then
      echo "✅"
    else
      echo "❌"
    fi
  done
  echo "========================"
  read -rp "按任意键返回菜单..."
}

#====== 查询已部署的入站协议并生成链接 ======
show_deployed_protocols() {
  CONFIG="/usr/local/etc/xray/config.json"
  if [ ! -f "$CONFIG" ]; then
    red "❌ 找不到 Xray 配置文件：$CONFIG"
    read -rp "按任意键返回菜单..."
    return
  fi

  green "📥 正在分析已部署协议..."

  IP=$(curl -s https://api.ipify.org || echo "yourdomain.com")
  mapfile -t INBOUNDS < <(jq -c '.inbounds[]' "$CONFIG")

  if [ ${#INBOUNDS[@]} -eq 0 ]; then
    red "未发现入站协议配置"
    read -rp "按任意键返回菜单..."
    return
  fi

  for inbound in "${INBOUNDS[@]}"; do
    proto=$(echo "$inbound" | jq -r '.protocol')
    port=$(echo "$inbound" | jq -r '.port')
    clients=$(echo "$inbound" | jq -c '.settings.clients // empty')

    case $proto in
      vless)
        echo "$clients" | jq -c '.[]' | while read -r client; do
          uuid=$(echo "$client" | jq -r '.id')
          remark=$(echo "$client" | jq -r '.email // "VLESS"')
          sni=$(echo "$inbound" | jq -r '.streamSettings.realitySettings.serverNames[0] // "www.cloudflare.com"')
          pbk=$(echo "$inbound" | jq -r '.streamSettings.realitySettings.publicKey // "PUBKEY"')
          sid=$(echo "$inbound" | jq -r '.streamSettings.realitySettings.shortIds[0] // "SID"')
          link="vless://$uuid@$IP:$port?type=tcp&security=reality&sni=$sni&fp=chrome&pbk=$pbk&sid=$sid#$remark"
          green "🎯 VLESS 链接：$link"
        done
        ;;

      vmess)
        echo "$clients" | jq -c '.[]' | while read -r client; do
          uuid=$(echo "$client" | jq -r '.id')
          remark=$(echo "$client" | jq -r '.email // "VMESS"')
          link_json=$(jq -n \
            --arg v "2" \
            --arg add "$IP" \
            --arg port "$port" \
            --arg id "$uuid" \
            --arg aid "0" \
            --arg net "tcp" \
            --arg type "none" \
            --arg host "" \
            --arg path "" \
            --arg tls "none" \
            --arg name "$remark" \
            '{
              v: $v, ps: $name, add: $add, port: $port,
              id: $id, aid: $aid, net: $net,
              type: $type, host: $host, path: $path, tls: $tls
            }')
          encoded=$(echo "$link_json" | base64 -w 0)
          green "🎯 VMess 链接：vmess://$encoded"
        done
        ;;

      shadowsocks)
        method=$(echo "$inbound" | jq -r '.settings.method')
        password=$(echo "$inbound" | jq -r '.settings.password')
        remark="Shadowsocks-$port"
        userpass=$(echo -n "$method:$password" | base64)
        green "🎯 SS 链接：ss://$userpass@$IP:$port#$remark"
        ;;

      trojan)
        echo "$clients" | jq -c '.[]' | while read -r client; do
          password=$(echo "$client" | jq -r '.password')
          remark=$(echo "$client" | jq -r '.email // "trojan"')
          green "🎯 Trojan 链接：trojan://$password@$IP:$port#${remark}"
        done
        ;;

      *)
        yellow "⚠️  未支持的协议: $proto"
        ;;
    esac
  done

  echo
  read -rp "按任意键返回菜单..."
}
#====== 主菜单 ======
while true; do
  clear
  green "官网: sadidc.cn"
  green "======= VLESS Reality 一键脚本 ======="
  echo "1) 安装并配置 VLESS Reality 节点"
  echo "2) 生成 VLESS 中转链接"
  echo "3) 开启 BBR 加速"
  echo "4) 测试流媒体解锁"
  echo "5) 检查 IP 纯净度"
  echo "6) Ookla Speedtest 测试"
  echo "7) 卸载 Xray"
  echo "8) 查询 Xray 已部署协议"
  echo "0) 退出"
  echo
  read -rp "请选择操作: " choice

  case "$choice" in
    1)
      read -rp "监听端口（如 443）: " PORT
      read -rp "节点备注（如：sadcloudUSA）: " REMARK

      bash <(curl -Ls https://github.com/XTLS/Xray-install/raw/main/install-release.sh)
      XRAY_BIN=$(command -v xray || echo "/usr/local/bin/xray")
      [ ! -x "$XRAY_BIN" ] && red "❌ Xray 安装失败" && exit 1

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
    "settings": {
      "clients": [{ "id": "$UUID", "email": "$REMARK" }],
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
      new_link=$(echo "$old_link" | sed -E "s#(@)[^:]+#\\1$new_server#")
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
      green "✅ Xray 已卸载"
      read -rp "按任意键返回菜单..."
      ;;

    8)
      show_deployed_protocols
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