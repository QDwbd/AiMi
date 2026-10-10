#!/bin/bash

author=QDwbd
red='\e[31m'
yellow='\e[33m'
gray='\e[90m'
green='\e[92m'
blue='\e[94m'
magenta='\e[95m'
cyan='\e[96m'
none='\e[0m'
_red() { echo -e ${red}$@${none}; }
_blue() { echo -e ${blue}$@${none}; }
_cyan() { echo -e ${cyan}$@${none}; }
_green() { echo -e ${green}$@${none}; }
_yellow() { echo -e ${yellow}$@${none}; }
_magenta() { echo -e ${magenta}$@${none}; }
_red_bg() { echo -e "\e[41m$@${none}"; }
is_err=$(_red_bg 错误!)
is_warn=$(_red_bg 警告!)
err() {
    echo -e "\n$is_err $@\n" && exit 1
}
warn() {
    echo -e "\n$is_warn $@\n"
}
[[ $EUID != 0 ]] && err "当前非 ${yellow}ROOT用户.${none}"
cmd=$(type -P apt-get || type -P yum)
[[ ! $cmd ]] && err "此脚本仅支持 ${yellow}(Ubuntu or Debian or CentOS)${none}."
[[ ! $(type -P systemctl) ]] && {
    err "此系统缺少 ${yellow}(systemctl)${none}, 请尝试执行:${yellow} ${cmd} update -y;${cmd} install systemd -y ${none}来修复此错误."
}
is_wget=$(type -P wget)
case $(uname -m) in
amd64 | x86_64)
    is_arch=amd64
    ;;
*aarch64* | *armv8*)
    is_arch=arm64
    ;;
*)
    err "此脚本仅支持 64 位系统..."
    ;;
esac
is_core=sing-box
is_core_name=sing-box
is_sh_name=AiMi
is_core_dir=/etc/$is_core
is_core_bin=$is_core_dir/bin/$is_core
is_core_repo=SagerNet/$is_core
is_conf_dir=$is_core_dir/conf
is_log_dir=/var/log/$is_core
is_sh_bin=/usr/local/bin/$is_sh_name
is_sh_dir=$is_core_dir/sh
is_sh_repo=$author/AiMi
is_pkg="wget unzip tar"
is_config_json=$is_core_dir/config.json
tmp_var_lists=(
    tmpcore
    tmpsh
    tmpjq
    is_core_ok
    is_sh_ok
    is_jq_ok
    is_pkg_ok
)
tmpdir=$(mktemp -u)
[[ ! $tmpdir ]] && {
    tmpdir=/tmp/tmp-$RANDOM
}
for i in ${tmp_var_lists[*]}; do
    export $i=$tmpdir/$i
