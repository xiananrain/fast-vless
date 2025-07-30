#!/bin/bash
set -e
#兼容老版本bash只能说是我被这个搞红纹了
sudo apt update
sudo apt install --only-upgrade -y bash
======= 彩色输出函数 =======

green()  { echo -e "\033[32m$1\033[0m"; } red()    { echo -e "\033[31m$1\033[0m"; }

apt update -y >/dev/null 2>&1 apt install -y curl wget xz-utils jq xxd >/dev/null 2>&1

======= 流媒体解锁检测 =======

check_streaming_unlock() { green "==== 流媒体解锁检测 ====" test_site() { local name=$1 url=$2 keyword=$3 echo -n "检测 $name ... " html=$(curl -s --max-time 10 -A "Mozilla/5.0" "$url") if echo "$html" | grep -qi "$keyword"; then echo "✅ 解锁" else echo "❌ 未解锁" fi } test_site "Netflix" "https://www.netflix.com/title/80018499" "netflix" test_site "Disney+" "https://www.disneyplus.com/" "disney" test_site "YouTube Premium" "https://www.youtube.com/premium" "Premium" test_site "ChatGPT" "https://chat.openai.com/" "OpenAI" test_site "Twitch" "https://www.twitch.tv/" "Twitch" test_site "HBO Max" "https://play.hbomax.com/" "HBO" echo "==========================" read -rp "按任意键返回菜单..." }

======= IP 纯净度检测 =======

check_ip_clean() { echo "==== IP 纯净度检测 ====" IP=$(curl -s https://api.ipify.org) echo "本机公网 IP：$IP" hosts=("openai.com" "api.openai.com" "youtube.com" "tiktok.com" "twitter.com" "wikipedia.org") for h in "${hosts[@]}"; do echo -n "测试 $h ... " if timeout 5 curl -sI https://$h >/dev/null; then echo "✅"; else echo "❌"; fi done echo "========================" read -rp "按任意键返回菜单..." }

======= 查询支持协议 =======

show_xray_protocols() { echo -e "\n📦 检测当前 Xray 支持的出站协议\n" XRAY_BIN=$(command -v xray || echo "/usr/local/bin/xray") if [ ! -x "$XRAY_BIN" ]; then red "未安装 Xray" read -rp "按任意键返回菜单..."; return fi protocols=("vless" "vmess" "trojan" "shadowsocks" "socks" "http" "wireguard") for proto in "${protocols[@]}"; do echo -n "$proto: " if "$XRAY_BIN" run -test -c <(echo '{"outbounds":[{"protocol":"'"$proto"'","settings":{}}]}') 2>/dev/null; then echo "✅ 支持" else echo "❌ 不支持" fi done echo -e "\n🌐 协议格式示例：" echo "VLESS: vless://UUID@yourdomain.com:443?type=tcp&security=reality&fp=chrome&pbk=PUBKEY&sid=SHORTID#remark" echo "VMess: vmess://Base64EncodedJSON" echo "Trojan: trojan://password@yourdomain.com:443?security=tls&type=tcp#remark" echo "Shadowsocks: ss://method:password@host:port#remark" read -rp "按任意键返回菜单..." }

======= 主菜单 =======

while true; do clear green "官网:sadidc.cn" green "======= VLESS Reality 一键脚本 =======" echo "1) 安装并配置 VLESS Reality 节点" echo "2) 生成 VLESS 中转链接" echo "3) 开启 BBR 加速" echo "4) 测试流媒体解锁" echo "5) 检查 IP 纯净度" echo "6) Ookla Speedtest 测试" echo "7) 卸载 Xray" echo "8) 查询 Xray 支持协议" echo "0) 退出" echo read -rp "请选择操作: " choice

case "$choice" in 1) read -rp "监听端口（如 443）: " PORT read -rp "节点备注（如：sadcloudUSA）: " REMARK bash <(curl -Ls https://github.com/XTLS/Xray-install/raw/main/install-release.sh) XRAY_BIN=$(command -v xray || echo "/usr/local/bin/xray") [ ! -x "$XRAY_BIN" ] && red "❌ Xray 安装失败" && exit 1 UUID=$(cat /proc/sys/kernel/random/uuid) KEYS=$($XRAY_BIN x25519) PRIV_KEY=$(echo "$KEYS" | awk '/Private/ {print $3}') PUB_KEY=$(echo "$KEYS" | awk '/Public/ {print $3}') SHORT_ID=$(head -c 4 /dev/urandom | xxd -p) SNI="www.cloudflare.com" mkdir -p /usr/local/etc/xray cat > /usr/local/etc/xray/config.json <<EOF { "log": { "loglevel": "warning" }, "inbounds": [{ "port": $PORT, "protocol": "vless", "settings": { "clients": [{ "id": "$UUID", "email": "$REMARK" }], "decryption": "none" }, "streamSettings": { "network": "tcp", "security": "reality", "realitySettings": { "show": false, "dest": "$SNI:443", "xver": 0, "serverNames": ["$SNI"], "privateKey": "$PRIV_KEY", "shortIds": ["$SHORT_ID"] } } }], "outbounds": [{ "protocol": "freedom" }] } EOF systemctl daemon-reexec systemctl restart xray systemctl enable xray IP=$(curl -s ipv4.ip.sb || curl -s ifconfig.me) LINK="vless://$UUID@$IP:$PORT?type=tcp&security=reality&sni=$SNI&fp=chrome&pbk=$PUB_KEY&sid=$SHORT_ID#$REMARK" green "✅ 节点链接如下：" echo "$LINK" read -rp "按任意键返回菜单..." ;;

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
  show_xray_protocols
  ;;

0)
  exit 0
  ;;

*)
  red "❌ 无效选项，请重试"
  sleep 1
  ;;

esac done

