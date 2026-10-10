is_dns_list=(
    1.1.1.1
    8.8.8.8
    h3://dns.google/dns-query
    h3://cloudflare-dns.com/dns-query
    h3://family.cloudflare-dns.com/dns-query
    set
    none
)



dns_new_server() {
    local is_dns_addr=$1 is_dns_scheme is_dns_rest is_dns_hostpart
    local is_dns_server is_dns_port is_dns_path is_dns_type
    case $is_dns_addr in
    *://*)
        is_dns_scheme=${is_dns_addr%%://*}
        is_dns_rest=${is_dns_addr#*://}
        ;;
    *)
        is_dns_rest=$is_dns_addr
        ;;
    esac
    is_dns_hostpart=${is_dns_rest%%/*}
    [[ $is_dns_rest == */* ]] && is_dns_path="/${is_dns_rest#*/}"
    is_dns_server=$is_dns_hostpart
    if [[ $is_dns_hostpart =~ ^\[(.*)\]:([0-9]+)$ ]]; then
        is_dns_server=${BASH_REMATCH[1]}
        is_dns_port=${BASH_REMATCH[2]}
    elif [[ $is_dns_hostpart =~ ^([^:]+):([0-9]+)$ ]]; then
        is_dns_server=${BASH_REMATCH[1]}
        is_dns_port=${BASH_REMATCH[2]}
    fi
    case ${is_dns_scheme,,} in
    tcp) is_dns_type=tcp ;;
    tls) is_dns_type=tls ;;
    https) is_dns_type=https ;;
    quic) is_dns_type=quic ;;
    h3) is_dns_type=h3 ;;
    *) is_dns_type=udp ;;
    esac
    if [[ $is_dns_type == https || $is_dns_type == h3 ]] && [[ ! $is_dns_path ]]; then
        is_dns_path=/dns-query
    fi

    jq -cn \
        --arg type "$is_dns_type" \
        --arg server "$is_dns_server" \
        --arg path "$is_dns_path" \
        --arg port "$is_dns_port" \
        '{type:$type,server:$server,domain_resolver:"local"}
         + (if $port == "" then {} else {server_port:($port | tonumber)} end)
         + (if ($type == "https" or $type == "h3") then {path:$path} else {} end)'
}
dns_set() {
    if [[ $1 ]]; then
        case ${1,,} in
        11 | 1111)
            is_dns_use=${is_dns_list[0]}
            ;;
        88 | 8888)
            is_dns_use=${is_dns_list[1]}
            ;;
        gg | google)
            is_dns_use=${is_dns_list[2]}
            ;;
        cf | cloudflare)
            is_dns_use=${is_dns_list[3]}
            ;;
        nosex | family)
            is_dns_use=${is_dns_list[4]}
            ;;
        set)
            if [[ $2 ]]; then
                is_dns_use=${2,,}
            else
                ask string is_dns_use "请输入 DNS: "
            fi
            ;;
        none)
            is_dns_use=none
            ;;
        *)
            err "无法识别 DNS 参数: $@"
            ;;
        esac
    else
        is_tmp_list=(${is_dns_list[@]})
        ask list is_dns_use null "\n请选择 DNS:\n"
        if [[ $is_dns_use == "set" ]]; then
            ask string is_dns_use "请输入 DNS: "
        fi
    fi
    if [[ $is_dns_use == "none" ]]; then

        is_tmp_dns_json=$(jq '.dns={} | del(.route.default_domain_resolver)' $is_config_json)
    elif [[ $is_new_dns ]]; then



        is_dns_server_json=$(dns_new_server "$is_dns_use")
        [[ $? != 0 || ! $is_dns_server_json ]] && err "无法解析 DNS 地址: $is_dns_use"
        is_tmp_dns_json=$(jq --argjson s "$is_dns_server_json" '.dns.servers=[$s,{type:"local",tag:"local",prefer_go:true}] | .route.default_domain_resolver="local"' $is_config_json)
    else

        is_tmp_dns_json=$(jq --arg dns "$is_dns_use" '.dns.servers=[{address:$dns,address_resolver:"local"},{tag:"local",address:"local"}]' $is_config_json)
    fi
    cat <<<"$is_tmp_dns_json" >$is_config_json
    unset is_tmp_dns_json is_dns_server_json
    manage restart &
    msg "\n已更新 DNS 为: $(_green $is_dns_use)\n"
}