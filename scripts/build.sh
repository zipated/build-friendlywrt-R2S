#!/usr/bin/env bash
# FriendlyWrt 构建入口，GitHub Actions 与本地 Linux 环境共用。
#
# 用法：
#   bash scripts/build.sh [prepare|download|firmware|images|collect|all]
#
# 各阶段（workflow 中分开执行，便于缓存下载与 ccache）：
#   prepare  : repo 同步源码 -> 替换 feeds 源 -> 组装 .config -> 自定义脚本
#              -> feeds update/install -> make defconfig
#   download : make download，把源码包预下载到 work/friendlywrt/dl
#   firmware : 编译 u-boot / kernel / friendlywrt
#   images   : 生成 eMMC（eflasher）镜像
#   collect  : 压缩镜像、导出最终 .config 到 artifacts/
#   all      : 以上全部按顺序执行（本地一键构建）
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOP_DIR="${TOP_DIR:-$REPO_DIR/work}"
ARTIFACT_DIR="${ARTIFACT_DIR:-$REPO_DIR/artifacts}"

MANIFEST_URL="${MANIFEST_URL:-https://github.com/friendlyarm/friendlywrt_manifests}"
MANIFEST_BRANCH="${MANIFEST_BRANCH:-master-v25.12}"
MANIFEST_XML="${MANIFEST_XML:-rk3328.xml}"
REPO_TOOL_URL="${REPO_TOOL_URL:-https://github.com/friendlyarm/repo}"
BOARD="${BOARD:-rk3328.mk}"
VENDOR_CONFIG="${VENDOR_CONFIG:-rockchip}"
BUILD_EMMC="${BUILD_EMMC:-true}"
# 厂商配置默认打开 CONFIG_ALL_KMODS/CONFIG_ALL_NONSHARED，GitHub 托管 runner 编译时间不够，
# 默认关闭；需要全量内核模块时设置 FULL_KMODS=1。
FULL_KMODS="${FULL_KMODS:-0}"
# 默认启用 ccache，配合 workflow 中的缓存显著缩短重复编译时间
USE_CCACHE="${USE_CCACHE:-1}"
JOBS="${JOBS:-$(nproc)}"

FRIENDLYWRT_DIR="$TOP_DIR/friendlywrt"
VENDOR_CONFIG_DIR="$TOP_DIR/configs/$VENDOR_CONFIG"
CUSTOM_CONFIG_FILE="$REPO_DIR/.config"
REPO_TOOL="$TOP_DIR/.repo-tool/repo"

export REPO_DIR TOP_DIR ARTIFACT_DIR FRIENDLYWRT_DIR VENDOR_CONFIG_DIR CUSTOM_CONFIG_FILE
# 厂商镜像脚本遇缺失文件时会等待键盘输入，CI 中改为自动确认
export SDFUSE_NONINTERACTIVE="${SDFUSE_NONINTERACTIVE:-1}"
export GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-FriendlyWrt CI}"
export GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-friendlywrt-ci@users.noreply.github.com}"
export GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-$GIT_AUTHOR_NAME}"
export GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-$GIT_AUTHOR_EMAIL}"

if [ "$USE_CCACHE" = "1" ]; then
    export CCACHE_DIR="${CCACHE_DIR:-$HOME/.ccache}"
    export CCACHE_COMPRESS=1
    mkdir -p "$CCACHE_DIR"
fi

