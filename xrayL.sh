#!/bin/bash

DEFAULT_START_PORT=20000                          # Default starting port
DEFAULT_WS_PATH="/ws"                             # Default WebSocket path
DEFAULT_UUID=$(cat /proc/sys/kernel/random/uuid)  # Default random UUID

IP_ADDRESSES=($(hostname -I))

install_xray() {
    echo "Installing Xray..."
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
    echo "Xray installation completed."
}

config_xray() {
    config_type="http"
    mkdir -p /etc/xrayL

    read -p "Starting port (default $DEFAULT_START_PORT): " START_PORT
    START_PORT=${START_PORT:-$DEFAULT_START_PORT}

    for ((i = 0; i < ${#IP_ADDRESSES[@]}; i++)); do
        config_content+="[[inbounds]]\n"
        config_content+="port = $((START_PORT + i))\n"
        config_content+="protocol = \"$config_type\"\n"
        config_content+="tag = \"tag_$((i + 1))\"\n"
        config_content+="[inbounds.settings]\n"
        config_content+="udp = true\n"
        config_content+="ip = \"${IP_ADDRESSES[i]}\"\n"
        config_content+="[[outbounds]]\n"
        config_content+="sendThrough = \"${IP_ADDRESSES[i]}\"\n"
        config_content+="protocol = \"freedom\"\n"
        config_content+="tag = \"tag_$((i + 1))\"\n\n"
        config_content+="[[routing.rules]]\n"
        config_content+="type = \"field\"\n"
        config_content+="inboundTag = \"tag_$((i + 1))\"\n"
        config_content+="outboundTag = \"tag_$((i + 1))\"\n\n\n"
    done
    echo -e "$config_content" >/etc/xrayL/config.json
    systemctl restart xrayL.service
    systemctl --no-pager status xrayL.service
    echo ""
    echo "HTTP proxy configuration completed"
    echo "Starting port: $START_PORT"
    echo "Ending port: $((START_PORT + $i - 1))"
    echo ""
}

main() {
    [ -x "$(command -v xrayL)" ] || install_xray
    config_xray
}

main
