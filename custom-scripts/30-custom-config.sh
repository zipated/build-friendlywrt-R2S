#!/usr/bin/env bash
# 追加/覆盖 OpenWrt 编译配置项。
# 这些配置会加到 friendlywrt/.config 末尾，随后由 make defconfig 展开。
# 本目录下的脚本按文件名顺序执行，可拆成多个脚本管理不同功能。
#
# 可用函数（来自 scripts/lib.sh）：
#   append_config 'CONFIG_...=y' 'CONFIG_...=n'
#
# 通过环境变量追加（可选，空格分隔）：
#   EXTRA_CONFIG="CONFIG_PACKAGE_luci-app-openclash=y CONFIG_PACKAGE_kmod-tun=y"
if [ -n "${EXTRA_CONFIG:-}" ]; then
    # shellcheck disable=SC2086
    append_config ${EXTRA_CONFIG}
fi

# 示例：配合 20-custom-packages.sh 打开克隆进来的插件
# append_config \
#     'CONFIG_PACKAGE_luci-app-openclash=y' \
#     'CONFIG_PACKAGE_kmod-tun=y'

append_config \
    'CONFIG_PACKAGE_zram-swap=y' \
    \
    'CONFIG_PACKAGE_kmod-ipt-nat6=y' \
    'CONFIG_PACKAGE_kmod-nf-nat6=y' \
    'CONFIG_PACKAGE_kmod-inet-diag=y' \
    'CONFIG_PACKAGE_kmod-zram=y' \
    'CONFIG_PACKAGE_kmod-usb-net-rndis=y' \
    'CONFIG_PACKAGE_kmod-usb-serial=y' \
    'CONFIG_PACKAGE_kmod-usb-serial-option=y' \
    'CONFIG_PACKAGE_kmod-usb-serial-wwan=y' \
    \
    'CONFIG_PACKAGE_perl=y' \
    'CONFIG_PERL_THREADS=y' \
    'CONFIG_PERL_NOCOMMENT=y' \
    'CONFIG_PACKAGE_perlbase-base=y' \
    'CONFIG_PACKAGE_perlbase-bytes=y' \
    'CONFIG_PACKAGE_perlbase-class=y' \
    'CONFIG_PACKAGE_perlbase-config=y' \
    'CONFIG_PACKAGE_perlbase-dynaloader=y' \
    'CONFIG_PACKAGE_perlbase-errno=y' \
    'CONFIG_PACKAGE_perlbase-essential=y' \
    'CONFIG_PACKAGE_perlbase-fcntl=y' \
    'CONFIG_PACKAGE_perlbase-filehandle=y' \
    'CONFIG_PACKAGE_perlbase-getopt=y' \
    'CONFIG_PACKAGE_perlbase-io=y' \
    'CONFIG_PACKAGE_perlbase-list=y' \
    'CONFIG_PACKAGE_perlbase-net=y' \
    'CONFIG_PACKAGE_perlbase-posix=y' \
    'CONFIG_PACKAGE_perlbase-scalar=y' \
    'CONFIG_PACKAGE_perlbase-selectsaver=y' \
    'CONFIG_PACKAGE_perlbase-socket=y' \
    'CONFIG_PACKAGE_perlbase-symbol=y' \
    'CONFIG_PACKAGE_perlbase-tie=y' \
    'CONFIG_PACKAGE_perlbase-time=y' \
    'CONFIG_PACKAGE_perlbase-xsloader=y' \
    \
    'CONFIG_PACKAGE_ruby=y' \
    'CONFIG_RUBY_ENABLE_YJIT=y' \
    'CONFIG_PACKAGE_ruby-bigdecimal=y' \
    'CONFIG_PACKAGE_ruby-date=y' \
    'CONFIG_PACKAGE_ruby-digest=y' \
    'CONFIG_PACKAGE_ruby-enc=y' \
    'CONFIG_PACKAGE_ruby-pstore=y' \
    'CONFIG_PACKAGE_ruby-psych=y' \
    'CONFIG_PACKAGE_ruby-stringio=y' \
    'CONFIG_PACKAGE_ruby-yaml=y' \
    \
    'CONFIG_PACKAGE_libyaml=y' \
    'CONFIG_PACKAGE_libruby=y' \
    \
    'CONFIG_PACKAGE_luci-mod-rpc=y' \
    'CONFIG_PACKAGE_luci-app-argon-config=y' \
    'CONFIG_PACKAGE_luci-app-easytier=y' \
    'CONFIG_PACKAGE_luci-app-openclash=y' \
    'CONFIG_PACKAGE_luci-app-wol=y' \
    \
    'CONFIG_PACKAGE_luci-lib-json=y' \
    \
    'CONFIG_PACKAGE_luci-i18n-argon-config-es=y' \
    'CONFIG_PACKAGE_luci-i18n-argon-config-ru=y' \
    'CONFIG_PACKAGE_luci-i18n-argon-config-zh-cn=y' \
    'CONFIG_PACKAGE_luci-i18n-argon-config-zh-tw=y' \
    'CONFIG_PACKAGE_luci-i18n-easytier-zh-cn=y' \
    'CONFIG_PACKAGE_luci-i18n-wol-bg=y' \
    'CONFIG_PACKAGE_luci-i18n-wol-ca=y' \
    'CONFIG_PACKAGE_luci-i18n-wol-cs=y' \
    'CONFIG_PACKAGE_luci-i18n-wol-de=y' \
    'CONFIG_PACKAGE_luci-i18n-wol-el=y' \
    'CONFIG_PACKAGE_luci-i18n-wol-es=y' \
    'CONFIG_PACKAGE_luci-i18n-wol-fr=y' \
    'CONFIG_PACKAGE_luci-i18n-wol-he=y' \
    'CONFIG_PACKAGE_luci-i18n-wol-hi=y' \
    'CONFIG_PACKAGE_luci-i18n-wol-hu=y' \
    'CONFIG_PACKAGE_luci-i18n-wol-it=y' \
    'CONFIG_PACKAGE_luci-i18n-wol-ja=y' \
    'CONFIG_PACKAGE_luci-i18n-wol-ko=y' \
    'CONFIG_PACKAGE_luci-i18n-wol-mr=y' \
    'CONFIG_PACKAGE_luci-i18n-wol-ms=y' \
    'CONFIG_PACKAGE_luci-i18n-wol-pl=y' \
    'CONFIG_PACKAGE_luci-i18n-wol-pt=y' \
    'CONFIG_PACKAGE_luci-i18n-wol-pt-br=y' \
    'CONFIG_PACKAGE_luci-i18n-wol-ro=y' \
    'CONFIG_PACKAGE_luci-i18n-wol-ru=y' \
    'CONFIG_PACKAGE_luci-i18n-wol-sk=y' \
    'CONFIG_PACKAGE_luci-i18n-wol-sv=y' \
    'CONFIG_PACKAGE_luci-i18n-wol-tr=y' \
    'CONFIG_PACKAGE_luci-i18n-wol-uk=y' \
    'CONFIG_PACKAGE_luci-i18n-wol-vi=y' \
    'CONFIG_PACKAGE_luci-i18n-wol-zh-cn=y' \
    'CONFIG_PACKAGE_luci-i18n-wol-zh-tw=y' \
    \
    'CONFIG_PACKAGE_ip6tables-mod-nat=y' \
    'CONFIG_PACKAGE_etherwake=y' \
    'CONFIG_PACKAGE_wakeonlan=y'
