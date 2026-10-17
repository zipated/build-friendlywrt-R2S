#!/usr/bin/env bash
# 克隆自定义插件源码到 friendlywrt/package/custom/，随固件一起编译。
# 本目录下的脚本按文件名顺序执行，可用多个脚本分别管理不同插件。
#
# 可用函数（来自 scripts/lib.sh）：
#   clone_package <仓库地址> [目录名] [分支]
#
# 通过环境变量批量克隆（可选，空格分隔，格式 URL[#分支]）：
#   CUSTOM_PACKAGE_REPOS="https://github.com/vernesong/OpenClash.git#master"
if [ -n "${CUSTOM_PACKAGE_REPOS:-}" ]; then
    for entry in $CUSTOM_PACKAGE_REPOS; do
        url="${entry%%#*}"
        branch=""
        [ "$entry" != "$url" ] && branch="${entry#*#}"
        clone_package "$url" "$(basename "$url" .git)" "$branch"
    done
fi

# 示例：克隆单个插件（克隆后还需在 30-custom-config.sh 中打开对应 CONFIG_PACKAGE_xxx）
# clone_package https://github.com/vernesong/OpenClash.git luci-app-openclash master
# clone_package https://github.com/sirpdboy/luci-app-netdata.git luci-app-netdata main
clone_package https://github.com/vernesong/OpenClash.git luci-app-openclash master
clone_package https://github.com/jerrykuku/luci-app-argon-config.git luci-app-argon-config master
clone_package https://github.com/EasyTier/luci-app-easytier.git luci-app-easytier main
