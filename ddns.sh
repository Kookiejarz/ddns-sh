#!/bin/bash

# 改进的进度条函数
show_progress() {
  local duration=$1
  local steps=20
  local delay=$(bc <<< "scale=2; $duration/$steps")
  
  # 定义颜色
  local green="\e[32m"
  local blue="\e[34m"
  local reset="\e[0m"
  
  # 进度条字符
  local filled="▰"
  local empty="▱"
  
  echo -ne "${blue}Progress: ${reset}"
  
  for ((i = 0; i <= steps; i++)); do
    local percentage=$((i*100/steps))
    local num_filled=$((i*40/steps))
    local num_empty=$((40-num_filled))
    
    # 构建进度条
    local progress_bar=""
    for ((j = 0; j < num_filled; j++)); do
      progress_bar="${progress_bar}${green}${filled}${reset}"
    done
    for ((j = 0; j < num_empty; j++)); do
      progress_bar="${progress_bar}${empty}"
    done
    
    # 打印进度条
    echo -ne "\r${blue}Progress: ${reset}[${progress_bar}] ${percentage}%"
    
    sleep "$delay"
  done
  
  echo -e "\n${green}完成!${reset}"
}

# 设置脚本路径
SCRIPT_URL="https://raw.githubusercontent.com/zanjie1999/cloudflare-api-v4-ddns/master/cf-v4-ddns.sh"
SCRIPT_PATH="/usr/local/bin/cf-v4-ddns.sh"

# 检查是否已安装 curl，如果没有则安装
echo "检查 curl 是否已安装..."
if ! command -v curl &> /dev/null; then
    echo "curl 未安装，正在安装..."
    sudo apt-get update && sudo apt-get install -y curl
fi
show_progress 3

# 下载并设置脚本权限
echo "正在下载 cf-v4-ddns.sh..."
sudo curl -o "$SCRIPT_PATH" "$SCRIPT_URL"
sudo chmod +x "$SCRIPT_PATH"
show_progress 3

# 让用户输入自定义配置
echo "请输入以下自定义配置: "
read -p "请输入 Cloudflare API Token: " CFTOKEN
read -p "请输入 Zone 名称 (例如 example.com): " CFZONE_NAME
read -p "请输入要更新的主机名 (例如 host.example.com): " CFRECORD_NAME
read -p "请输入记录类型 (A 为 IPv4,AAAA 为 IPv6): " CFRECORD_TYPE
read -p "请输入 TTL 时间 (120 到 86400 秒): " CFTTL
read -p "是否强制更新 IP?(true/false): " FORCE
show_progress 2

# 将自定义配置写入脚本
echo "正在写入自定义配置..."
sudo sed -i "s/^CFTOKEN=.*/CFTOKEN=\"$CFTOKEN\"/" "$SCRIPT_PATH"
sudo sed -i "s/^CFZONE_NAME=.*/CFZONE_NAME=\"$CFZONE_NAME\"/" "$SCRIPT_PATH"
sudo sed -i "s/^CFRECORD_NAME=.*/CFRECORD_NAME=\"$CFRECORD_NAME\"/" "$SCRIPT_PATH"
sudo sed -i "s/^CFRECORD_TYPE=.*/CFRECORD_TYPE=\"$CFRECORD_TYPE\"/" "$SCRIPT_PATH"
sudo sed -i "s/^CFTTL=.*/CFTTL=\"$CFTTL\"/" "$SCRIPT_PATH"
sudo sed -i "s/^FORCE=.*/FORCE=\"$FORCE\"/" "$SCRIPT_PATH"
show_progress 3

# 添加 crontab 定时任务，每 2 分钟运行一次脚本
echo "正在设置 crontab 定时任务..."
(crontab -l 2>/dev/null; echo "*/2 * * * * $SCRIPT_PATH >/dev/null 2>&1") | crontab -
show_progress 2

# 创建 systemd 服务文件
SERVICE_FILE="/etc/systemd/system/cf-v4-ddns.service"
echo "正在创建 systemd 服务文件..."
sudo bash -c "cat > $SERVICE_FILE << EOL
[Unit]
Description=Cloudflare DDNS Update Service

[Service]
ExecStart=$SCRIPT_PATH
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOL"
show_progress 3

# 重新加载 systemd 守护进程
echo "重新加载 systemd 守护进程..."
sudo systemctl daemon-reload
show_progress 1

# 启动并启用服务
echo "启动并设置开机自启..."
sudo systemctl start cf-v4-ddns.service
sudo systemctl enable cf-v4-ddns.service
show_progress 3

echo "DONE!"