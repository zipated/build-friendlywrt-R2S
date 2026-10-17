#!/usr/bin/env bash
# 自定义脚本辅助函数。
# build.sh 在执行 custom-scripts/*.sh 前会 source 本文件。

: "${FRIENDLYWRT_DIR:?FRIENDLYWRT_DIR 未设置}"

# 向 feeds.conf 追加一行（自动去重）。
# 首次调用时会先从 feeds.conf.default 复制，避免丢掉默认 feed。
# 用法：add_feed_line 'src-git name https://example.com/repo.git;branch'
add_feed_line() {
    local line="$1"
    local file="$FRIENDLYWRT_DIR/feeds.conf"
    if [ ! -f "$file" ]; then
        cp "$FRIENDLYWRT_DIR/feeds.conf.default" "$file"
    fi
    grep -qxF "$line" "$file" 2>/dev/null || printf '%s\n' "$line" >>"$file"
}

# 添加 git feed。
# 用法：add_feed <名称> <仓库地址> [分支]
add_feed() {
    local name="$1"
    local url="$2"
    local branch="${3:-}"
    local line="src-git $name $url"
    [ -n "$branch" ] && line="$line;$branch"
    add_feed_line "$line"
}

# 向 friendlywrt/.config 追加配置项，最终由 make defconfig 展开。
# 用法：append_config 'CONFIG_PACKAGE_xxx=y' 'CONFIG_yyy=n'
append_config() {
    [ "$#" -gt 0 ] || return 0
    printf '%s\n' "$@" >>"$FRIENDLYWRT_DIR/.config"
}

# 克隆插件源码到 friendlywrt/package/custom/<目录名>。
# 用法：clone_package <仓库地址> [目录名] [分支]
clone_package() {
    local url="$1"
    local name="${2:-}"
    local branch="${3:-}"
    [ -n "$name" ] || name="$(basename "$url" .git)"
    local dest="$FRIENDLYWRT_DIR/package/custom/$name"
    if [ -d "$dest/.git" ]; then
        echo "插件已存在，跳过：$dest"
        return 0
    fi
    mkdir -p "$(dirname "$dest")"
    if [ -n "$branch" ]; then
        git clone --depth 1 --branch "$branch" "$url" "$dest"
    else
        git clone --depth 1 "$url" "$dest"
    fi
}

# 从标准输入写入 rootfs 覆盖文件（friendlywrt/files/<相对路径>）。
# 用法：add_rootfs_file etc/uci-defaults/99-custom-network 0755 <<'EOF'
add_rootfs_file() {
    local rel="$1"
    local mode="${2:-0644}"
    local dest="$FRIENDLYWRT_DIR/files/$rel"
    mkdir -p "$(dirname "$dest")"
    cat >"$dest"
    chmod "$mode" "$dest"
}
