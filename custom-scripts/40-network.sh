#!/usr/bin/env bash
# 自定义 LAN / WAN / DNS 配置，通过 /etc/uci-defaults 在首次启动时生效。
# 本脚本通过环境变量工作，未设置的项不会被修改；也可以直接改成固定值。
#
# 可用变量：
#   LAN_IP / LAN_NETMASK / LAN_DNS
#   WAN_PROTO=dhcp|static / WAN_IP / WAN_NETMASK / WAN_GATEWAY
#
# 可用函数（来自 scripts/lib.sh）：
#   add_rootfs_file <相对路径> [权限]   （内容从标准输入读取）
#
# 说明：WAN_PROTO=static 时，WAN_IP 为空则不会切换协议，避免设备失联。

# LAN_IP="${LAN_IP:-}"
# LAN_NETMASK="${LAN_NETMASK:-}"
# LAN_DNS="${LAN_DNS:-}"
# WAN_PROTO="${WAN_PROTO:-none}"
# WAN_IP="${WAN_IP:-}"
# WAN_NETMASK="${WAN_NETMASK:-255.255.255.0}"
# WAN_GATEWAY="${WAN_GATEWAY:-}"

LAN_IP="${LAN_IP:-192.168.7.1}"
LAN_NETMASK="${LAN_NETMASK:-255.255.255.0}"
LAN_DNS="${LAN_DNS:-119.29.29.29,223.5.5.5}"
WAN_PROTO="${WAN_PROTO:-none}"
WAN_IP="${WAN_IP:-}"
WAN_NETMASK="${WAN_NETMASK:-255.255.255.0}"
WAN_GATEWAY="${WAN_GATEWAY:-}"

if [ "$WAN_PROTO" = "static" ] && [ -z "$WAN_IP" ]; then
    echo "WAN_PROTO=static 但未设置 WAN_IP，忽略静态 WAN 配置"
    WAN_PROTO="none"
fi

if [ -z "$LAN_IP$LAN_NETMASK$LAN_DNS$WAN_IP$WAN_GATEWAY" ] && [ "$WAN_PROTO" = "none" ]; then
    echo "未设置网络参数，跳过"
    exit 0
fi

{
    echo '#!/bin/sh'
    echo '# 由 custom-scripts/40-network.sh 在编译时生成'

    [ -n "$LAN_IP" ] && echo "uci -q set network.lan.ipaddr='$LAN_IP'"
    [ -n "$LAN_NETMASK" ] && echo "uci -q set network.lan.netmask='$LAN_NETMASK'"

    case "$WAN_PROTO" in
    static)
        echo "uci -q set network.wan.proto='static'"
        echo "uci -q set network.wan.ipaddr='$WAN_IP'"
        echo "uci -q set network.wan.netmask='$WAN_NETMASK'"
        [ -n "$WAN_GATEWAY" ] && echo "uci -q set network.wan.gateway='$WAN_GATEWAY'"
        ;;
    dhcp)
        echo "uci -q set network.wan.proto='dhcp'"
        ;;
    esac

    if [ -n "$LAN_DNS" ]; then
        dns_list="$(printf '%s' "$LAN_DNS" | tr ',' ' ' | tr -s ' ')"
        dns_csv="${dns_list// /,}"
        echo "uci -q set network.wan.peerdns='0'"
        echo 'uci -q delete network.wan.dns'
        for dns in $dns_list; do
            echo "uci -q add_list network.wan.dns='$dns'"
        done
        # 同时下发给 LAN DHCP 客户端
        echo 'uci -q delete dhcp.lan.dhcp_option'
        echo "uci -q add_list dhcp.lan.dhcp_option='6,$dns_csv'"
    fi

    echo 'uci commit network'
    echo 'uci commit dhcp'
    echo 'exit 0'
} | add_rootfs_file etc/uci-defaults/99-custom-network 0755

echo "已写入 etc/uci-defaults/99-custom-network"