log() { printf '\033[1;32m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

feeds_file() {
    if [ -f "$FRIENDLYWRT_DIR/feeds.conf" ]; then
        printf '%s' "$FRIENDLYWRT_DIR/feeds.conf"
    else
        printf '%s' "$FRIENDLYWRT_DIR/feeds.conf.default"
    fi
}

download_sources() {
    log "同步源码：$MANIFEST_BRANCH / $MANIFEST_XML"
    mkdir -p "$TOP_DIR"
    if [ ! -x "$REPO_TOOL" ]; then
        rm -rf "$TOP_DIR/.repo-tool"
        git clone --depth 1 "$REPO_TOOL_URL" "$TOP_DIR/.repo-tool"
        chmod +x "$REPO_TOOL"
    fi

    (
        cd "$TOP_DIR"
        "$REPO_TOOL" init --depth=1 \
            -u "$MANIFEST_URL" \
            -b "$MANIFEST_BRANCH" \
            -m "$MANIFEST_XML" \
            --repo-url="$REPO_TOOL_URL" \
            --no-clone-bundle

        local attempt
        for attempt in 1 2 3; do
            if "$REPO_TOOL" sync -c --no-clone-bundle -j"$JOBS" --optimized-fetch; then
                exit 0
            fi
            warn "repo sync 失败（第 $attempt 次），10 秒后重试"
            sleep 10
        done
        exit 1
    ) || die "repo sync 失败"

    [ -d "$FRIENDLYWRT_DIR" ] || die "未找到 $FRIENDLYWRT_DIR"
    find "$TOP_DIR/device/friendlyelec" -name "$BOARD" -print -quit | grep -q . \
        || die "未找到板型配置 $BOARD"
}

rewrite_feeds() {
    local file
    file="$(feeds_file)"
    [ -f "$file" ] || die "未找到 feeds.conf.default"

    log "替换 feeds 源：git.openwrt.org -> github.com/openwrt"
    for file in "$FRIENDLYWRT_DIR/feeds.conf" "$FRIENDLYWRT_DIR/feeds.conf.default"; do
        [ -f "$file" ] || continue
        sed -i -E \
            -e 's#(git|https?)://git\.openwrt\.org/feed/#https://github.com/openwrt/#g' \
            -e 's#(git|https?)://git\.openwrt\.org/project/luci\.git#https://github.com/openwrt/luci.git#g' \
            "$file"
        if grep -q 'git\.openwrt\.org' "$file"; then
            warn "$(basename "$file") 中仍存在 git.openwrt.org 源："
            grep 'git\.openwrt\.org' "$file" || true
        fi
    done
}

prepare_config() {
    [ -d "$VENDOR_CONFIG_DIR" ] || die "未找到厂商配置目录 $VENDOR_CONFIG_DIR"

    log "组装 .config：$VENDOR_CONFIG/* + 项目 .config"
    : >"$FRIENDLYWRT_DIR/.config"
    local f
    for f in "$VENDOR_CONFIG_DIR"/*; do
        [ -f "$f" ] || continue
        cat "$f" >>"$FRIENDLYWRT_DIR/.config"
    done

    if [ "$FULL_KMODS" != "1" ]; then
        sed -i -E '/^CONFIG_ALL_KMODS=/d; /^CONFIG_ALL_NONSHARED=/d' "$FRIENDLYWRT_DIR/.config"
    fi

    if [ -f "$CUSTOM_CONFIG_FILE" ]; then
        printf '\n# ===== 项目 .config =====\n' >>"$FRIENDLYWRT_DIR/.config"
        cat "$CUSTOM_CONFIG_FILE" >>"$FRIENDLYWRT_DIR/.config"
    else
        warn "项目根目录没有 .config，仅使用厂商配置"
    fi

    if [ "$USE_CCACHE" = "1" ]; then
        printf '\nCONFIG_CCACHE=y\n' >>"$FRIENDLYWRT_DIR/.config"
        log "已启用 ccache：$CCACHE_DIR"
    fi
}

run_custom_scripts() {
    shopt -s nullglob
    local scripts=("$REPO_DIR"/custom-scripts/*.sh)
    if [ "${#scripts[@]}" -eq 0 ]; then
        log "未找到 custom-scripts/*.sh，跳过自定义配置"
        return 0
    fi

    local script
    for script in "${scripts[@]}"; do
        log "执行自定义脚本：$(basename "$script")"
        (
            set -euo pipefail
            source "$REPO_DIR/scripts/lib.sh"
            # shellcheck source=/dev/null
            source "$script"
        ) || die "自定义脚本执行失败：$(basename "$script")"
    done
}

update_feeds() {
    log "更新并安装 feeds"
    local attempt
    for attempt in 1 2 3; do
        if (
            cd "$FRIENDLYWRT_DIR"
            ./scripts/feeds update -a
            ./scripts/feeds install -a
        ); then
            return 0
        fi
        warn "feeds 更新失败（第 $attempt 次），10 秒后重试"
        sleep 10
    done
    die "feeds 更新失败"
}

expand_config() {
    log "展开配置：make defconfig"
    (
        cd "$FRIENDLYWRT_DIR"
        make defconfig
    ) || die "make defconfig 失败"
    grep -q '^CONFIG_TARGET_rockchip=y' "$FRIENDLYWRT_DIR/.config" \
        || die "最终 .config 缺少 rockchip 目标配置"
}

download_packages() {
    log "预下载源码包：make download -j$JOBS"
    (
        cd "$FRIENDLYWRT_DIR"
        make download -j"$JOBS"
    ) || {
        warn "部分源码包下载失败，串行重试一次"
        (
            cd "$FRIENDLYWRT_DIR"
            make download -j1 V=s
        ) || warn "make download 仍有失败项，编译阶段会再次尝试下载"
    }
}

build_firmware() {
    log "开始编译 FriendlyWrt（BOARD=$BOARD）"
    (
        cd "$TOP_DIR"
        ./build.sh "$BOARD"
    ) || die "FriendlyWrt 编译失败"
}

build_images() {
    case "${BUILD_EMMC,,}" in
    true | 1 | yes | y)
        log "生成 eMMC 刷机镜像（eflasher）"
        (
            cd "$TOP_DIR"
            # 缺少 eflasher 预置文件时自动确认下载，避免 CI 中交互式等待
            SDFUSE_NONINTERACTIVE=1 ./build.sh emmc-img
        ) || die "eMMC 镜像生成失败"
        ;;
    *)
        log "BUILD_EMMC=$BUILD_EMMC，跳过 eMMC 镜像"
        ;;
    esac
}

collect_artifacts() {
    log "收集并压缩产物"
    rm -rf "${ARTIFACT_DIR:?}"
    mkdir -p "$ARTIFACT_DIR"

    shopt -s nullglob
    local images=("$TOP_DIR"/out/*.img)
    [ "${#images[@]}" -gt 0 ] || die "$TOP_DIR/out 下没有镜像文件"

    local compressor=(gzip -9 -c)
    if command -v pigz >/dev/null 2>&1; then
        compressor=(pigz -9 -c)
    fi

    local img base
    for img in "${images[@]}"; do
        base="$(basename "$img")"
        if [ -f "$img.gz" ]; then
            cp -f "$img.gz" "$ARTIFACT_DIR/$base.gz"
        else
            log "压缩 $base"
            "${compressor[@]}" "$img" >"$ARTIFACT_DIR/$base.gz"
        fi
    done

    # eMMC 刷机助手使用的系统升级包（mk-emmc-image.sh 生成）
    local pkg
    for pkg in "$TOP_DIR"/out/images-for-eflasher/*.tgz; do
        cp -f "$pkg" "$ARTIFACT_DIR/"
    done

    cp -f "$FRIENDLYWRT_DIR/.config" "$ARTIFACT_DIR/config.txt"

    log "产物列表："
    ls -lh "$ARTIFACT_DIR"
}

usage() {
    cat <<'EOF'
用法: bash scripts/build.sh [阶段]

阶段:
  prepare    同步源码、替换 feeds 源、组装 .config、执行 custom-scripts、feeds 与 defconfig
  download   make download，预下载源码包到 work/friendlywrt/dl
  firmware   编译 u-boot / kernel / friendlywrt
  images     生成 eMMC（eflasher）镜像
  collect    压缩镜像、导出 config.txt 到 artifacts/
  all        依次执行以上全部阶段（默认）
EOF
}

stage_prepare() {
    log "MANIFEST_BRANCH=$MANIFEST_BRANCH MANIFEST_XML=$MANIFEST_XML BOARD=$BOARD BUILD_EMMC=$BUILD_EMMC FULL_KMODS=$FULL_KMODS"
    download_sources
    rewrite_feeds
    prepare_config
    run_custom_scripts
    update_feeds
    expand_config
}

main() {
    local stage="${1:-all}"
    case "$stage" in
    prepare) stage_prepare ;;
    download) download_packages ;;
    firmware) build_firmware ;;
    images) build_images ;;
    collect) collect_artifacts ;;
    all)
        stage_prepare
        download_packages
        build_firmware
        build_images
        collect_artifacts
        log "全部完成"
        ;;
    -h | --help | help)
        usage
        ;;
    *)
        die "未知阶段：$stage（可用：prepare download firmware images collect all）"
        ;;
    esac
}

main "$@"
