show_help() {
    case $1 in
    api | x25519 | tls | run | uuid | version)
        $is_core_bin help $1 ${@:2}
        ;;
    *)
        [[ $1 ]] && warn "未知选项 '$1'"
        msg "$is_sh_name script $is_sh_ver by $author"
        msg "Usage: $is_sh_name [options]... [args]... "
        msg
        help_info=(
            "基本:"
            "   v, version                                      显示当前版本"
            "   ip                                              返回当前主机的 IP"
            "   pbk                                             同等于 $is_sh_name generate reality-keypair"
            "   get-port                                        返回一个可用的端口"
            "   ss2022                                          返回一个可用于 Shadowsocks 2022 的密码\n"
            "一般:"
            "   a, add [protocol] [args... | auto]              添加配置"
            "       add anytls [port] [password] [domain]       添加 AnyTLS 配置"
            "       add mixed [port] [username] [password]      添加 Mixed 配置 (HTTP + SOCKS 混合入站)"
            "       add snell [port] [psk] [version]            添加 Snell 配置 (版本 5 或 6)"
            "       add shadowtls [port] [pass] [ver] [shake]   添加 ShadowTLS 配置 (版本 1/2/3, 需内层协议)"
            "       add naive [port] [username] [password] [domain]  添加 Naive 配置 (必须给域名申请证书, 客户端无法跳过校验)"
            "       [domain]                                    可选: 末尾加域名自动申请受信任证书 (其余协议自签即可, 仅 naive 必须)"
            "   cert [domain]                                   申请并复用受信任证书 (Caddy 自动续期)"
            "   relay [name] [args...]                         添加中转; 指定节点则直接修改, 否则创建独立中转"
            "   c, change [name] [option] [args... | auto]      更改配置"
            "   d, del [name]                                   删除配置**"
            "   i, info [name]                                  查看配置"
            "   client [name]                                   生成对应的 $is_core_name 客户端配置 (需 $is_core_name >= 1.13.0)"
            "   url [name]                                      URL 信息"
            "   log                                             查看日志"
            "更改:"
            "   full [name] [...]                               更改多个参数"
            "   id [name] [uuid | auto]                         更改 UUID"
            "   host [name] [domain]                            更改域名"
            "   port [name] [port | auto]                       更改端口"
            "   path [name] [path | auto]                       更改路径"
            "   passwd [name] [password | auto]                 更改密码"
            "   key [name] [Private key | atuo] [Public key]    更改密钥"
            "   method [name] [method | auto]                   更改加密方式"
            "   sni [name] [ ip | domain]                       更改 serverName"
            "   new [name] [...]                                更改协议"
            "   web [name] [domain]                             更改伪装网站\n"
            "进阶:"
            "   dns [...]                                       设置 DNS (1.14+ 自动使用新版格式)"
            "   dd, ddel [name...]                              删除多个配置**"
            "   fix [name]                                      修复一个配置"
            "   fix-all                                         修复全部配置"
            "   fix-caddyfile                                   修复 Caddyfile"
            "   fix-config.json                                 修复 config.json"
            "   import                                          导入 xray/v2ray 脚本配置\n"
            "管理:"
            "   un, uninstall                                   卸载"
            "   u, update [core | sh | caddy] [ver]             更新"
            "   U, update.sh                                    更新脚本"
            "   s, status                                       运行状态"
            "   start, stop, restart [caddy]                    启动, 停止, 重启"
            "   t, test                                         测试运行"
            "   reinstall                                       重装脚本\n"
            "测试:"
            "   debug [name]                                    显示一些 debug 信息, 仅供参考"
            "   gen [...]                                       同等于 add, 但只显示 JSON 内容, 不创建文件, 测试使用"
            "   no-auto-tls [...]                               同等于 add, 但禁止自动配置 TLS, 可用于 *TLS 相关协议"
            "其他:"
            "   bbr                                             启用 BBR, 如果支持"
            "   bin [...]                                       运行 $is_core_name 命令, 例如: $is_sh_name bin help"
            "   [...] [...]                                     兼容绝大多数的 $is_core_name 命令, 例如: $is_sh_name generate uuid"
            "   h, help                                         显示此帮助界面\n"
        )
        for v in "${help_info[@]}"; do
            msg "$v"
        done
        msg "谨慎使用 del, ddel, 此选项会直接删除配置; 无需确认"
        msg "反馈问题) $(msg_ul https://github.com/${is_sh_repo}/issues) "
        ;;
    esac
}
about() {
    msg
    msg "------------- 关于 -------------"
    msg "$is_sh_name script $is_sh_ver by $author"
    msg "$is_core_ver: $is_core_status"
    msg
    [[ $is_caddy ]] && {
        msg "Caddy $is_caddy_ver: $is_caddy_status"
        msg
    }
    msg "项目地址:"
    msg "https://github.com/${is_sh_repo}"
    msg
    msg "反馈问题:"
    msg "https://github.com/${is_sh_repo}/issues"
    msg
}