done
load() {
    . $is_sh_dir/src/$1
}
_wget() {
    [[ $proxy ]] && export https_proxy=$proxy
    wget --no-check-certificate $*
}
msg() {
    case $1 in
    warn)
        local color=$yellow
        ;;
    err)
        local color=$red
        ;;
    ok)
        local color=$green
        ;;
    esac
    echo -e "${color}$(date +'%T')${none}) ${2}"
}
show_help() {
    echo -e "Usage: $0 [-f xxx | -l | -p xxx | -v xxx | -h]"
    echo -e "  -f, --core-file <path>          自定义 $is_core_name 文件路径, e.g., -f /root/$is_core-linux-amd64.tar.gz"
    echo -e "  -l, --local-install             本地获取安装脚本, 使用当前目录"
    echo -e "  -p, --proxy <addr>              使用代理下载, e.g., -p http://127.0.0.1:30666 or -p socks5://127.0.0.1:30666"
    echo -e "  -v, --core-version <ver>        自定义 $is_core_name 版本, e.g., -v v1.8.13"
    echo -e "  -h, --help                      显示此帮助界面\n"
    exit 0
}
install_pkg() {
    cmd_not_found=
    for i in $*; do
        [[ ! $(type -P $i) ]] && cmd_not_found="$cmd_not_found,$i"
    done
    if [[ $cmd_not_found ]]; then
        pkg=$(echo $cmd_not_found | sed 's/,/ /g')
        msg warn "安装依赖包 >${pkg}"
        is_yum=$([[ $cmd =~ yum ]] && echo 1)



        if [[ ! $is_yum ]]; then
            for _ in $(seq 1 30); do
                fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock &>/dev/null || break
                sleep 2
            done
        fi
        [[ $is_yum ]] && yum install epel-release -y &>/dev/null
        $cmd update -y &>/dev/null
        for _ in 1 2 3; do
            $cmd install -y $pkg &>/dev/null && {
                >$is_pkg_ok
                break
            }
            sleep 3
        done
    else
        >$is_pkg_ok
    fi
}
download() {
    case $1 in
    core)
        [[ ! $is_core_ver ]] && is_core_ver=$(_wget -qO- "https://api.github.com/repos/${is_core_repo}/releases/latest?v=$RANDOM" | grep tag_name | egrep -o 'v([0-9.]+)')
        [[ $is_core_ver ]] && link="https://github.com/${is_core_repo}/releases/download/${is_core_ver}/${is_core}-${is_core_ver:1}-linux-${is_arch}.tar.gz"
        name=$is_core_name
        tmpfile=$tmpcore
        is_ok=$is_core_ok
        ;;
    sh)
        link=https://github.com/${is_sh_repo}/releases/latest/download/code.tar.gz
        name="$is_sh_name 脚本"
        tmpfile=$tmpsh
        is_ok=$is_sh_ok
        ;;
    jq)
        link=https://github.com/jqlang/jq/releases/download/jq-1.8.1/jq-linux-$is_arch
        name="jq"
        tmpfile=$tmpjq
        is_ok=$is_jq_ok
        ;;
    esac
    [[ $link ]] && {
        msg warn "下载 ${name} > ${link}"
        if _wget -t 3 -q -c $link -O $tmpfile; then
            mv -f $tmpfile $is_ok
        fi
    }
}
get_ip() {
    local ip_line
    ip_line=$(_wget -4 -qO- https://one.one.one.one/cdn-cgi/trace 2>/dev/null | sed -n 's/^ip=//p' | head -n1)
    [[ -z $ip_line ]] && ip_line=$(_wget -6 -qO- https://one.one.one.one/cdn-cgi/trace 2>/dev/null | sed -n 's/^ip=//p' | head -n1)
    [[ $ip_line ]] && export ip="$ip_line"
}
check_status() {
    [[ ! -f $is_pkg_ok ]] && {
        msg err "安装依赖包失败"
        msg err "请尝试手动安装依赖包: $cmd update -y; $cmd install -y $is_pkg"
        is_fail=1
    }
    if [[ $is_wget ]]; then
        [[ ! -f $is_core_ok ]] && {
            msg err "下载 ${is_core_name} 失败"
            is_fail=1
        }
        [[ ! -f $is_sh_ok ]] && {
            msg err "下载 ${is_sh_name} 脚本失败"
            is_fail=1
        }
        [[ ! -f $is_jq_ok ]] && {
            msg err "下载 jq 失败"
            is_fail=1
        }
    else
        [[ ! $is_fail ]] && {
            is_wget=1
            [[ ! $is_core_file ]] && download core &
            [[ ! $local_install ]] && download sh &
            [[ $jq_not_found ]] && download jq &
            get_ip
            wait
            check_status
        }
    fi
    [[ $is_fail ]] && {
        exit_and_del_tmpdir
    }
}
pass_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
        -f | --core-file)
            [[ -z $2 ]] && {
                err "($1) 缺少必需参数, 正确使用示例: [$1 /root/$is_core-linux-amd64.tar.gz]"
            } || [[ ! -f $2 ]] && {
                err "($2) 不是一个常规的文件."
            }
            is_core_file=$2
            shift 2
            ;;
        -l | --local-install)
            [[ ! -f ${PWD}/src/core.sh || ! -f ${PWD}/$is_sh_name.sh ]] && {
                err "当前目录 (${PWD}) 非完整的脚本目录."
            }
            local_install=1
            shift 1
            ;;
        -p | --proxy)
            [[ -z $2 ]] && {
                err "($1) 缺少必需参数, 正确使用示例: [$1 http://127.0.0.1:30666 or -p socks5://127.0.0.1:30666]"
            }
            proxy=$2
            shift 2
            ;;
        -v | --core-version)
            [[ -z $2 ]] && {
                err "($1) 缺少必需参数, 正确使用示例: [$1 v1.8.13]"
            }
            is_core_ver=v${2//v/}
            shift 2
            ;;
        -h | --help)
            show_help
            ;;
        *)
            echo -e "\n${is_err} ($@) 为未知参数...\n"
            show_help
            ;;
        esac
    done
    [[ $is_core_ver && $is_core_file ]] && {
        err "无法同时自定义 ${is_core_name} 版本和 ${is_core_name} 文件."
    }
}
exit_and_del_tmpdir() {
    rm -rf $tmpdir
    [[ ! $1 ]] && {
        msg err "哦豁.."
        msg err "安装过程出现错误..."
        echo -e "反馈问题) https://github.com/${is_sh_repo}/issues"
        echo
        exit 1
    }
    exit
}
main() {
    [[ -f $is_sh_bin && -d $is_core_dir/bin && -d $is_sh_dir && -d $is_conf_dir ]] && {
        err "检测到脚本已安装, 如需重装请使用${green} ${is_sh_name} reinstall ${none}命令."
    }
    [[ $# -gt 0 ]] && pass_args $@
    clear
    echo
    echo "........... $is_sh_name script by $author .........."
    echo
    msg warn "开始安装..."
    [[ $is_core_ver ]] && msg warn "${is_core_name} 版本: ${yellow}$is_core_ver${none}"
    [[ $proxy ]] && msg warn "使用代理: ${yellow}$proxy${none}"
    mkdir -p $tmpdir
    [[ $is_core_file ]] && {
        cp -f $is_core_file $is_core_ok
        msg warn "${yellow}${is_core_name} 文件使用 > $is_core_file${none}"
    }
    [[ $local_install ]] && {
        >$is_sh_ok
        msg warn "${yellow}本地获取安装脚本 > $PWD ${none}"
    }
    timedatectl set-ntp true &>/dev/null
    [[ $? != 0 ]] && {
        is_ntp_on=1
    }
    install_pkg $is_pkg &
    if [[ $(type -P jq) ]]; then
        >$is_jq_ok
    else
        jq_not_found=1
    fi
    [[ $is_wget ]] && {
        [[ ! $is_core_file ]] && download core &
        [[ ! $local_install ]] && download sh &
        [[ $jq_not_found ]] && download jq &
        get_ip
    }
    wait
    check_status
    if [[ $is_core_file ]]; then
        mkdir -p $tmpdir/testzip
        tar zxf $is_core_ok --strip-components 1 -C $tmpdir/testzip &>/dev/null
        [[ $? != 0 ]] && {
            msg err "${is_core_name} 文件无法通过测试."
            exit_and_del_tmpdir
        }
        [[ ! -f $tmpdir/testzip/$is_core ]] && {
            msg err "${is_core_name} 文件无法通过测试."
            exit_and_del_tmpdir
        }
    fi
    [[ ! $ip ]] && {
        msg err "获取服务器 IP 失败."
        exit_and_del_tmpdir
    }
    mkdir -p $is_sh_dir
    if [[ $local_install ]]; then
        cp -rf $PWD/* $is_sh_dir
    else
        tar zxf $is_sh_ok -C $is_sh_dir
    fi
    mkdir -p $is_core_dir/bin
    if [[ $is_core_file ]]; then
        cp -rf $tmpdir/testzip/* $is_core_dir/bin
    else
        tar zxf $is_core_ok --strip-components 1 -C $is_core_dir/bin
    fi
    echo "alias AiMi=$is_sh_bin" >>/root/.bashrc
    echo "alias $is_sh_name=$is_sh_bin" >>/root/.bashrc
    ln -sf $is_sh_dir/$is_sh_name.sh $is_sh_bin
    ln -sf $is_sh_dir/$is_sh_name.sh ${is_sh_bin/$is_sh_name/万物}
    [[ $jq_not_found ]] && mv -f $is_jq_ok /usr/bin/jq
    chmod +x $is_core_bin $is_sh_bin /usr/bin/jq ${is_sh_bin/$is_sh_name/万物}
    mkdir -p $is_log_dir
    msg ok "生成配置文件..."
    load systemd.sh
    is_new_install=1
    install_service $is_core &>/dev/null
    mkdir -p $is_conf_dir
    load core.sh
    add reality
    exit_and_del_tmpdir ok
}
main $@