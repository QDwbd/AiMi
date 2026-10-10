#!/bin/bash

protocol_list=(
    TUIC
    Trojan
    Hysteria2
    VMess-WS
    VMess-TCP
    VMess-HTTP
    VMess-QUIC
    Shadowsocks
    VMess-H2-TLS
    VMess-WS-TLS
    VLESS-H2-TLS
    VLESS-WS-TLS
    Trojan-H2-TLS
    Trojan-WS-TLS
    VMess-HTTPUpgrade-TLS
    VLESS-HTTPUpgrade-TLS
    Trojan-HTTPUpgrade-TLS
    VLESS-REALITY
    VLESS-HTTP2-REALITY
    Socks
    AnyTLS
    Mixed
    Snell
    ShadowTLS
    Naive
)
ss_method_list=(
    aes-128-gcm
    aes-256-gcm
    chacha20-ietf-poly1305
    xchacha20-ietf-poly1305
    2022-blake3-aes-128-gcm
    2022-blake3-aes-256-gcm
    2022-blake3-chacha20-poly1305
)
mainmenu=(
    "添加配置"
    "添加中转节点"
    "更改配置"
    "查看配置"
    "删除配置"
    "运行管理"
    "更新"
    "卸载"
    "帮助"
    "其他"
    "关于"
)
info_list=(
    "协议 (protocol)"
    "地址 (address)"
    "端口 (port)"
    "用户ID (id)"
    "传输协议 (network)"
    "伪装类型 (type)"
    "伪装域名 (host)"
    "路径 (path)"
    "传输层安全 (TLS)"
    "应用层协议协商 (Alpn)"
    "密码 (password)"
    "加密方式 (encryption)"
    "链接 (URL)"
    "目标地址 (remote addr)"
    "目标端口 (remote port)"
    "流控 (flow)"
    "SNI (serverName)"
    "指纹 (Fingerprint)"
    "公钥 (Public key)"
    "用户名 (Username)"
    "跳过证书验证 (allowInsecure)"
    "拥塞控制算法 (congestion_control)"
    "版本 (version)"
)
change_list=(
    "更改协议"
    "更改端口"
    "更改域名"
    "更改路径"
    "更改密码"
    "更改 UUID"
    "更改加密方式"
    "更改目标地址"
    "更改目标端口"
    "更改密钥"
    "更改 SNI (serverName)"
    "更改伪装网站"
    "更改用户名 (Username)"
)
servername_list=(
    www.amazon.com
    www.ebay.com
    www.paypal.com
    www.cloudflare.com
    dash.cloudflare.com
    aws.amazon.com
)
is_random_ss_method=${ss_method_list[$(shuf -i 4-6 -n1)]}
random_index=$(shuf -i 0-$((${#servername_list[@]} - 1)) -n1)
is_random_servername=${servername_list[$random_index]}

ver_ge() {
    local is_ver_i is_ver_a is_ver_b
    local -a is_ver_v1=(${1//./ }) is_ver_v2=(${2//./ })
    for is_ver_i in 0 1 2; do
        is_ver_a=${is_ver_v1[is_ver_i]:-0}
        is_ver_b=${is_ver_v2[is_ver_i]:-0}
        is_ver_a=${is_ver_a#"${is_ver_a%%[0-9]*}"}
        is_ver_b=${is_ver_b#"${is_ver_b%%[0-9]*}"}
        is_ver_a=${is_ver_a%%[!0-9]*}
        is_ver_b=${is_ver_b%%[!0-9]*}
        [[ -z $is_ver_a ]] && is_ver_a=0
        [[ -z $is_ver_b ]] && is_ver_b=0
        ((10#$is_ver_a > 10#$is_ver_b)) && return 0
        ((10#$is_ver_a < 10#$is_ver_b)) && return 1
    done
    return 0
}

[[ ! $is_core_ver && -x $is_core_bin ]] && is_core_ver=$($is_core_bin version 2>/dev/null | head -n1 | egrep -o '[0-9]+\.[0-9]+\.[0-9]+[^ ]*' | head -n1)

unset is_new_dns
ver_ge "${is_core_ver:-0}" 1.14.0 && is_new_dns=1



if [[ ! $is_listen_addr ]]; then
    is_listen_addr='::'
    if [[ ! -r /proc/sys/net/ipv6/conf/all/disable_ipv6 ]]; then
        is_listen_addr='0.0.0.0'
    elif [[ $(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null) == 1 ]]; then
        is_listen_addr='0.0.0.0'
    elif [[ $(cat /proc/sys/net/ipv6/bindv6only 2>/dev/null) == 1 ]]; then
        is_listen_addr='0.0.0.0'
    fi
fi
msg() {
    echo -e "$@"
}
msg_ul() {
    echo -e "\e[4m$@\e[0m"
}
pause() {
    echo
    echo -ne "按 $(_green Enter 回车键) 继续, 或按 $(_red Ctrl + C) 取消."
    read -rs -d $'\n'
    echo
}
get_uuid() {
    tmp_uuid=$(cat /proc/sys/kernel/random/uuid)
}
get_ip() {
    [[ $ip || $is_no_auto_tls || $is_gen || $is_dont_get_ip ]] && return
    local ip_line
    ip_line=$(_wget -4 -qO- https://one.one.one.one/cdn-cgi/trace 2>/dev/null | sed -n 's/^ip=//p' | head -n1)
    [[ -z $ip_line ]] && ip_line=$(_wget -6 -qO- https://one.one.one.one/cdn-cgi/trace 2>/dev/null | sed -n 's/^ip=//p' | head -n1)
    [[ $ip_line ]] && ip=$ip_line
    [[ ! $ip ]] && {
        err "获取服务器 IP 失败.."
    }
}
url_addr() {
    [[ $1 == *:* && $1 != \[*\] ]] && echo "[$1]" || echo "$1"
}
get_port() {
    is_count=0
    while :; do
        ((is_count++))
        if [[ $is_count -ge 200 ]]; then
            err "自动获取可用端口失败次数达到 200 次, 请检查端口占用情况."
        fi
        tmp_port=$(shuf -i 445-65535 -n 1)
        [[ ! $(is_test port_used $tmp_port) && $tmp_port != $port ]] && break
    done
}
get_pbk() {
    is_tmp_pbk=($($is_core_bin generate reality-keypair | sed 's/.*://'))
    is_public_key=${is_tmp_pbk[1]}
    is_private_key=${is_tmp_pbk[0]}
}
show_list() {
    PS3=''
    COLUMNS=1
    select i in "$@"; do echo; done &
    wait
}
is_test() {
    case $1 in
    number)
        echo $2 | egrep '^[1-9][0-9]?+$'
        ;;
    port)
        if [[ $(is_test number $2) ]]; then
            [[ $2 -le 65535 ]] && echo ok
        fi
        ;;
    port_used)
        [[ $(is_port_used $2) && ! $is_cant_test_port ]] && echo ok
        ;;
    domain)
        echo $2 | egrep -i '^\w(\w|\-|\.)?+\.\w+$'
        ;;
    path)
        echo $2 | egrep -i '^\/\w(\w|\-|\/)?+\w$'
        ;;
    uuid)
        echo $2 | egrep -i '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
        ;;
    esac
}
is_port_used() {
    if [[ $(type -P netstat) ]]; then
        [[ ! $is_used_port ]] && is_used_port="$(netstat -tunlp | sed -n 's/.*:\([0-9]\+\).*/\1/p' | sort -nu)"
        echo $is_used_port | sed 's/ /\n/g' | grep ^${1}$
        return
    fi
    if [[ $(type -P ss) ]]; then
        [[ ! $is_used_port ]] && is_used_port="$(ss -tunlp | sed -n 's/.*:\([0-9]\+\).*/\1/p' | sort -nu)"
        echo $is_used_port | sed 's/ /\n/g' | grep ^${1}$
        return
    fi
    is_cant_test_port=1
    msg "$is_warn 无法检测端口是否可用."
    msg "请执行: $(_yellow "${cmd} update -y; ${cmd} install net-tools -y") 来修复此问题."
}
ask() {
    case $1 in
    set_ss_method)
        is_tmp_list=(${ss_method_list[@]})
        is_default_arg=$is_random_ss_method
        is_opt_msg="\n请选择加密方式:\n"
        is_opt_input_msg="(默认\e[92m $is_default_arg\e[0m):"
        is_ask_set=ss_method
        ;;
    set_protocol)
        is_tmp_list=(${protocol_list[@]})
        [[ $is_no_auto_tls ]] && {
            unset is_tmp_list
            for v in ${protocol_list[@]}; do
                [[ ${v,,} == 'shadowtls' ]] && continue
                [[ $(grep -i tls$ <<<$v) ]] && is_tmp_list=(${is_tmp_list[@]} $v)
            done
        }
        is_opt_msg="\n请选择协议:\n"
        is_ask_set=is_new_protocol
        ;;
    set_change_list)
        is_tmp_list=()
        for v in ${is_can_change[@]}; do
            is_tmp_list+=("${change_list[$v]}")
        done
        is_opt_msg="\n请选择更改:\n"
        is_ask_set=is_change_str
        is_opt_input_msg=$3
        ;;
    string)
        is_ask_set=$2
        is_opt_input_msg=$3
        ;;
    list)
        is_ask_set=$2
        [[ ! $is_tmp_list ]] && is_tmp_list=($3)
        is_opt_msg=$4
        is_opt_input_msg=$5
        ;;
    get_config_file)
        is_tmp_list=("${is_all_json[@]}")
        is_opt_msg="\n请选择配置:\n"
        is_ask_set=is_config_file
        ;;
    mainmenu)
        is_tmp_list=("${mainmenu[@]}")
        is_ask_set=is_main_pick
        is_emtpy_exit=1
        ;;
    esac
    msg $is_opt_msg
    [[ ! $is_opt_input_msg ]] && is_opt_input_msg="请选择 [\e[91m1-${#is_tmp_list[@]}\e[0m]:"
    [[ $is_tmp_list ]] && show_list "${is_tmp_list[@]}"
    while :; do
        echo -ne $is_opt_input_msg
        read REPLY
        [[ ! $REPLY && $is_emtpy_exit ]] && exit
        [[ ! $REPLY && $is_default_arg ]] && export $is_ask_set=$is_default_arg && break
        [[ "$REPLY" == "${is_str}2${is_get}3${is_opt}3" && $is_ask_set == 'is_main_pick' ]] && {
            msg "\n${is_get}2${is_str}3${is_msg}3b${is_tmp}o${is_opt}y\n" && exit
        }
        if [[ ! $is_tmp_list ]]; then
            [[ $(grep port <<<$is_ask_set) ]] && {
                [[ ! $(is_test port "$REPLY") ]] && {
                    msg "$is_err 请输入正确的端口, 可选(1-65535)"
                    continue
                }
                if [[ $(is_test port_used $REPLY) && $is_ask_set != 'door_port' ]]; then
                    msg "$is_err 无法使用 ($REPLY) 端口."
                    continue
                fi
            }
            [[ $(grep path <<<$is_ask_set) && ! $(is_test path "$REPLY") ]] && {
                [[ ! $tmp_uuid ]] && get_uuid
                msg "$is_err 请输入正确的路径, 例如: /$tmp_uuid"
                continue
            }
            [[ $(grep uuid <<<$is_ask_set) && ! $(is_test uuid "$REPLY") ]] && {
                [[ ! $tmp_uuid ]] && get_uuid
                msg "$is_err 请输入正确的 UUID, 例如: $tmp_uuid"
                continue
            }
            [[ $(grep ^y$ <<<$is_ask_set) ]] && {
                [[ $(grep -i ^y$ <<<"$REPLY") ]] && break
                msg "请输入 (y)"
                continue
            }
            [[ $REPLY ]] && export $is_ask_set=$REPLY && msg "使用: ${!is_ask_set}" && break
        else
            [[ $(is_test number "$REPLY") ]] && is_ask_result=${is_tmp_list[$REPLY - 1]}
            [[ $is_ask_result ]] && export $is_ask_set="$is_ask_result" && msg "选择: ${!is_ask_set}" && break
        fi
        msg "输入${is_err}"
    done
    unset is_opt_msg is_opt_input_msg is_tmp_list is_ask_result is_default_arg is_emtpy_exit
}
create() {
    case $1 in
    server)
        is_tls=none
        get new
        is_listen='listen: "'$is_listen_addr'"'
        if [[ $host ]]; then
            is_config_name=$2-${host}.json


            [[ ! $(grep -E '^(trojan|hysteria2|tuic|anytls|naive|snell|shadowtls)$' <<<${2,,}) && ! $(grep -i quic <<<${2,,}) ]] && is_listen='listen: "127.0.0.1"'
        else
            is_config_name=$2-${port}.json
        fi
        is_json_file=$is_conf_dir/$is_config_name
        [[ $is_change || ! $json_str ]] && get protocol $2
        [[ $net == "reality" ]] && is_add_public_key=",outbounds:[{type:\"direct\"},{tag:\"public_key_$is_public_key\",type:\"direct\"}]"
        is_new_json=$(jq "{inbounds:[{tag:\"$is_config_name\",type:\"$is_protocol\",$is_listen,listen_port:$port,$json_str}]$is_add_public_key}" <<<{})
        [[ $is_test_json ]] && return
        [[ $is_gen ]] && {
            msg
            jq <<<$is_new_json
            msg
            return
        }
        [[ $is_config_file ]] && is_no_del_msg=1 && del $is_config_file
        cat <<<$is_new_json >$is_json_file
        if [[ $is_new_install ]]; then
            create config.json
        fi
        if [[ $is_caddy && $host && ! $is_no_auto_tls ]]; then
            if [[ $(grep -i quic <<<$net) ]]; then

                warn "QUIC 传输无法由 Caddy 终结 TLS, 已跳过 Caddy, 节点自带(自签)证书公网监听; 客户端需跳过证书校验."
            else
                create caddy $net
            fi
        fi
        manage restart &
        ;;
    client)
        is_client=1
        get info $2
        get client-json
        [[ ! $is_client_id_json ]] && err "($is_config_name) 不支持生成客户端配置."
        is_new_json=$(jq "{outbounds:[{tag:\"$is_config_name\",type:\"$is_client_type\",$is_client_id_json$is_stream}]}" <<<{})
        msg "\n------------- $is_config_name & 客户端配置 (AiMi) -------------"
        msg
        jq <<<$is_new_json
        msg
        ;;
    caddy)
        load caddy.sh
        [[ $is_install_caddy ]] && caddy_config new
        [[ ! $(grep "$is_caddy_conf" $is_caddyfile) ]] && {
            msg "import $is_caddy_conf/*.conf" >>$is_caddyfile
        }
        [[ ! -d $is_caddy_conf ]] && mkdir -p $is_caddy_conf
        caddy_config $2
        manage restart caddy &
        ;;
    config.json)
        is_log='log:{output:"/var/log/'$is_core'/access.log",level:"info","timestamp":true}'
        is_dns_route=
        if [[ $is_new_dns ]]; then


            is_dns='dns:{servers:[{type:"local",tag:"local",prefer_go:true}]}'
            is_dns_route='route:{default_domain_resolver:"local"},'
        else
            is_dns='dns:{}'
        fi
        is_ntp='ntp:{"enabled":true,"server":"time.apple.com"},'
        if [[ -f $is_config_json ]]; then
            [[ $(jq .ntp.enabled $is_config_json) != "true" ]] && is_ntp=
        else
            [[ ! $is_ntp_on ]] && is_ntp=
        fi
        is_outbounds='outbounds:[{tag:"direct",type:"direct"}]'
        is_server_config_json=$(jq "{$is_log,$is_dns,$is_ntp${is_dns_route}$is_outbounds}" <<<{})
        cat <<<$is_server_config_json >$is_config_json
        manage restart &
        ;;
    esac
}
change() {
    is_change=1
    is_dont_show_info=1
    if [[ $2 ]]; then
        case ${2,,} in
        full)
            is_change_id=full
            ;;
        new)
            is_change_id=0
            ;;
        port)
            is_change_id=1
            ;;
        host)
            is_change_id=2
            ;;
        path)
            is_change_id=3
            ;;
        pass | passwd | password)
            is_change_id=4
            ;;
        id | uuid)
            is_change_id=5
            ;;
        ssm | method | ss-method | ss_method)
            is_change_id=6
            ;;
        dda | door-addr | door_addr)
            is_change_id=7
            ;;
        ddp | door-port | door_port)
            is_change_id=8
            ;;
        key | publickey | privatekey)
            is_change_id=9
            ;;
        sni | servername | servernames)
            is_change_id=10
            ;;
        web | proxy-site)
            is_change_id=11
            ;;
        *)
            [[ $is_try_change ]] && return
            err "无法识别 ($2) 更改类型."
            ;;
        esac
    fi
    [[ $is_try_change ]] && return
    [[ $is_dont_auto_exit ]] && {
        get info $1
    } || {
        [[ $is_change_id ]] && {
            is_change_msg=${change_list[$is_change_id]}
            [[ $is_change_id == 'full' ]] && {
                [[ $3 ]] && is_change_msg="更改多个参数" || is_change_msg=
            }
            [[ $is_change_msg ]] && _green "\n快速执行: $is_change_msg"
        }
        info $1
        [[ $is_auto_get_config ]] && msg "\n自动选择: $is_config_file"
    }
    is_old_net=$net
    if [[ $(jq -r '.outbounds[0].server // empty' $is_conf_dir/$is_config_file 2>/dev/null) ]]; then
        warn "($is_config_file) 是中转节点配置, 不支持更改, 如需修改请删除后重新添加."
        return
    fi
    [[ $is_tcp_http ]] && net=http
    [[ $host ]] && net=$is_protocol-$net-tls
    [[ $is_reality && $net_type =~ 'http' ]] && net=rh2
    [[ $3 == 'auto' ]] && is_auto=1
    is_dont_show_info=
    [[ ! $is_change_id ]] && {
        ask set_change_list
        is_change_id=${is_can_change[$REPLY - 1]}
    }
    case $is_change_id in
    full)
        add $net ${@:3}
        ;;
    0)
        is_set_new_protocol=1
        add ${@:3}
        ;;
    1)
        is_new_port=$3
        [[ $host && ! $is_caddy ]] && err "($is_config_file) 不支持更改端口, 因为没啥意义."
        if [[ $is_new_port && ! $is_auto ]]; then
            [[ ! $(is_test port $is_new_port) ]] && err "请输入正确的端口, 可选(1-65535)"
            [[ $is_new_port != 443 && $(is_test port_used $is_new_port) ]] && err "无法使用 ($is_new_port) 端口"
        fi
        [[ $is_auto ]] && get_port && is_new_port=$tmp_port
        [[ ! $is_new_port ]] && ask string is_new_port "请输入新端口:"
        if [[ $is_caddy && $host ]]; then
            net=$is_old_net
            is_https_port=$is_new_port
            load caddy.sh
            caddy_config $net
            manage restart caddy &
            info
        else
            add $net $is_new_port
        fi
        ;;
    2)
        is_new_host=$3
        [[ ! $host ]] && err "($is_config_file) 不支持更改域名."
        [[ ! $is_new_host ]] && ask string is_new_host "请输入新域名:"
        old_host=$host
        add $net $is_new_host
        ;;
    3)
        is_new_path=$3
        [[ ! $path ]] && err "($is_config_file) 不支持更改路径."
        [[ $is_auto ]] && get_uuid && is_new_path=/$tmp_uuid
        [[ ! $is_new_path ]] && ask string is_new_path "请输入新路径:"
        add $net auto auto $is_new_path
        ;;
    4)
        is_new_pass=$3
        if [[ $ss_password || $password ]]; then
            [[ $is_auto ]] && {
                get_uuid && is_new_pass=$tmp_uuid
                [[ $ss_password ]] && is_new_pass=$(get ss2022)
            }
        else
            err "($is_config_file) 不支持更改密码."
        fi
        [[ ! $is_new_pass ]] && ask string is_new_pass "请输入新密码:"
        password=$is_new_pass
        ss_password=$is_new_pass
        is_socks_pass=$is_new_pass
        add $net
        ;;
    5)
        is_new_uuid=$3
        [[ ! $uuid ]] && err "($is_config_file) 不支持更改 UUID."
        [[ $is_auto ]] && get_uuid && is_new_uuid=$tmp_uuid
        [[ ! $is_new_uuid ]] && ask string is_new_uuid "请输入新 UUID:"
        add $net auto $is_new_uuid
        ;;
    6)
        is_new_method=$3
        [[ $net != 'ss' ]] && err "($is_config_file) 不支持更改加密方式."
        [[ $is_auto ]] && is_new_method=$is_random_ss_method
        [[ ! $is_new_method ]] && {
            ask set_ss_method
            is_new_method=$ss_method
        }
        add $net auto auto $is_new_method
        ;;
    7)
        is_new_door_addr=$3
        [[ $net != 'direct' ]] && err "($is_config_file) 不支持更改目标地址."
        [[ ! $is_new_door_addr ]] && ask string is_new_door_addr "请输入新的目标地址:"
        door_addr=$is_new_door_addr
        add $net
        ;;
    8)
        is_new_door_port=$3
        [[ $net != 'direct' ]] && err "($is_config_file) 不支持更改目标端口."
        [[ ! $is_new_door_port ]] && {
            ask string door_port "请输入新的目标端口:"
            is_new_door_port=$door_port
        }
        add $net auto auto $is_new_door_port
        ;;
    9)
        is_new_private_key=$3
        is_new_public_key=$4
        [[ ! $is_reality ]] && err "($is_config_file) 不支持更改密钥."
        if [[ $is_auto ]]; then
            get_pbk
            add $net
        else
            [[ $is_new_private_key && ! $is_new_public_key ]] && {
                err "无法找到 Public key."
            }
            [[ ! $is_new_private_key ]] && ask string is_new_private_key "请输入新 Private key:"
            [[ ! $is_new_public_key ]] && ask string is_new_public_key "请输入新 Public key:"
            if [[ $is_new_private_key == $is_new_public_key ]]; then
                err "Private key 和 Public key 不能一样."
            fi
            is_tmp_json=$is_conf_dir/$is_config_file-$uuid
            cp -f $is_conf_dir/$is_config_file $is_tmp_json
            sed -i s#$is_private_key #$is_new_private_key# $is_tmp_json
            $is_core_bin check -c $is_tmp_json &>/dev/null
            if [[ $? != 0 ]]; then
                is_key_err=1
                is_key_err_msg="Private key 无法通过测试."
            fi
            sed -i s#$is_new_private_key #$is_new_public_key# $is_tmp_json
            $is_core_bin check -c $is_tmp_json &>/dev/null
            if [[ $? != 0 ]]; then
                is_key_err=1
                is_key_err_msg+="Public key 无法通过测试."
            fi
            rm $is_tmp_json
            [[ $is_key_err ]] && err $is_key_err_msg
            is_private_key=$is_new_private_key
            is_public_key=$is_new_public_key
            is_test_json=
            add $net
        fi
        ;;
    10)
        is_new_servername=$3
        [[ ! $is_reality ]] && err "($is_config_file) 不支持更改 serverName."
        [[ $is_auto ]] && is_new_servername=$is_random_servername
        [[ ! $is_new_servername ]] && ask string is_new_servername "请输入新的 serverName:"
        is_servername=$is_new_servername
        [[ $(grep -i "^github.com$" <<<$is_servername) ]] && {
            err "墙啦"
        }
        add $net
        ;;
    11)
        is_new_proxy_site=$3
        [[ ! $is_caddy && ! $host ]] && {
            err "($is_config_file) 不支持更改伪装网站."
        }
        [[ ! -f $is_caddy_conf/${host}.conf.add ]] && err "无法配置伪装网站."
        [[ ! $is_new_proxy_site ]] && ask string is_new_proxy_site "请输入新的伪装网站 (例如 example.com):"
        proxy_site=$(sed 's#^.*//##;s#/$##' <<<$is_new_proxy_site)
        [[ $(grep -i "^github.com$" <<<$proxy_site) ]] && {
            err "墙啦"
        } || {
            load caddy.sh
            caddy_config proxy
            manage restart caddy &
        }
        msg "\n已更新伪装网站为: $(_green $proxy_site) \n"
        ;;
    12)
        [[ ! $is_socks_user ]] && err "($is_config_file) 不支持更改用户名 (Username)."
        ask string is_socks_user "请输入新用户名 (Username):"
        add $net
        ;;
    esac
}
del() {
    is_dont_get_ip=1
    [[ $is_conf_dir_empty ]] && return
    [[ ! $is_config_file ]] && get info $1
    if [[ $is_config_file ]]; then
        if [[ $is_main_start && ! $is_no_del_msg ]]; then
            msg "\n是否删除配置文件?: $is_config_file"
            pause
        fi
        rm -rf $is_conf_dir/"$is_config_file"
        [[ ! $is_new_json ]] && manage restart &
        [[ ! $is_no_del_msg ]] && _green "\n已删除: $is_config_file\n"
        [[ $is_caddy ]] && {
            is_del_host=$host
            [[ $is_change ]] && {
                [[ ! $old_host ]] && return
                is_del_host=$old_host
            }
            [[ $is_del_host && $host != $old_host ]] && {
                rm -rf $is_caddy_conf/$is_del_host.conf $is_caddy_conf/$is_del_host.conf.add
                [[ ! $is_new_json ]] && manage restart caddy &
            }
        }
    fi
    if [[ ! $(ls $is_conf_dir | grep .json) && ! $is_change ]]; then
        warn "当前配置目录为空! 因为你刚刚删除了最后一个配置文件."
        is_conf_dir_empty=1
    fi
    unset is_dont_get_ip
    [[ $is_dont_auto_exit ]] && unset is_config_file
}
uninstall() {
    if [[ $is_caddy ]]; then
        is_tmp_list=("卸载 $is_core_name" "卸载 ${is_core_name} & Caddy")
        ask list is_do_uninstall
    else
        ask string y "是否卸载 ${is_core_name}? [y]:"
    fi
    manage stop &>/dev/null
    manage disable &>/dev/null
    rm -rf $is_core_dir $is_log_dir $is_sh_bin ${is_sh_bin/$is_sh_name/AiMi} /lib/systemd/system/$is_core.service
    sed -i "/alias $is_sh_name=/d;/alias AiMi=/d" /root/.bashrc
    if [[ $REPLY == '2' ]]; then
        manage stop caddy &>/dev/null
        manage disable caddy &>/dev/null
        rm -rf $is_caddy_dir $is_caddy_bin /lib/systemd/system/caddy.service
    fi
    [[ $is_install_sh ]] && return
    _green "\n卸载完成!"
    msg "脚本哪里需要完善? 请反馈"
    msg "反馈问题) $(msg_ul https://github.com/${is_sh_repo}/issues)\n"
}
manage() {
    [[ $is_dont_auto_exit ]] && return
    case $1 in
    1 | start)
        is_do=start
        is_do_msg=启动
        is_test_run=1
        ;;
    2 | stop)
        is_do=stop
        is_do_msg=停止
        ;;
    3 | r | restart)
        is_do=restart
        is_do_msg=重启
        is_test_run=1
        ;;
    *)
        is_do=$1
        is_do_msg=$1
        ;;
    esac
    case $2 in
    caddy)
        is_do_name=$2
        is_run_bin=$is_caddy_bin
        is_do_name_msg=Caddy
        ;;
    *)
        is_do_name=$is_core
        is_run_bin=$is_core_bin
        is_do_name_msg=$is_core_name
        ;;
    esac
    systemctl $is_do $is_do_name
    [[ $is_test_run && ! $is_new_install ]] && {
        sleep 2
        if [[ ! $(pgrep -f $is_run_bin) ]]; then
            is_run_fail=${is_do_name_msg,,}
            [[ ! $is_no_manage_msg ]] && {
                msg
                warn "($is_do_msg) $is_do_name_msg 失败"
                _yellow "检测到运行失败, 自动执行测试运行."
                get test-run
                _yellow "测试结束, 请按 Enter 退出."
            }
        fi
    }
}
add() {
    is_lower=${1,,}
    if [[ $is_lower ]]; then
        case $is_lower in
        ws | tcp | quic | http)
            is_new_protocol=VMess-${is_lower^^}
            ;;
        wss | h2 | hu | vws | vh2 | vhu | tws | th2 | thu)
            is_new_protocol=$(sed -E "s/^V/VLESS-/;s/^T/Trojan-/;/^(W|H)/{s/^/VMess-/};s/WSS/WS/;s/HU/HTTPUpgrade/" <<<${is_lower^^})-TLS
            ;;
        r | reality)
            is_new_protocol=VLESS-REALITY
            ;;
        rh2)
            is_new_protocol=VLESS-HTTP2-REALITY
            ;;
        ss)
            is_new_protocol=Shadowsocks
            ;;
        door | direct)
            is_new_protocol=Direct
            ;;
        tuic)
            is_new_protocol=TUIC
            ;;
        hy | hy2 | hysteria*)
            is_new_protocol=Hysteria2
            ;;
        trojan)
            is_new_protocol=Trojan
            ;;
        socks)
            is_new_protocol=Socks
            ;;
        anytls | atls)
            is_new_protocol=AnyTLS
            ;;
        mixed | mix)
            is_new_protocol=Mixed
            ;;
        snell | sn)
            is_new_protocol=Snell
            ;;
        shadowtls | stls | st)
            is_new_protocol=ShadowTLS
            ;;
        naive | nv)
            is_new_protocol=Naive
            ;;
        *)
            for v in ${protocol_list[@]}; do
                [[ $(egrep -i "^$is_lower$" <<<$v) ]] && is_new_protocol=$v && break
            done
            [[ ! $is_new_protocol ]] && err "无法识别 ($1), 请使用: $is_sh_name add [protocol] [args... | auto]"
            ;;
        esac
    fi
    [[ ! $is_new_protocol ]] && ask set_protocol
    case ${is_new_protocol,,} in
    snell*)
        is_use_port=$2
        is_use_pass=$3
        is_use_snell_ver=$4
        is_add_opts="[port] [psk] [version]"
        ;;
    shadowtls*)
        is_use_port=$2
        is_use_pass=$3
        is_use_stls_ver=$4
        is_use_handshake=$5
        is_add_opts="[port] [password] [version] [handshake]"
        ;;
    naive*)
        is_use_port=$2
        is_use_socks_user=$3
        is_use_socks_pass=$4
        is_use_domain=$5
        is_add_opts="[port] [username] [password] [domain]"
        ;;
    *-tls)
        is_use_tls=1
        is_use_host=$2
        is_use_uuid=$3
        is_use_path=$4
        is_add_opts="[host] [uuid] [/path]"
        ;;
    vmess* | tuic*)
        is_use_port=$2
        is_use_uuid=$3
        [[ ${is_new_protocol,,} == 'tuic' ]] && is_use_domain=$4
        is_add_opts="[port] [uuid]"
        ;;
    trojan* | hysteria*)
        is_use_port=$2
        is_use_pass=$3
        is_use_domain=$4
        is_add_opts="[port] [password] [domain]"
        ;;
    *reality*)
        is_reality=1
        is_use_port=$2
        is_use_uuid=$3
        is_use_servername=$4
        is_add_opts="[port] [uuid] [sni]"
        ;;
    shadowsocks)
        is_use_port=$2
        is_use_pass=$3
        is_use_method=$4
        is_add_opts="[port] [password] [method]"
        ;;
    direct)
        is_use_port=$2
        is_use_door_addr=$3
        is_use_door_port=$4
        is_add_opts="[port] [remote_addr] [remote_port]"
        ;;
    socks)
        is_socks=1
        is_use_port=$2
        is_use_socks_user=$3
        is_use_socks_pass=$4
        is_add_opts="[port] [username] [password]"
        ;;
    anytls*)
        is_use_port=$2
        is_use_pass=$3
        is_use_domain=$4
        is_add_opts="[port] [password] [domain]"
        ;;
    mixed*)
        is_use_port=$2
        is_use_socks_user=$3
        is_use_socks_pass=$4
        is_add_opts="[port] [username] [password]"
        ;;
    esac
    [[ $1 && ! $is_change ]] && {
        msg "\n使用协议: $is_new_protocol"
        is_err_tips="\n\n请使用: $(_green $is_sh_name add $1 $is_add_opts) 来添加 $is_new_protocol 配置"
    }
    if [[ $is_set_new_protocol ]]; then
        unset is_ver is_psk is_handshake
        case $is_old_net in
        h2 | ws | httpupgrade)
            old_host=$host
            [[ ! $is_use_tls ]] && host=
            ;;
        reality)
            net_type=
            [[ ! $(grep -i reality <<<$is_new_protocol) ]] && is_reality=
            ;;
        ss)
            [[ $(is_test uuid $ss_password) ]] && uuid=$ss_password
            ;;
        esac
        [[ ! $(is_test uuid $uuid) ]] && uuid=
        [[ $(is_test uuid $password) ]] && uuid=$password
    fi
    if [[ $is_no_auto_tls && ! $is_use_tls && ! $(grep -E '^(anytls|snell|shadowtls|naive)$' <<<${is_new_protocol,,}) ]]; then
        err "$is_new_protocol 不支持手动配置 tls."
    fi
    if [[ $2 ]]; then
        for v in is_use_port is_use_uuid is_use_host is_use_path is_use_pass is_use_method is_use_door_addr is_use_door_port is_use_socks_user is_use_socks_pass is_use_servername is_use_snell_ver is_use_stls_ver is_use_handshake is_use_domain; do
            [[ ${!v} == 'auto' ]] && unset $v
        done
        if [[ $is_use_port ]]; then
            [[ ! $(is_test port ${is_use_port}) ]] && {
                err "($is_use_port) 不是一个有效的端口. $is_err_tips"
            }
            [[ $(is_test port_used $is_use_port) && ! $is_gen ]] && {
                err "无法使用 ($is_use_port) 端口. $is_err_tips"
            }
            port=$is_use_port
        fi
        if [[ $is_use_door_port ]]; then
            [[ ! $(is_test port ${is_use_door_port}) ]] && {
                err "(${is_use_door_port}) 不是一个有效的目标端口. $is_err_tips"
            }
            door_port=$is_use_door_port
        fi
        if [[ $is_use_uuid ]]; then
            [[ ! $(is_test uuid $is_use_uuid) ]] && {
                err "($is_use_uuid) 不是一个有效的 UUID. $is_err_tips"
            }
            uuid=$is_use_uuid
        fi
        if [[ $is_use_path ]]; then
            [[ ! $(is_test path $is_use_path) ]] && {
                err "($is_use_path) 不是有效的路径. $is_err_tips"
            }
            path=$is_use_path
        fi
        if [[ $is_use_method ]]; then
            is_tmp_use_name=加密方式
            is_tmp_list=${ss_method_list[@]}
            for v in ${is_tmp_list[@]}; do
                [[ $(egrep -i "^${is_use_method}$" <<<$v) ]] && is_tmp_use_type=$v && break
            done
            [[ ! ${is_tmp_use_type} ]] && {
                warn "(${is_use_method}) 不是一个可用的${is_tmp_use_name}."
                msg "${is_tmp_use_name}可用如下: "
                for v in ${is_tmp_list[@]}; do
                    msg "\t\t$v"
                done
                msg "$is_err_tips\n"
                exit 1
            }
            ss_method=$is_tmp_use_type
        fi
        [[ $is_use_pass ]] && ss_password=$is_use_pass && password=$is_use_pass
        [[ $is_use_host ]] && host=$is_use_host
        [[ $is_use_door_addr ]] && door_addr=$is_use_door_addr
        [[ $is_use_servername ]] && is_servername=$is_use_servername
        [[ $is_use_socks_user ]] && is_socks_user=$is_use_socks_user
        [[ $is_use_socks_pass ]] && is_socks_pass=$is_use_socks_pass
        [[ $is_use_snell_ver ]] && is_ver=$is_use_snell_ver
        [[ $is_use_stls_ver ]] && is_ver=$is_use_stls_ver
        [[ $is_use_handshake ]] && is_handshake=$is_use_handshake


        if [[ ${is_new_protocol,,} == 'naive' && ! $is_gen && ! $is_no_auto_tls && ! $is_use_domain && ! $is_cert_domain ]]; then
            [[ $is_main_start ]] && ask string is_use_domain "Naive 必须使用受信任证书, 请输入用于申请证书的域名:"
            [[ ! $is_use_domain ]] && {
                err "Naive 必须使用受信任证书, 请提供域名: $is_sh_name add naive [port] [username] [password] [domain]"
            }
        fi
        [[ $is_use_domain && ! $is_gen ]] && {
            [[ $is_no_auto_tls ]] && {
                err "no-auto-tls 模式下不会自动申请证书, 请去掉参数 ($is_use_domain)."
            }
            [[ ! $(grep -E '^[a-zA-Z0-9]([a-zA-Z0-9_.-]*[a-zA-Z0-9])?\.[a-zA-Z]{2,}$' <<<"$is_use_domain") ]] && {
                err "($is_use_domain) 不是一个有效的域名. $is_err_tips"
            }
            get cert $is_use_domain
        }
        [[ ${is_new_protocol,,} == 'snell' && $is_ver && ! $(egrep -o '^[56]$' <<<"$is_ver") ]] && {
            err "($is_ver) 不是一个可用的 Snell 版本, 可选: 5 或 6. $is_err_tips"
        }
        [[ ${is_new_protocol,,} == 'shadowtls' && $is_ver && ! $(egrep -o '^[123]$' <<<"$is_ver") ]] && {
            err "($is_ver) 不是一个可用的 ShadowTLS 版本, 可选: 1, 2 或 3. $is_err_tips"
        }
    fi
    if [[ $is_use_tls ]]; then
        if [[ ! $is_no_auto_tls && ! $is_caddy && ! $is_gen && ! $is_dont_test_host ]]; then
            [[ $(is_test port_used 80) || $(is_test port_used 443) ]] && {
                get_port
                is_http_port=$tmp_port
                get_port
                is_https_port=$tmp_port
                warn "端口 (80 或 443) 已经被占用, 你也可以考虑使用 no-auto-tls"
                msg "\n Caddy 将使用非标准端口实现自动配置 TLS, HTTP:$is_http_port HTTPS:$is_https_port\n"
                msg "请确定是否继续???"
                pause
            }
            is_install_caddy=1
        fi
        [[ ! $host ]] && ask string host "请输入域名:"
        get host-test
    else
        if [[ $is_main_start ]]; then
            [[ ! $port ]] && ask string port "请输入端口:"
            case ${is_new_protocol,,} in
            socks)
                [[ ! $is_socks_user ]] && ask string is_socks_user "请设置用户名:"
                [[ ! $is_socks_pass ]] && ask string is_socks_pass "请设置密码:"
                ;;
            mixed)
                [[ ! $is_socks_user ]] && ask string is_socks_user "请设置用户名:"
                [[ ! $is_socks_pass ]] && ask string is_socks_pass "请设置密码:"
                ;;
            anytls)
                [[ ! $password ]] && ask string password "请设置密码:"
                ;;
            snell)
                [[ ! $password ]] && ask string password "请设置 PSK:"
                [[ ! $is_ver ]] && {
                    is_default_arg=5
                    ask string is_ver "请选择 Snell 版本 (5 或 6, 默认 [5]):"
                }
                ;;
            shadowtls)
                [[ ! $password ]] && ask string password "请设置密码:"
                [[ ! $is_ver ]] && {
                    is_default_arg=3
                    ask string is_ver "请选择 ShadowTLS 版本 (1, 2 或 3, 默认 [3]):"
                }
                [[ ! $is_handshake ]] && {
                    is_default_arg=$is_random_servername
                    ask string is_handshake "请输入握手域名 (默认 [$is_random_servername]):"
                }
                ;;
            naive)
                [[ ! $is_socks_user ]] && ask string is_socks_user "请设置用户名:"
                [[ ! $is_socks_pass ]] && ask string is_socks_pass "请设置密码:"
                ;;
            shadowsocks)
                [[ ! $ss_method ]] && ask set_ss_method
                [[ ! $ss_password ]] && ask string ss_password "请设置密码:"
                ;;
            esac
        fi
    fi
    if [[ $is_new_protocol == 'Direct' ]]; then
        [[ ! $door_addr ]] && ask string door_addr "请输入目标地址:"
        [[ ! $door_port ]] && ask string door_port "请输入目标端口:"
    fi
    if [[ $(grep 2022 <<<$ss_method) ]]; then
        [[ $ss_password ]] && {
            is_test_json=1
            create server Shadowsocks
            [[ ! $tmp_uuid ]] && get_uuid
            is_test_json_save=$is_conf_dir/tmp-test-$tmp_uuid
            cat <<<"$is_new_json" >$is_test_json_save
            $is_core_bin check -c $is_test_json_save &>/dev/null
            if [[ $? != 0 ]]; then
                warn "Shadowsocks 协议 ($ss_method) 不支持使用密码 ($(_red_bg $ss_password))\n\n你可以使用命令: $(_green $is_sh_name ss2022) 生成支持的密码.\n\n脚本将自动创建可用密码:)"
                ss_password=
                json_str=
            fi
            is_test_json=
            rm -f $is_test_json_save
        }
    fi
    if [[ $is_install_caddy ]]; then
        get install-caddy
    fi
    create server $is_new_protocol
    info
}
add_relay() {
    is_dont_show_info=
    unset relay_net relay_protocol relay_password relay_method relay_port relay_server relay_server_port relay_server_password
    if [[ $1 ]]; then
        is_relay_file=$(ls $is_conf_dir 2>/dev/null | egrep -i "$1" | grep .json | head -n1)
        if [[ $is_relay_file ]]; then
            get info $is_relay_file
            relay_net=$net
            relay_server=$2
            relay_server_port=$3
            relay_server_password=$4
        else
            relay_server=$1
            relay_server_port=$2
            relay_server_password=$3
        fi
    else
        relay_server=$2
        relay_server_port=$3
        relay_server_password=$4
    fi
    [[ $relay_server == 'auto' ]] && relay_server=
    [[ $relay_server_port == 'auto' ]] && relay_server_port=
    [[ $relay_server_password == 'auto' ]] && relay_server_password=
    if [[ ! $relay_net ]]; then
        is_tmp_list=("Hysteria2" "Trojan" "TUIC" "Shadowsocks")
        ask list relay_net null "\n请选择中转协议:\n"
        case ${relay_net,,} in
        hysteria2 | hy | hy2) relay_net=hysteria2 ;;
        trojan) relay_net=trojan ;;
        tuic) relay_net=tuic ;;
        ss | shadowsocks) relay_net=ss ;;
        *) err "无法识别中转协议: $relay_net" ;;
        esac
    fi
    case $relay_net in
    hysteria2 | trojan | tuic | ss | shadowsocks) ;;
    *)
        msg "节点 ($is_config_file) 协议不支持直接中转, 默认使用 Hysteria2 作为中转协议."
        relay_net=hysteria2
        ;;
    esac
    case $relay_net in
    hysteria2) relay_protocol=Hysteria2 ;;
    trojan) relay_protocol=Trojan ;;
    ss | shadowsocks) relay_protocol=Shadowsocks ;;
    tuic) relay_protocol=TUIC ;;
    esac
    if [[ $relay_net == 'ss' || $relay_net == 'shadowsocks' ]]; then
        [[ ! $relay_method ]] && relay_method=$ss_method
        [[ ! $relay_method ]] && relay_method=$is_random_ss_method
        is_default_arg=$relay_method
        ask string relay_method "请选择中转加密方式 (直接回车使用: $relay_method):"
        is_tmp_use_type=
        for v in ${ss_method_list[@]}; do
            [[ $(egrep -i "^${relay_method}$" <<<$v) ]] && is_tmp_use_type=$v && break
        done
        [[ ! $is_tmp_use_type ]] && err "($relay_method) 不是可用的加密方式."
        relay_method=$is_tmp_use_type
    fi
    if [[ ! $relay_password ]]; then
        if [[ $relay_net == 'ss' && $(grep 2022 <<<$relay_method) ]]; then
            relay_password=$(get ss2022)
        else
            get_uuid
            relay_password=$tmp_uuid
        fi
    fi
    if [[ $is_config_file ]]; then
        relay_port=$port
    else
        [[ ! $relay_port ]] && {
            get_port
            relay_port=$tmp_port
            is_default_arg=$relay_port
            ask string relay_port "请设置中转监听端口 (直接回车使用: $relay_port):"
        }
    fi
    if [[ $relay_net == 'ss' && $(grep 2022 <<<$relay_method) ]]; then
        msg "Shadowsocks 2022 中转密码: $relay_password"
    else
        is_default_arg=$relay_password
        ask string relay_password "请设置中转密码/UUID (直接回车使用: $relay_password):"
    fi
    if [[ $relay_net == 'tuic' && ! $(is_test uuid $relay_password) ]]; then
        get_uuid
        relay_password=$tmp_uuid
        msg "已自动生成 TUIC UUID: $relay_password"
    fi
    [[ ! $relay_server ]] && ask string relay_server "请输入落地服务器地址 (IP/域名):"
    [[ ! $relay_server_port ]] && {
        while :; do
            echo -ne "请输入落地服务器端口:"
            read relay_server_port
            [[ $(is_test port "$relay_server_port") ]] && break
            msg "输入错误, 请输入正确的端口 (1-65535)"
        done
    }
    if [[ ! $relay_server_password ]]; then
        if [[ $relay_net == 'ss' && $(grep 2022 <<<$relay_method) ]]; then
            relay_server_password=$(get ss2022)
            msg "Shadowsocks 2022 落地密码: $relay_server_password"
        else
            is_default_arg=$relay_password
            ask string relay_server_password "请设置落地密码/UUID (直接回车使用: $relay_password):"
        fi
    fi
    case $relay_net in
    hysteria2)
        is_relay_inbound="type:\"hysteria2\",listen:\"$is_listen_addr\",listen_port:$relay_port,users:[{password:\"$relay_password\"}],tls:{enabled:true,alpn:[\"h3\"],key_path:\"$is_tls_key\",certificate_path:\"$is_tls_cer\"}"
        is_relay_outbound="type:\"hysteria2\",server:\"$relay_server\",server_port:$relay_server_port,password:\"$relay_server_password\",tls:{enabled:true,alpn:[\"h3\"],insecure:true}"
        ;;
    trojan)
        is_relay_inbound="type:\"trojan\",listen:\"$is_listen_addr\",listen_port:$relay_port,users:[{password:\"$relay_password\"}],tls:{enabled:true,key_path:\"$is_tls_key\",certificate_path:\"$is_tls_cer\"}"
        is_relay_outbound="type:\"trojan\",server:\"$relay_server\",server_port:$relay_server_port,password:\"$relay_server_password\",tls:{enabled:true,insecure:true}"
        ;;
    tuic)
        is_relay_inbound="type:\"tuic\",listen:\"$is_listen_addr\",listen_port:$relay_port,users:[{uuid:\"$relay_password\",password:\"$relay_password\"}],congestion_control:\"bbr\",tls:{enabled:true,alpn:[\"h3\"],key_path:\"$is_tls_key\",certificate_path:\"$is_tls_cer\"}"
        is_relay_outbound="type:\"tuic\",server:\"$relay_server\",server_port:$relay_server_port,uuid:\"$relay_password\",password:\"$relay_server_password\",congestion_control:\"bbr\",tls:{enabled:true,alpn:[\"h3\"],insecure:true}"
        ;;
    ss | shadowsocks)
        is_relay_inbound="type:\"shadowsocks\",listen:\"$is_listen_addr\",listen_port:$relay_port,method:\"$relay_method\",password:\"$relay_password\""
        is_relay_outbound="type:\"shadowsocks\",server:\"$relay_server\",server_port:$relay_server_port,method:\"$relay_method\",password:\"$relay_server_password\""
        ;;
    esac
    is_relay_out_tag=relay-$relay_port
    if [[ $is_config_file ]]; then
        is_relay_out_obj=$(jq -c "{tag:\"$is_relay_out_tag\",$is_relay_outbound}" <<<{})
        is_new_json=$(jq --argjson ob "$is_relay_out_obj" --arg tag "$is_relay_out_tag" --arg inb "$is_config_file" '.outbounds=[.outbounds[]? | select(.tag != $tag)] + [$ob] | .route={final:"direct",rules:[.route.rules[]? | select(.outbound != $tag)] + [{inbound:[$inb],action:"route",outbound:$tag}]}' $is_conf_dir/$is_config_file)
        cat <<<$is_new_json >$is_conf_dir/$is_config_file
        is_relay_on_node=1
    else
        is_config_name=$relay_protocol-Relay-$relay_port.json
        is_new_json=$(jq "{inbounds:[{tag:\"$is_config_name\",$is_relay_inbound}],outbounds:[{tag:\"$is_relay_out_tag\",$is_relay_outbound}],route:{final:\"direct\",rules:[{inbound:[\"$is_config_name\"],action:\"route\",outbound:\"$is_relay_out_tag\"}]}}" <<<{})
        cat <<<$is_new_json >$is_conf_dir/$is_config_name
    fi
    manage restart &
    unset host
    is_addr=
    get addr
    net=$relay_net
    case $relay_net in
    hysteria2) is_protocol=hysteria2 ;;
    trojan) is_protocol=trojan ;;
    tuic) is_protocol=tuic ;;
    ss | shadowsocks) is_protocol=shadowsocks ;;
    esac
    port=$relay_port
    password=$relay_password
    [[ $relay_net == 'tuic' ]] && uuid=$relay_password
    [[ $relay_net == 'ss' || $relay_net == 'shadowsocks' ]] && {
        ss_method=$relay_method
        ss_password=$relay_password
    }
    if [[ $is_relay_on_node ]]; then
        unset is_protocol
        info $is_config_file
        msg "\n$(_green 已给节点 $is_config_file 添加中转)\n"
    else
        info $is_config_name
        msg "\n$(_green 已添加中转节点: $is_config_name)\n"
    fi
    msg "落地地址 (remote addr): $relay_server"
    msg "落地端口 (remote port): $relay_server_port"
    msg "落地密码 (password): $relay_server_password"
    msg "客户端连接地址: 本机 IP + 中转端口 $relay_port"
}
get() {
    case $1 in
    addr)
        is_addr=$host
        [[ ! $is_addr ]] && is_addr=$is_cert_domain
        [[ ! $is_addr ]] && {
            get_ip
            is_addr=$ip
        }
        ;;
    new)
        [[ ! $host ]] && get_ip
        [[ ! $port ]] && get_port && port=$tmp_port
        [[ ! $uuid ]] && get_uuid && uuid=$tmp_uuid
        ;;
    file)
        is_file_str=$2
        [[ ! $is_file_str ]] && is_file_str='.json$'
        readarray -t is_all_json <<<"$(ls $is_conf_dir | egrep -i "$is_file_str" | sed '/dynamic-port-.*-link/d' | head -200)"
        [[ ! $is_all_json ]] && err "无法找到相关的配置文件: $2"
        [[ ${#is_all_json[@]} -eq 1 ]] && is_config_file=$is_all_json && is_auto_get_config=1
        [[ ! $is_config_file ]] && {
            [[ $is_dont_auto_exit ]] && return
            ask get_config_file
        }
        ;;
    info)
        get file $2
        if [[ $is_config_file ]]; then
            is_json_str=$(cat $is_conf_dir/"$is_config_file" | sed s#//.*##)
            is_json_data=$(jq '(.inbounds[0]|.type,.listen_port,(.users[0]|.uuid,.password,.username),.method,.password,.override_port,.override_address,(.transport|.type,.path,.headers.host),(.tls|.server_name,.reality.private_key,.key_path,.certificate_path),.version,.psk,(.handshake|.server,.server_port)),(.outbounds[1].tag)' <<<$is_json_str)
            [[ $? != 0 ]] && err "无法读取此文件: $is_config_file"
            is_up_var_set=(null is_protocol port uuid password username ss_method ss_password door_port door_addr net_type path host is_servername is_private_key is_tls_key_json is_tls_cer_json is_ver is_psk is_handshake is_handshake_port is_public_key)
            [[ $is_debug ]] && msg "\n------------- debug: $is_config_file -------------"
            i=0
            for v in $(sed 's/""/null/g;s/"//g' <<<"$is_json_data"); do
                ((i++))
                [[ $is_debug ]] && msg "$i-${is_up_var_set[$i]}: $v"
                export ${is_up_var_set[$i]}="${v}"
            done
            for v in ${is_up_var_set[@]}; do
                [[ ${!v} == 'null' ]] && unset $v
            done
            [[ $is_handshake && $is_handshake_port && $is_handshake_port != 443 ]] && is_handshake="$is_handshake:$is_handshake_port"
            unset is_handshake_port

            [[ $is_tls_key_json ]] && is_tls_key=$is_tls_key_json
            [[ $is_tls_cer_json ]] && is_tls_cer=$is_tls_cer_json

            [[ $is_tls_cer == $is_caddy_data/* ]] && is_cert_domain=$(basename $(dirname $is_tls_cer))
            if [[ $is_private_key ]]; then
                is_reality=1
                net_type+=reality
                is_public_key=${is_public_key/public_key_/}
            fi
            is_socks_user=$username
            is_socks_pass=$password
            is_config_name=$is_config_file
            if [[ $is_caddy && $host && -f $is_caddy_conf/$host.conf ]]; then
                is_tmp_https_port=$(egrep -o "$host:[1-9][0-9]?+" $is_caddy_conf/$host.conf | sed s/.*://)
            fi
            [[ $is_tmp_https_port ]] && is_https_port=$is_tmp_https_port
            [[ $is_client && $host && $is_https_port && $(grep -E '^(ws|h2|http|httpupgrade)$' <<<$net_type) ]] && port=$is_https_port
            get protocol $is_protocol-$net_type
        fi
        ;;
    protocol)
        get addr
        is_lower=${2,,}
        net=
        is_users="users:[{uuid:\"$uuid\"}]"
        is_tls_json='tls:{enabled:true,alpn:["h3"],key_path:"'$is_tls_key'",certificate_path:"'$is_tls_cer'"}'
        case $is_lower in
        vmess*)
            is_protocol=vmess
            [[ $is_lower =~ "tcp" || ! $net_type && $is_up_var_set ]] && net=tcp && json_str=$is_users
            ;;
        vless*)
            is_protocol=vless
            ;;
        tuic*)
            net=tuic
            is_protocol=$net
            [[ ! $password ]] && password=$uuid
            is_users="users:[{uuid:\"$uuid\",password:\"$password\"}]"
            json_str="$is_users,congestion_control:\"bbr\",$is_tls_json"
            ;;
        trojan*)
            is_protocol=trojan
            [[ ! $password ]] && password=$uuid
            is_users="users:[{password:\"$password\"}]"
            [[ ! $host ]] && {
                net=trojan
                json_str="$is_users,${is_tls_json/alpn\:\[\"h3\"\],/}"
            }
            ;;
        hysteria2*)
            net=hysteria2
            is_protocol=$net
            [[ ! $password ]] && password=$uuid
            json_str="users:[{password:\"$password\"}],$is_tls_json"
            ;;
        shadowsocks*)
            net=ss
            is_protocol=shadowsocks
            [[ ! $ss_method ]] && ss_method=$is_random_ss_method
            [[ ! $ss_password ]] && {
                ss_password=$uuid
                [[ $(grep 2022 <<<$ss_method) ]] && ss_password=$(get ss2022)
            }
            json_str="method:\"$ss_method\",password:\"$ss_password\""
            ;;
        direct*)
            net=direct
            is_protocol=$net
            json_str="override_port:$door_port,override_address:\"$door_addr\""
            ;;
        socks*)
            net=socks
            is_protocol=$net
            [[ ! $is_socks_user ]] && is_socks_user=AiMi
            [[ ! $is_socks_pass ]] && is_socks_pass=$uuid
            json_str="users:[{username: \"$is_socks_user\", password: \"$is_socks_pass\"}]"
            ;;
        anytls*)
            net=anytls
            is_protocol=$net
            [[ ! $password ]] && password=$uuid
            json_str="users:[{password:\"$password\"}],${is_tls_json/alpn\:\[\"h3\"\],/}"
            ;;
        mixed*)
            net=mixed
            is_protocol=$net
            [[ ! $is_socks_user ]] && is_socks_user=AiMi
            [[ ! $is_socks_pass ]] && is_socks_pass=$uuid
            json_str="users:[{username: \"$is_socks_user\", password: \"$is_socks_pass\"}]"
            ;;
        snell*)
            net=snell
            is_protocol=$net
            [[ ! $password && $is_psk ]] && password=$is_psk
            [[ ! $password ]] && password=$uuid
            [[ ! $is_ver ]] && is_ver=5
            [[ $is_ver != 5 && $is_ver != 6 ]] && err "Snell 版本只能是 5 或 6, 当前: $is_ver"
            [[ $is_ver == 6 && ${#password} -lt 12 ]] && {
                err "Snell v6 的 psk 长度至少需要 12 个字符, 当前长度: ${#password}"
            }
            json_str="version:$is_ver,psk:\"$password\""
            ;;
        shadowtls*)
            net=shadowtls
            is_protocol=$net
            [[ ! $password && $is_psk ]] && password=$is_psk
            [[ ! $password && $ss_password ]] && password=$ss_password
            [[ ! $password ]] && password=$uuid
            [[ ! $is_ver ]] && is_ver=3
            [[ $is_ver != 1 && $is_ver != 2 && $is_ver != 3 ]] && {
                err "ShadowTLS 版本只能是 1, 2 或 3, 当前: $is_ver"
            }
            [[ ! $is_handshake ]] && is_handshake=$is_random_servername
            is_stls_handshake_addr=${is_handshake%%:*}
            if [[ $is_stls_handshake_addr == $is_handshake ]]; then
                is_stls_handshake_port=443
            else
                is_stls_handshake_port=${is_handshake##*:}
                [[ ! $(grep -E '^[0-9]+$' <<<"$is_stls_handshake_port") || $is_stls_handshake_port -gt 65535 ]] && {
                    err "($is_handshake) 不是一个有效的握手地址, 例如: www.bing.com 或 www.bing.com:443"
                }
            fi
            is_stls_handshake="handshake:{server:\"$is_stls_handshake_addr\",server_port:$is_stls_handshake_port}"
            case $is_ver in
            1)
                json_str="version:1,$is_stls_handshake"
                ;;
            2)
                json_str="version:2,password:\"$password\",$is_stls_handshake"
                ;;
            3)
                json_str="version:3,users:[{password:\"$password\"}],$is_stls_handshake"
                ;;
            esac
            ;;
        naive*)
            net=naive
            is_protocol=$net
            [[ ! $is_socks_user ]] && is_socks_user=AiMi
            [[ ! $is_socks_pass ]] && is_socks_pass=$uuid
            json_str="users:[{username: \"$is_socks_user\", password: \"$is_socks_pass\"}],tls:{enabled:true,key_path:\"$is_tls_key\",certificate_path:\"$is_tls_cer\"}"
            ;;
        *)
            err "无法识别协议: $is_config_file"
            ;;
        esac
        [[ $net ]] && return
        [[ $host && $is_lower =~ "tls" ]] && {
            [[ ! $path ]] && path="/$uuid"
            is_path_host_json=",path:\"$path\",headers:{host:\"$host\"}"
        }
        case $is_lower in
        *quic*)
            net=quic
            is_json_add="$is_tls_json,transport:{type:\"$net\"}"
            ;;
        *ws*)
            net=ws
            is_json_add="transport:{type:\"$net\"$is_path_host_json,early_data_header_name:\"Sec-WebSocket-Protocol\"}"
            ;;
        *reality*)
            net=reality
            [[ ! $is_servername ]] && is_servername=$is_random_servername
            [[ ! $is_private_key ]] && get_pbk
            is_json_add="tls:{enabled:true,server_name:\"$is_servername\",reality:{enabled:true,handshake:{server:\"$is_servername\",server_port:443},private_key:\"$is_private_key\",short_id:[\"\"]}}"
            [[ $is_lower =~ "http" ]] && {
                is_json_add="$is_json_add,transport:{type:\"http\"}"
            } || {
                is_users=${is_users/uuid/flow:\"xtls-rprx-vision\",uuid}
            }
            ;;
        *http* | *h2*)
            net=http
            [[ $is_lower =~ "up" ]] && net=httpupgrade
            is_json_add="transport:{type:\"$net\"$is_path_host_json}"
            [[ $is_lower =~ "h2" || ! $is_lower =~ "httpupgrade" && $host ]] && {
                net=h2

                [[ ! $is_caddy || $is_no_auto_tls ]] && {
                    is_json_add="${is_tls_json/alpn\:\[\"h3\"\],/},$is_json_add"
                }
            }
            ;;
        *)
            err "无法识别传输协议: $is_config_file"
            ;;
        esac
        json_str="$is_users,$is_json_add"
        ;;
    host-test)
        [[ $is_no_auto_tls || $is_gen || $is_dont_test_host ]] && return
        get_ip
        get ping
        if [[ ! $(grep $ip <<<$is_host_dns) ]]; then
            msg "\n请将 ($(_red_bg $host)) 解析到 ($(_red_bg $ip))"
            msg "\n如果使用 Cloudflare, 在 DNS 那; 关闭 (Proxy status / 代理状态), 即是 (DNS only / 仅限 DNS)"
            ask string y "我已经确定解析 [y]:"
            get ping
            if [[ ! $(grep $ip <<<$is_host_dns) ]]; then
                _cyan "\n测试结果: $is_host_dns"
                err "域名 ($host) 没有解析到 ($ip)"
            fi
        fi
        ;;
    ssss | ss2022)
        $is_core_bin generate rand 32 --base64
        ;;
    ping)
        is_dns_type="a"
        [[ $(grep ":" <<<$ip) ]] && is_dns_type="aaaa"
        is_host_dns=$(_wget -qO- --header="accept: application/dns-json" "https://one.one.one.one/dns-query?name=$host&type=$is_dns_type")
        ;;
    log | logerr)
        msg "\n 提醒: 按 $(_green Ctrl + C) 退出\n"
        if [[ $1 == 'log' ]]; then
            tail -f $is_log_dir/access.log
        else

            tail -f $is_log_dir/access.log | grep -i --line-buffered -E 'ERROR|WARN|FATAL|PANIC'
        fi
        ;;
    install-caddy)
        _green "\n安装 Caddy 实现自动配置 TLS.\n"
        load download.sh
        download caddy
        load systemd.sh
        install_service caddy &>/dev/null
        is_caddy=1
        _green "安装 Caddy 成功.\n"
        ;;
    reinstall)
        is_install_sh=$(cat $is_sh_dir/install.sh)
        uninstall
        bash <<<$is_install_sh
        ;;
    test-run)
        systemctl list-units --full -all &>/dev/null
        [[ $? != 0 ]] && {
            _yellow "\n无法执行测试, 请检查 systemctl 状态.\n"
            return
        }
        is_no_manage_msg=1
        if [[ ! $(pgrep -f $is_core_bin) ]]; then
            _yellow "\n测试运行 $is_core_name ..\n"
            manage start &>/dev/null
            if [[ $is_run_fail == $is_core ]]; then
                _red "$is_core_name 运行失败信息:"
                $is_core_bin run -c $is_config_json -C $is_conf_dir
            else
                _green "\n测试通过, 已启动 $is_core_name ..\n"
            fi
        else
            _green "\n$is_core_name 正在运行, 跳过测试\n"
        fi
        if [[ $is_caddy ]]; then
            if [[ ! $(pgrep -f $is_caddy_bin) ]]; then
                _yellow "\n测试运行 Caddy ..\n"
                manage start caddy &>/dev/null
                if [[ $is_run_fail == 'caddy' ]]; then
                    _red "Caddy 运行失败信息:"
                    $is_caddy_bin run --config $is_caddyfile
                else
                    _green "\n测试通过, 已启动 Caddy ..\n"
                fi
            else
                _green "\nCaddy 正在运行, 跳过测试\n"
            fi
        fi
        ;;
    cert)
        is_cert_domain=$2
        [[ ! $is_cert_domain ]] && err "请指定证书域名, 例如: $is_sh_name cert example.com"
        [[ ! $(grep -E '^[a-zA-Z0-9]([a-zA-Z0-9_.-]*[a-zA-Z0-9])?\.[a-zA-Z]{2,}$' <<<"$is_cert_domain") ]] && {
            err "($is_cert_domain) 不是一个有效的域名."
        }
        is_cert_dir=$is_caddy_data/certificates
        is_cert_crt=$(ls -t $is_cert_dir/*/$is_cert_domain/$is_cert_domain.crt 2>/dev/null | head -n1)
        [[ $is_cert_crt && ! -f ${is_cert_crt%.crt}.key ]] && is_cert_crt=
        if [[ $(type -P openssl) && $is_cert_crt ]] && ! openssl x509 -in $is_cert_crt -noout -checkend 0 &>/dev/null; then
            warn "($is_cert_domain) 的证书已过期, 重新申请."
            is_cert_crt=
        fi
        if [[ ! $is_cert_crt ]]; then
            [[ ! $is_caddy ]] && {
                get install-caddy
                is_install_caddy=1
            }
            create caddy cert
            msg "\n等待 Caddy 为 $(_green $is_cert_domain) 签发证书 (最长 60 秒)...\n"
            for is_tmp_i in $(seq 1 30); do
                sleep 2
                is_cert_crt=$(ls -t $is_cert_dir/*/$is_cert_domain/$is_cert_domain.crt 2>/dev/null | head -n1)
                [[ ! $is_cert_crt ]] && continue
                [[ ! -f ${is_cert_crt%.crt}.key ]] && {
                    is_cert_crt=
                    continue
                }

                if [[ $(type -P openssl) ]] && ! openssl x509 -in $is_cert_crt -noout -checkend 0 &>/dev/null; then
                    is_cert_crt=
                    continue
                fi
                break
            done
            [[ ! $is_cert_crt ]] && {
                err "Caddy 未能为 ($is_cert_domain) 签发证书.\n\n请检查: \n  1. 域名 ($is_cert_domain) 是否已解析到本机 IP\n  2. 80 与 443 端口是否可从公网访问\n  3. Caddy 是否正常运行: $(_yellow systemctl status caddy)"
            }
        fi
        is_cert_key=${is_cert_crt%.crt}.key
        is_cert_end=$(openssl x509 -in $is_cert_crt -noout -enddate 2>/dev/null | sed 's/notAfter=//')
        is_tls_cer=$is_cert_crt
        is_tls_key=$is_cert_key
        msg "\n受信任证书: $(_green $is_cert_crt)\n到期时间: $(_cyan ${is_cert_end:-未知}) (Caddy 会自动续期)\n"
        ;;
    client-json)
        is_client_id_json=
        is_stream=
        is_client_type=${is_protocol,,}
        is_client_insecure=',insecure:true'
        if [[ $is_tls_cer == $is_caddy_data/* ]] || [[ $is_caddy && $host && ! $is_no_auto_tls && $(grep -E '^(ws|h2|http|httpupgrade)$' <<<$net_type) ]]; then
            is_client_insecure=
        fi
        is_client_tls=",\"tls\":{enabled:true,server_name:\"${host:-$is_addr}\"$is_client_insecure}"
        case ${is_protocol,,} in
        vmess)
            is_client_id_json="server:\"$is_addr\",server_port:$port,uuid:\"$uuid\",security:\"auto\",alter_id:0"
            ;;
        vless)
            is_client_id_json="server:\"$is_addr\",server_port:$port,uuid:\"$uuid\""
            [[ $is_reality && $net_type != *http* ]] && is_client_id_json+=",flow:\"xtls-rprx-vision\""
            ;;
        trojan | anytls)
            is_client_id_json="server:\"$is_addr\",server_port:$port,password:\"$password\""
            ;;
        hysteria2)
            is_client_id_json="server:\"$is_addr\",server_port:$port,password:\"$password\""
            ;;
        tuic)
            is_client_id_json="server:\"$is_addr\",server_port:$port,uuid:\"$uuid\",password:\"$password\",congestion_control:\"bbr\""
            ;;
        shadowsocks)
            is_client_id_json="server:\"$is_addr\",server_port:$port,method:\"$ss_method\",password:\"$ss_password\""
            ;;
        socks | mixed)
            [[ $is_client_type == 'mixed' ]] && is_client_type=socks
            is_client_id_json="server:\"$is_addr\",server_port:$port,version:\"5\",username:\"$is_socks_user\",password:\"$is_socks_pass\""
            ;;
        snell)
            is_client_snell_ver=4
            [[ $is_ver == 6 ]] && is_client_snell_ver=6
            is_client_id_json="server:\"$is_addr\",server_port:$port,psk:\"$password\",version:$is_client_snell_ver"
            ;;
        naive)
            is_client_id_json="server:\"$is_addr\",server_port:$port,username:\"$is_socks_user\",password:\"$is_socks_pass\""
            ;;
        *)
            unset is_client_tls is_client_id_json is_stream is_client_type
            return
            ;;
        esac
        case $net in
        ws)
            is_stream=",\"transport\":{type:\"ws\",path:\"$path\""
            [[ $host ]] && is_stream+=",headers:{host:\"$host\"}"
            is_stream+="}"
            ;;
        h2 | http)
            is_stream=",\"transport\":{type:\"http\""
            [[ $path ]] && is_stream+=",path:\"$path\""
            [[ $host ]] && is_stream+=",host:[\"$host\"]"
            is_stream+="}"
            ;;
        httpupgrade)
            is_stream=",\"transport\":{type:\"httpupgrade\",path:\"$path\""
            [[ $host ]] && is_stream+=",host:\"$host\""
            is_stream+="}"
            ;;
        quic)
            is_stream=",\"transport\":{type:\"quic\"}"
            ;;
        esac
        case ${is_protocol,,} in
        vmess | vless)
            if [[ $is_reality ]]; then
                is_stream+=",\"tls\":{enabled:true,server_name:\"$is_servername\",utls:{enabled:true,fingerprint:\"chrome\"},reality:{enabled:true,public_key:\"$is_public_key\",short_id:\"\"}}"
            elif [[ $net == 'quic' ]]; then
                is_stream+=",\"tls\":{enabled:true,server_name:\"${host:-$is_addr}\",alpn:[\"h3\"]$is_client_insecure}"
            elif [[ $host ]]; then
                is_stream+=$is_client_tls
            fi
            ;;
        trojan | anytls)
            is_stream+=$is_client_tls
            ;;
        naive)
            is_stream+=",\"tls\":{enabled:true,server_name:\"${host:-$is_addr}\"}"
            ;;
        hysteria2 | tuic)
            is_stream+=",\"tls\":{enabled:true,server_name:\"${host:-$is_addr}\",alpn:[\"h3\"]$is_client_insecure}"
            ;;
        esac
        unset is_client_tls is_client_insecure
        ;;
    esac
}

array_del() {
    local is_ad_name=$1 is_ad_val=$2
    eval "local is_ad_src=(\"\${${is_ad_name}[@]}\")"
    local is_ad_out=() is_ad_v
    for is_ad_v in "${is_ad_src[@]}"; do
        [[ $is_ad_v == "$is_ad_val" ]] && continue
        is_ad_out+=("$is_ad_v")
    done
    eval "$is_ad_name=(\"\${is_ad_out[@]}\")"
}
info() {
    if [[ ! $is_protocol ]]; then
        get info $1
    fi
    is_trusted_cert=
    [[ $is_tls_cer == $is_caddy_data/* ]] && is_trusted_cert=1
    is_color=44
    case $net in
    ws | tcp | h2 | quic | http*)
        if [[ $host ]]; then
            is_color=45
            is_can_change=(0 1 2 3 5)
            is_info_show=(0 1 2 3 4 6 7 8)
            is_tmp_info_port=$is_https_port

            if [[ $net == 'quic' ]]; then
                is_tmp_info_port=$port
                is_insecure=1
                is_info_show+=(20)
            fi
            [[ $is_protocol == 'vmess' ]] && {
                is_vmess_url=$(jq -c '{v:2,ps:'\"AiMi-$net-$host\"',add:'\"$is_addr\"',port:'\"$is_tmp_info_port\"',id:'\"$uuid\"',aid:"0",net:'\"$net\"',host:'\"$host\"',path:'\"$path\"',tls:'\"tls\"'}' <<<{})
                is_url=vmess://$(echo -n $is_vmess_url | base64 -w 0)
            } || {
                [[ $is_protocol == "trojan" ]] && {
                    uuid=$password
                    is_can_change=(0 1 2 3 4)
                    is_info_show=(0 1 2 10 4 6 7 8)
                }
                is_url="$is_protocol://$uuid@$(url_addr "$host"):$is_tmp_info_port?encryption=none&security=tls&type=$net&host=$host&path=$path#AiMi-$net-$host"
            }
            [[ $is_caddy ]] && is_can_change+=(11)
            is_info_str=("$is_protocol" "$is_addr" "$is_tmp_info_port" "$uuid" "$net" "$host" "$path" 'tls')
            [[ $net == 'quic' ]] && is_info_str+=(true)
        else
            is_type=none
            is_can_change=(0 1 5)
            is_info_show=(0 1 2 3 4)
            is_info_str=("$is_protocol" "$is_addr" "$port" "$uuid" "$net")
            [[ $net == "http" ]] && {
                net=tcp
                is_type=http
                is_tcp_http=1
                is_info_show+=(5)
                is_info_str=("$is_protocol" "$is_addr" "$port" "$uuid" tcp http)
            }
            [[ $net == "quic" ]] && {
                is_insecure=1
                is_info_show+=(8 9 20)
                is_info_str+=(tls h3 true)
                is_quic_add=",tls:\"tls\",alpn:\"h3\""
            }
            is_vmess_url=$(jq -c "{v:2,ps:\"AiMi-${net}-$is_addr\",add:\"$is_addr\",port:\"$port\",id:\"$uuid\",aid:\"0\",net:\"$net\",type:\"$is_type\"$is_quic_add}" <<<{})
            is_url=vmess://$(echo -n $is_vmess_url | base64 -w 0)
        fi
        ;;
    ss)
        is_can_change=(0 1 4 6)
        is_info_show=(0 1 2 10 11)
        is_url="ss://$(echo -n ${ss_method}:${ss_password} | base64 -w 0)@$(url_addr "$is_addr"):${port}#AiMi-$net-${is_addr}"
        is_info_str=("$is_protocol" "$is_addr" "$port" "$ss_password" "$ss_method")
        ;;
    trojan)
        is_insecure=1
        is_can_change=(0 1 4)
        is_info_show=(0 1 2 10 4 8 20)
        is_url="$is_protocol://$password@$(url_addr "$is_addr"):$port?type=tcp&security=tls&allowInsecure=1#AiMi-$net-$is_addr"
        is_info_str=("$is_protocol" "$is_addr" "$port" "$password" tcp tls true)
        [[ $is_trusted_cert ]] && {
            unset is_insecure
            array_del is_info_show 20
            array_del is_info_str true
            is_url=${is_url/&allowInsecure=1/}
        }
        ;;
    hy*)
        is_insecure=1
        is_can_change=(0 1 4)
        is_info_show=(0 1 2 10 8 9 20)
        is_url="$is_protocol://$password@$(url_addr "$is_addr"):$port?alpn=h3&insecure=1#AiMi-$net-$is_addr"
        is_info_str=("$is_protocol" "$is_addr" "$port" "$password" tls h3 true)
        [[ $is_trusted_cert ]] && {
            unset is_insecure
            array_del is_info_show 20
            array_del is_info_str true
            is_url=${is_url/&insecure=1/}
        }
        ;;
    tuic)
        is_insecure=1
        is_can_change=(0 1 4 5)
        is_info_show=(0 1 2 3 10 8 9 20 21)
        is_url="$is_protocol://$uuid:$password@$(url_addr "$is_addr"):$port?alpn=h3&allow_insecure=1&congestion_control=bbr#AiMi-$net-$is_addr"
        is_info_str=("$is_protocol" "$is_addr" "$port" "$uuid" "$password" tls h3 true bbr)
        [[ $is_trusted_cert ]] && {
            unset is_insecure
            array_del is_info_show 20
            array_del is_info_str true
            is_url=${is_url/&allow_insecure=1/}
        }
        ;;
    reality)
        is_color=41
        is_can_change=(0 1 5 9 10)
        is_info_show=(0 1 2 3 15 4 8 16 17 18)
        is_flow=xtls-rprx-vision
        is_net_type=tcp
        [[ $net_type =~ "http" || ${is_new_protocol,,} =~ "http" ]] && {
            is_flow=
            is_net_type=h2
            array_del is_info_show 15
        }
        if [[ $is_flow ]]; then
            is_info_str=("$is_protocol" "$is_addr" "$port" "$uuid" "$is_flow" "$is_net_type" reality "$is_servername" chrome "$is_public_key")
        else
            is_info_str=("$is_protocol" "$is_addr" "$port" "$uuid" "$is_net_type" reality "$is_servername" chrome "$is_public_key")
        fi
        is_url="$is_protocol://$uuid@$(url_addr "$ip"):$port?encryption=none&security=reality&flow=$is_flow&type=$is_net_type&sni=$is_servername&pbk=$is_public_key&fp=chrome#AiMi-$net-$is_addr"
        ;;
    direct)
        is_can_change=(0 1 7 8)
        is_info_show=(0 1 2 13 14)
        is_info_str=("$is_protocol" "$is_addr" "$port" "$door_addr" "$door_port")
        ;;
    socks)
        is_can_change=(0 1 12 4)
        is_info_show=(0 1 2 19 10)
        is_info_str=("$is_protocol" "$is_addr" "$port" "$is_socks_user" "$is_socks_pass")
        is_url="socks://$(echo -n ${is_socks_user}:${is_socks_pass} | base64 -w 0)@$(url_addr "$is_addr"):${port}#AiMi-$net-${is_addr}"
        ;;
    anytls)
        is_insecure=1
        is_can_change=(0 1 4)
        is_info_show=(0 1 2 10 4 8 20)
        is_url="$is_protocol://$password@$(url_addr "$is_addr"):$port?type=tcp&security=tls&allowInsecure=1#AiMi-$net-$is_addr"
        is_info_str=("$is_protocol" "$is_addr" "$port" "$password" tcp tls true)
        [[ $is_trusted_cert ]] && {
            unset is_insecure
            array_del is_info_show 20
            array_del is_info_str true
            is_url=${is_url/&allowInsecure=1/}
        }
        ;;
    mixed)
        is_can_change=(0 1 12 4)
        is_info_show=(0 1 2 19 10)
        is_info_str=("$is_protocol" "$is_addr" "$port" "$is_socks_user" "$is_socks_pass")
        is_url="socks://$(echo -n ${is_socks_user}:${is_socks_pass} | base64 -w 0)@$(url_addr "$is_addr"):${port}#AiMi-$net-${is_addr}"
        ;;
    snell)
        is_can_change=(0 1 4)
        is_info_show=(0 1 2 22 10)
        is_info_str=("$is_protocol" "$is_addr" "$port" "$is_ver" "$password")
        is_no_url_tips="Snell 没有标准分享链接, 请在客户端手动填写: 地址/端口/PSK/版本."
        ;;
    shadowtls)
        is_can_change=(0 1 4)
        is_info_show=(0 1 2 22 6 10)
        is_info_str=("$is_protocol" "$is_addr" "$port" "$is_ver" "$is_handshake" "$password")
        is_no_url_tips="ShadowTLS 需要与内层协议 (Trojan/Shadowsocks 等) 链式使用, 无法生成单一 URL."
        ;;
    naive)
        is_can_change=(0 1 12 4)
        is_info_show=(0 1 2 19 10 8 20)
        is_url="naive+https://$is_socks_user:$is_socks_pass@$(url_addr "$is_addr"):$port#AiMi-$net-$is_addr"
        is_info_str=("$is_protocol" "$is_addr" "$port" "$is_socks_user" "$is_socks_pass" tls true)
        [[ $is_trusted_cert ]] && {
            array_del is_info_show 20
            array_del is_info_str true
        }
        is_naive_tips=1
        ;;
    esac
    [[ $is_dont_show_info || $is_gen || $is_dont_auto_exit ]] && return
    msg "-------------- $is_config_name -------------"
    for ((i = 0; i < ${#is_info_show[@]}; i++)); do
        a=${info_list[${is_info_show[$i]}]}
        if [[ ${#a} -eq 11 || ${#a} -ge 13 ]]; then
            tt='\t'
        else
            tt='\t\t'
        fi
        msg "$a $tt= \e[${is_color}m${is_info_str[$i]}\e[0m"
    done
    is_relay_server=$(jq -r '[.outbounds[]? | select(.tag | startswith("relay-"))][0].server // empty' $is_conf_dir/$is_config_name 2>/dev/null)
    if [[ $is_relay_server ]]; then
        is_relay_server_port=$(jq -r '[.outbounds[]? | select(.tag | startswith("relay-"))][0].server_port' $is_conf_dir/$is_config_name)
        is_relay_server_password=$(jq -r '[.outbounds[]? | select(.tag | startswith("relay-"))][0].password' $is_conf_dir/$is_config_name)
        msg "------------- 中转 (Relay) -------------"
        for v in "13:$is_relay_server" "14:$is_relay_server_port" "10:$is_relay_server_password"; do
            idx=${v%%:*}
            val=${v#*:}
            a=${info_list[$idx]}
            if [[ ${#a} -eq 11 || ${#a} -ge 13 ]]; then
                tt='\t'
            else
                tt='\t\t'
            fi
            msg "$a $tt= \e[${is_color}m$val\e[0m"
        done
        unset is_relay_server is_relay_server_port is_relay_server_password
    fi
    if [[ $is_new_install ]]; then
        warn "首次安装自己看着办"
    fi
    if [[ $is_url ]]; then
        msg "------------- ${info_list[12]} -------------"
        msg "\e[4;${is_color}m${is_url}\e[0m"
        [[ $is_insecure ]] && {
            warn "某些客户端如(V2rayN 等)导入URL需手动将: 跳过证书验证(allowInsecure) 设置为 true, 或打开: 允许不安全的连接"
        }
    fi
    [[ $is_no_url_tips ]] && warn "$is_no_url_tips"
    if [[ -f $is_tls_cer && $is_tls_cer == $is_caddy_data/* ]]; then
        is_tmp_cert_end=$(openssl x509 -in $is_tls_cer -noout -enddate 2>/dev/null | sed 's/notAfter=//')
        msg "证书 (certificate) \t= $(_green 受信任) $is_tls_cer${is_tmp_cert_end:+ (到期: $is_tmp_cert_end)}"
    fi
    [[ $is_naive_tips && $is_tls_cer != $is_caddy_data/* ]] && {
        warn "Naive 需要受信任的证书, 当前只有自签名证书 ($is_tls_cer).\n\n可在添加时附带域名自动申请 (Caddy), 例如:\n  $is_sh_name add naive [port] [username] [password] [domain]"
    }
    if [[ $is_no_auto_tls ]]; then
        msg "------------- no-auto-tls INFO -------------"
        msg "端口(port): $port"
        msg "路径(path): $path"
        msg "\e[41m帮助(help)\e[0m: $(msg_ul https://github.com/QDwbd)"
    fi
    footer_msg
}
footer_msg() {
    [[ $is_core_stop && ! $is_new_json ]] && warn "$is_core_name 当前处于停止状态."
    [[ $is_caddy_stop && $host ]] && warn "Caddy 当前处于停止状态."
    msg "----------纯净无广告----------"
}
url_show() {
    is_dont_show_info=1
    info "$2"
    [[ ! $is_url ]] && err "($is_config_name) 无法生成 URL 链接."
    msg "\n------------- $is_config_name & URL 链接 -------------"
    msg "\n\e[${is_color}m${is_url}\e[0m\n"
    footer_msg
}
update() {
    case $1 in
    1 | core | $is_core)
        is_update_name=core
        is_show_name=$is_core_name
        is_run_ver=v${is_core_ver##* }
        is_update_repo=$is_core_repo
        ;;
    2 | sh)
        is_update_name=sh
        is_show_name="$is_sh_name 脚本"
        is_run_ver=$is_sh_ver
        is_update_repo=$is_sh_repo
        ;;
    3 | caddy)
        [[ ! $is_caddy ]] && err "不支持更新 Caddy."
        is_update_name=caddy
        is_show_name="Caddy"
        is_run_ver=$is_caddy_ver
        is_update_repo=$is_caddy_repo
        ;;
    *)
        err "无法识别 ($1), 请使用: $is_sh_name update [core | sh | caddy] [ver]"
        ;;
    esac
    [[ $2 ]] && is_new_ver=v${2#v}
    [[ $is_run_ver == $is_new_ver ]] && {
        msg "\n自定义版本和当前 $is_show_name 版本一样, 无需更新.\n"
        exit
    }
    load download.sh
    if [[ $is_new_ver ]]; then
        msg "\n使用自定义版本更新 $is_show_name: $(_green $is_new_ver)\n"
    else
        get_latest_version $is_update_name
        [[ $is_run_ver == $latest_ver ]] && {
            msg "\n$is_show_name 当前已经是最新版本了.\n"
            exit
        }
        msg "\n发现 $is_show_name 新版本: $(_green $latest_ver)\n"
        is_new_ver=$latest_ver
    fi
    download $is_update_name $is_new_ver
    msg "更新成功, 当前 $is_show_name 版本: $(_green $is_new_ver)\n"
    msg "$(_green 请查看更新说明: https://github.com/$is_update_repo/releases/tag/$is_new_ver)\n"
    [[ $is_update_name != 'sh' ]] && manage restart $is_update_name &
}
is_main_menu() {
    msg "\n------------- $is_sh_name script $is_sh_ver by $author -------------"
    msg "$is_core_name $is_core_ver: $is_core_status"
    is_main_start=1
    ask mainmenu
    case $REPLY in
    1)
        add
        ;;
    2)
        add_relay
        ;;
    3)
        change
        ;;
    4)
        info
        ;;
    5)
        del
        ;;
    6)
        ask list is_do_manage "启动 停止 重启"
        manage $REPLY &
        msg "\n管理状态执行: $(_green $is_do_manage)\n"
        ;;
    7)
        is_tmp_list=("更新$is_core_name" "更新脚本")
        [[ $is_caddy ]] && is_tmp_list+=("更新Caddy")
        ask list is_do_update null "\n请选择更新:\n"
        update $REPLY
        ;;
    8)
        uninstall
        ;;
    9)
        msg
        load help.sh
        show_help
        ;;
    10)
        ask list is_do_other "启用BBR 查看日志 测试运行 重装脚本 设置DNS"
        case $REPLY in
        1)
            load bbr.sh
            _try_enable_bbr
            ;;
        2)
            get log
            ;;
        3)
            get test-run
            ;;
        4)
            get reinstall
            ;;
        5)
            load dns.sh
            dns_set
            ;;
        esac
        ;;
    11)
        load help.sh
        about
        ;;
    esac
}
main() {
    case $1 in
    a | add | gen | no-auto-tls)
        [[ $1 == 'gen' ]] && is_gen=1
        [[ $1 == 'no-auto-tls' ]] && is_no_auto_tls=1
        add ${@:2}
        ;;
    relay)
        add_relay ${@:2}
        ;;
    bin | pbk | check | completion | format | generate | geoip | geosite | merge | rule-set | run | tools)
        is_run_command=$1
        if [[ $1 == 'bin' ]]; then
            $is_core_bin ${@:2}
        else
            [[ $is_run_command == 'pbk' ]] && is_run_command="generate reality-keypair"
            $is_core_bin $is_run_command ${@:2}
        fi
        ;;
    bbr)
        load bbr.sh
        _try_enable_bbr
        ;;
    c | config | change)
        change ${@:2}
        ;;
    cert)
        get cert $2
        ;;
    client)
        create client $2
        ;;
    d | del | rm)
        del $2
        ;;
    dd | ddel | fix | fix-all)
        case $1 in
        fix)
            [[ $2 ]] && {
                change $2 full
            } || {
                is_change_id=full && change
            }
            return
            ;;
        fix-all)
            is_dont_auto_exit=1
            msg
            for v in $(ls $is_conf_dir | grep .json$ | sed '/dynamic-port-.*-link/d'); do
                msg "fix: $v"
                change $v full
            done
            _green "\nfix 完成.\n"
            ;;
        *)
            is_dont_auto_exit=1
            [[ ! $2 ]] && {
                err "无法找到需要删除的参数"
            } || {
                for v in ${@:2}; do
                    del $v
                done
            }
            ;;
        esac
        is_dont_auto_exit=
        manage restart &
        [[ $is_del_host ]] && manage restart caddy &
        ;;
    dns)
        load dns.sh
        dns_set ${@:2}
        ;;
    debug)
        is_debug=1
        get info $2
        warn "如果需要复制; 请把 *uuid, *password, *host, *key 的值改写, 以避免泄露."
        ;;
    fix-config.json)
        create config.json
        ;;
    fix-caddyfile)
        if [[ $is_caddy ]]; then
            load caddy.sh
            caddy_config new
            manage restart caddy &
            _green "\nfix 完成.\n"
        else
            err "无法执行此操作"
        fi
        ;;
    i | info)
        info $2
        ;;
    ip)
        get_ip
        msg $ip
        ;;
    in | import)
        load import.sh
        ;;
    log)
        get $@
        ;;
    url)
        url_show $@
        ;;
    un | uninstall)
        uninstall
        ;;
    u | up | update | U | update.sh)
        is_update_name=$2
        is_update_ver=$3
        [[ ! $is_update_name ]] && is_update_name=core
        [[ $1 == 'U' || $1 == 'update.sh' ]] && {
            is_update_name=sh
            is_update_ver=
        }
        update $is_update_name $is_update_ver
        ;;
    ssss | ss2022)
        get $@
        ;;
    s | status)
        msg "\n$is_core_name $is_core_ver: $is_core_status\n"
        [[ $is_caddy ]] && msg "Caddy $is_caddy_ver: $is_caddy_status\n"
        ;;
    start | stop | r | restart)
        [[ $2 && $2 != 'caddy' ]] && err "无法识别 ($2), 请使用: $is_sh_name $1 [caddy]"
        manage $1 $2 &
        ;;
    t | test)
        get test-run
        ;;
    reinstall)
        get $1
        ;;
    get-port)
        get_port
        msg $tmp_port
        ;;
    main)
        is_main_menu
        ;;
    v | ver | version)
        [[ $is_caddy_ver ]] && is_caddy_ver="/ $(_blue Caddy $is_caddy_ver)"
        msg "\n$(_green $is_core_name $is_core_ver) / $(_cyan $is_sh_name script $is_sh_ver) $is_caddy_ver\n"
        ;;
    h | help | --help)
        load help.sh
        show_help ${@:2}
        ;;
    *)
        is_try_change=1
        change test $1
        if [[ $is_change_id ]]; then
            unset is_try_change
            [[ $2 ]] && {
                change $2 $1 ${@:3}
            } || {
                change
            }
        else
            err "无法识别 ($1), 获取帮助请使用: $is_sh_name help"
        fi
        ;;
    esac
}