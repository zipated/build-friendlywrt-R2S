#!/usr/bin/env bash
# 自定义 feed 配置。
# 本目录下的脚本按文件名顺序执行，可新增 11-*.sh、12-*.sh 等配合使用。
#
# 可用函数（来自 scripts/lib.sh）：
#   add_feed <名称> <仓库地址> [分支]
#   add_feed_line '<完整的 feeds.conf 行>'
#
# 通过环境变量追加一个 feed（可选）：
#   CUSTOM_FEED_NAME / CUSTOM_FEED_URL / CUSTOM_FEED_BRANCH
if [ -n "${CUSTOM_FEED_URL:-}" ]; then
    add_feed "${CUSTOM_FEED_NAME:-custom}" "$CUSTOM_FEED_URL" "${CUSTOM_FEED_BRANCH:-}"
fi

# 示例：追加第三方 feed
# add_feed kenzo https://github.com/kenzok8/small main
# add_feed_line 'src-git passwall https://github.com/xiaorouji/openwrt-passwall.git;main'
