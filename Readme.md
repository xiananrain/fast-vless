# VLESS Trojan One-Click Installation Script

English|[简体中文](Readme.cn.md)

> [!Note]
> The English translation is not 100% accurate, as it is primarily based on Claude-sonnet-4. The final result may still have some issues. If you find any problems or believe there are errors, please submit issues to help improve fast-vless.

> ·Special thanks to **Zedware Network** and **Zedware** for their tremendous support!  
> 
> ·Special thanks to **[拼好鸽](https://gelxc.cloud)** for their tremendous support!   

## 🚀 Overview

This project is a lightweight, one-click installation script that supports:

- ✅ **Latest Xray Installation** - Automatically installs the most recent version
- 🔒 **Advanced Protocols** - VLESS + Reality & Trojan + Reality modes  
- 🌐 **Streaming Detection** - Media unlock detection (powered by ip.check.place)
- 🔗 **Auto-Generated Links** - Direct VLESS connection URLs for easy client import

---

## 📋 Prerequisites

- VPS or LXC container with `root` privileges
- If you don't have root access, try: `su root` or `sudo -s`

## ⚡ Quick Start

Run the following command with **root privileges**:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/xiananrain/fast-vless/main/xrayvless.sh)
