#!/bin/bash
set -e
#====== 彩色输出函数 (必须放前面) ======
green() { echo -e "\033[32m$1\033[0m"; }
red()   { echo -e "\033[31m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; } 
#====== 安装依赖 ======
sudo apt install -y curl wget xz-utils jq xxd >/dev/null 2>&1
#====== 检测xray是否安装 =====
check_and_install_xray() {
  if command -v xray >/dev/null 2>&1; then
    green "✅ Xray 已安装，跳过安装"
  else
    green "❗检测到 Xray 未安装，正在安装..."
    bash <(curl -L https://lax.xx.kg/https://github.com/Lorry-San/fast-vless/raw/main/xrayinstall.sh)
    XRAY_BIN=$(command -v xray || echo "/usr/local/bin/xray")
    if [ ! -x "$XRAY_BIN" ]; then
      red "❌ Xray 安装失败，请检查"
      exit 1
    fi
    green "✅ Xray 安装完成"
  fi
}
#====== 流媒体解锁检测 ======
check_streaming_unlock() {
  bash <(curl -L ip.check.place) -y
  read -rp "按任意键返回菜单..."
}

#====== IP 纯净度检测 ======
check_ip_clean() {
  bash <(curl -L ip.check.place) -y
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
          sni=$(echo "$inbound" | jq -r '.streamSettings.realitySettings.serverNames[0] // "icloud.cdn-apple.com"')
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
install_trojan_reality() {
  check_and_install_xray
  XRAY_BIN=$(command -v xray || echo "/usr/local/bin/xray")
  read -rp "监听端口（如 443）: " PORT
  read -rp "节点备注（如：trojanNode）: " REMARK

  PASSWORD=$(openssl rand -hex 8)
  KEYS=$($XRAY_BIN x25519)
  PRIV_KEY=$(echo "$KEYS" | awk '/PrivateKey:/ {print $2}')
  PUB_KEY=$(echo "$KEYS" | awk '/Password/ {print $2}')
  SHORT_ID=$(head -c 4 /dev/urandom | xxd -p)
  SNI="icloud.cdn-apple.com"

  mkdir -p /usr/local/etc/xray
  cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [{
    "port": $PORT,
    "protocol": "trojan",
    "settings": {
      "clients": [{ "password": "$PASSWORD", "email": "$REMARK" }]
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
  LINK="trojan://$PASSWORD@$IP:$PORT?security=reality&sni=$SNI&pbk=$PUB_KEY&sid=$SHORT_ID&type=tcp&headerType=none#aa"
  green "✅ Trojan Reality 节点链接如下："
  echo "$LINK"
  read -rp "按任意键返回菜单..."
}
#====== 主菜单 ======
while true; do
  clear
  green "AD：优秀流媒体便宜LXC小鸡：伤心的云 sadidc.cn"
  green "AD：低价精品线路KVM & LXC：拼好鸽 gelxc.cloud"
  green "AD: 大量优秀解锁 & 优化线路KVM: jia cloud jiavps.com"
  green "======= VLESS Reality 一键脚本V5.2正式版 by Lorry-San（💩山Pro Max） ======="
  echo "1) 安装并配置 VLESS Reality 节点"  
  echo "2）生成Trojan Reality节点"
  echo "3) 生成 VLESS 中转链接"
  echo "4) 开启 BBR 加速"
  echo "5) 检查 IP 纯净度 & 流媒体解锁"
  echo "6) Ookla Speedtest 测试"
  echo "7) 卸载 Xray"
  echo "0) 退出"
  echo
  read -rp "请选择操作: " choice

  case "$choice" in
    1)
      check_and_install_xray
      XRAY_BIN=$(command -v xray || echo "/usr/local/bin/xray")
      read -rp "监听端口（如 443）: " PORT
      read -rp "节点备注: " REMARK
      UUID=$(cat /proc/sys/kernel/random/uuid)
      KEYS=$($XRAY_BIN x25519)
      PRIV_KEY=$(echo "$KEYS" | awk '/PrivateKey:/ {print $2}')
      PUB_KEY=$(echo "$KEYS" | awk '/Password/ {print $2}')
      SHORT_ID=$(head -c 4 /dev/urandom | xxd -p)
      SNI="icloud.cdn-apple.com"

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
      install_trojan_reality
      ;;
    3)
      read -rp "请输入原始 VLESS 链接: " old_link
      read -rp "请输入中转服务器地址（IP 或域名）: " new_server
      new_link=$(echo "$old_link" | sed -E "s#(@)[^:]+#\\1$new_server#")
      green "🎯 生成的新中转链接："
      echo "$new_link"
      read -rp "按任意键返回菜单..."
      ;;

    4)
      echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
      echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
      sysctl -p
      green "✅ BBR 加速已启用"
      read -rp "按任意键返回菜单..."
      ;;

    5)
      check_streaming_unlock
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

    0)
      exit 0
      ;;

    *)
      red "❌ 无效选项，请重试"
      sleep 1
      ;;
  esac
done
