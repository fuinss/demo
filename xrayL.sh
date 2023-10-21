#!/bin/bash

DEFAULT_START_PORT=20000                         # 默认起始端口
DEFAULT_WS_PATH="/ws"                            # 默认ws路径
DEFAULT_UUID=$(cat /proc/sys/kernel/random/uuid) # 默认随机UUID

IP_ADDRESSES=($(hostname -I))

install_xray() {
    echo "安装 Xray..."
    apt-get install unzip -y || yum install unzip -y
    wget https://github.com/XTLS/Xray-core/releases/download/v1.8.3/Xray-linux-64.zip
    unzip Xray-linux-64.zip
    mv xray /usr/local/bin/xrayL
    chmod +x /usr/local/bin/xrayL
    cat <<EOF >/etc/systemd/system/xrayL.service
[Unit]
Description=XrayL Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xrayL -c /etc/xrayL/config.json
Restart=on-failure
User=nobody
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable xrayL.service
    systemctl start xrayL.service
    echo "Xray 安装完成."
}

config_xray() {
    config_type=$1
    mkdir -p /etc/xrayL
    if [ "$config_type" != "http" ] && [ "$config_type" != "vmess" ]; then
        echo "类型错误！仅支持http和vmess."
        exit 1
    fi

    read -p "起始端口 (默认 $DEFAULT_START_PORT): " START_PORT
    START_PORT=${START_PORT:-$DEFAULT_START_PORT}

    if [ "$config_type" == "vmess" ]; then
        read -p "UUID (默认随机): " UUID
        UUID=${UUID:-$DEFAULT_UUID}
        read -p "WebSocket 路径 (默认 $DEFAULT_WS_PATH): " WS_PATH
        WS_PATH=${WS_PATH:-$DEFAULT_WS_PATH}
    fi

    for ((i = 0; i < ${#IP_ADDRESSES[@]}; i++)); do
        config_content+="{
  \"inbounds\": [
    {
      \"port\": $((START_PORT + i)),
      \"protocol\": \"$config_type\",
      \"settings\": {
        \"udp\": true
      },
      \"tag\": \"tag_$((i + 1))\"
    }
  ],
  \"outbounds\": [
    {
      \"protocol\": \"freedom\",
      \"settings\": {},
      \"tag\": \"tag_$((i + 1))\"
    }
  ],
  \"routing\": {
    \"rules\": [
      {
        \"type\": \"field\",
        \"inboundTag\": [
          \"tag_$((i + 1))\"
        ],
        \"outboundTag\": \"tag_$((i + 1))\"
      }
    ]
  }
}
"
        if [ "$config_type" == "vmess" ]; then
            config_content+=",{
  \"inbounds\": [
    {
      \"protocol\": \"vmess\",
      \"port\": $((START_PORT + i)),
      \"tag\": \"tag_$((i + 1))\",
      \"settings\": {
        \"clients\": [
          {
            \"id\": \"$UUID\"
          }
        ]
      },
      \"streamSettings\": {
        \"network\": \"ws\",
        \"wsSettings\": {
          \"path\": \"$WS_PATH\"
        }
      }
    }
  ]
}"
        fi

        config_content+=$'\n'
    done
    echo "$config_content" >/etc/xrayL/config.json
    systemctl restart xrayL.service
    systemctl --no-pager status xrayL.service
    echo ""
    echo "生成 $config_type 配置完成"
    echo "起始端口:$START_PORT"
    echo "结束端口:$(($START_PORT + $i - 1))"
    if [ "$config_type" == "vmess" ]; then
        echo "UUID:$UUID"
        echo "ws路径:$WS_PATH"
    fi
    echo ""
}

main() {
    [ -x "$(command -v xrayL)" ] || install_xray
    if [ $# -eq 1 ]; then
        config_type="$1"
    else
        read -p "选择生成的节点类型 (http/vmess): " config_type
    fi
    if [ "$config_type" == "vmess" ]; then
        config_xray "vmess"
    elif [ "$config_type" == "http" ]; then
        config_xray "http"
    else
        echo "未正确选择类型，使用默认http配置."
        config_xray "http"
    fi
}
main "$@"
