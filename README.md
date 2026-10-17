# build-friendlywrt-R2S

在 GitHub Actions 上编译 NanoPi R2S / R2S Plus 的 FriendlyWrt 固件，并把产物上传到 Releases。

## 功能

- 编译环境：Ubuntu 24.04
- 产物：SD 卡镜像（`*_sd.img.gz`）、eMMC 刷机镜像（eflasher，`*_eflasher.img.gz`）
- 自动把本次最终使用的 `.config` 上传为 `config.txt`
- 将 feeds 中的 `git.openwrt.org` 源替换为 `github.com/openwrt`
- 支持自定义 feed / 插件 / 网络参数，多个脚本按文件名顺序配合

## 使用

在仓库 `Actions` 页手动触发~~，或推送 `v*` 标签触发~~。

手动触发常用输入：

| 输入 | 说明 |
|---|---|
| manifest_branch | 源码分支，默认 `master-v25.12` |
| board | 板型配置，默认 `rk3328.mk` |
| build_emmc | 是否同时生成 eMMC 刷机镜像 |
| release_tag | Release 标签，留空自动生成 |
| lan_ip / lan_netmask / lan_dns | LAN 地址、掩码、DNS |
| wan_proto / wan_ip / wan_gateway | WAN 协议与静态参数 |

## 目录结构

```
.config                          # 项目级 OpenWrt 配置，追加到厂商配置后
scripts/
  build.sh                       # 构建入口
  lib.sh                         # 自定义脚本辅助函数
custom-scripts/                  # 按文件名顺序执行的钩子
  10-custom-feeds.sh             # 自定义 feed
  20-custom-packages.sh          # 克隆额外插件
  30-custom-config.sh            # 追加 CONFIG_*
  40-network.sh                  # LAN / WAN / DNS
.github/workflows/build-friendlywrt.yml
```

## 自定义

### 添加 feed

编辑 `custom-scripts/10-custom-feeds.sh`：

```bash
add_feed kenzo https://github.com/kenzok8/small main
```

或通过环境变量 `CUSTOM_FEED_NAME` / `CUSTOM_FEED_URL` / `CUSTOM_FEED_BRANCH`。

### 克隆插件

编辑 `custom-scripts/20-custom-packages.sh`：

```bash
clone_package https://github.com/vernesong/OpenClash.git luci-app-openclash master
```

然后在 `30-custom-config.sh`：

```bash
append_config 'CONFIG_PACKAGE_luci-app-openclash=y'
```

### 网络参数

`40-network.sh` 通过环境变量工作，未设置的项不改动：

```bash
LAN_IP=192.168.2.1
LAN_DNS="223.5.5.5 119.29.29.29"
WAN_PROTO=dhcp
```

网络配置以 `/etc/uci-defaults/99-custom-network` 注入，首次启动生效。

## 其他

- 默认关闭厂商的 `CONFIG_ALL_KMODS` / `CONFIG_ALL_NONSHARED` 以缩短编译时间；需要全量内核模块时设置 `FULL_KMODS=1`。
- RK3328 没有独立的 USB 烧录镜像，刷 eMMC 使用 eflasher 镜像（写入 TF 卡启动后自动刷入 eMMC）。