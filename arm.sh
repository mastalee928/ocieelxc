#!/usr/bin/env bash

options=("LXC镜像下载" "安装LXC环境" "清空机子和规则" "安装LXC受控")
_red() { echo -e "\033[31m\033[01m$@\033[0m"; }
_green() { echo -e "\033[32m\033[01m$@\033[0m"; }
_yellow() { echo -e "\033[33m\033[01m$@\033[0m"; }
_blue() { echo -e "\033[36m\033[01m$@\033[0m"; }
reading() { read -rp "$(_green "$1")" "$2"; }
#root权限
root_need() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${Red}Error:This script must be run as root!${Font}"
        exit 1
    fi
}

#检测ovz
ovz_no() {
    if [[ -d "/proc/vz" ]]; then
        echo -e "${Red}Your VPS is based on OpenVZ，not supported!${Font}"
        exit 1
    fi
}

install_package() {
    package_name=$1
    if command -v $package_name >/dev/null 2>&1; then
        _green "$package_name has been installed"
        _green "$package_name 已经安装"
    else
        apt-get install -y $package_name
        if [ $? -ne 0 ]; then
            apt-get install -y $package_name --fix-missing
        fi
        _green "$package_name has attempted to install"
        _green "$package_name 已尝试安装"
    fi
}

downimage(){
    install_package curl
    if [ ! -d /root/image ]; then
        echo "Image文件夹不存在，为你创建文件夹"
        mkdir /root/image
    fi
    echo "——————————————————————————————————————————————————"
    _green "1)Alpine3.6"
    _green "2)Debian11"
    _green "3)Debian10"
    _green "4)Debian12(ARM)"
    echo "——————————————————————————————————————————————————"
    reading "请输入安装的系统模板:" num
    case "$num" in
        1)
            if [ ! -f /root/image/alpine3.6.tar.gz ]; then
                curl -L https://wp.809886.xyz/d/NAT/Alpine3.6.tar.gz?sign=lBDmJznQw6D14KxRvrp98XFont88pFbvSpWxoO3u7vU=:0 -o /root/image/alpine3.6.tar.gz
                echo "下载完成，开始导入镜像"
            fi
            cd /root >/dev/null 2>&1
            lxc image import /root/image/alpine3.6.tar.gz --alias alpine3.6
        ;;
        2)
            if [ ! -f /root/image/debian11.tar.gz ]; then
                curl -L https://drive.usercontent.google.com/download?id=12pvyXUe-cYDpUrDfwQPKyA1Bt4T3QxtS&export=download&authuser=0&confirm=t&uuid=c6c41e42-77d3-4f04-8bb5-0621f288da31&at=ANTm3czsoG6JiwCXeFe2zfxpEhHx:1767343430816 -o /root/image/debian11.tar.gz
                echo "下载完成，开始导入镜像"
            fi
            cd /root >/dev/null 2>&1
            lxc image import /root/image/debian11.tar.gz --alias debian11
        ;;
        3)
            if [ ! -f /root/image/debian10.tar.gz ]; then
                curl -L http://down.senkin.nl/image/debian10.tar.gz -o /root/image/debian10.tar.gz
                echo "下载完成，开始导入镜像"
            fi
            cd /root >/dev/null 2>&1
            lxc image import /root/image/debian10.tar.gz --alias debian10
        ;;
        4)
            if [ ! -f /root/image/debian12.tar.gz ]; then
                curl -L https://drive.usercontent.google.com/download?id=1PInrWQvSPBTXw5IiwEIQk2KVBS2q9Twf&export=download&authuser=0&confirm=t&uuid=967eb59f-dc71-4547-8454-63b366cc1c14&at=ANTm3cw76wWPTY2lApv6EYWlmPg1:1767343332750 -o /root/image/debian12.tar.gz
                echo "下载完成，开始导入镜像"
            fi
            cd /root >/dev/null 2>&1
            ! lxc -h >/dev/null 2>&1 && echo 'alias lxc="/snap/bin/lxc"' >> /root/.bashrc && source /root/.bashrc
export PATH=$PATH:/snap/bin && lxc image import /root/image/debian12.tar.gz --alias debian12
        ;;
    esac
}

Lxcinstall(){
    root_need
    ovz_no
    apt-get update
    install_package wget
    install_package curl
    install_package sudo
    install_package dos2unix
    install_package ufw
    install_package jq
    install_package uidmap
    install_package ipcalc
    ufw disable
    #Lxd开始安装
    lxd_snap=$(dpkg -l | awk '/^[hi]i/{print $2}' | grep -ow snap)
    lxd_snapd=$(dpkg -l | awk '/^[hi]i/{print $2}' | grep -ow snapd)
    if [[ "$lxd_snap" =~ ^snap.* ]] && [[ "$lxd_snapd" =~ ^snapd.* ]]; then
        _green "snap已安装"
    else
        _green "开始安装snap"
        apt-get update
        #     install_package snap
        install_package snapd
    fi
    snap_core=$(snap list core)
    snap_lxd=$(snap list lxd)
    if [[ "$snap_core" =~ core.* ]] && [[ "$snap_lxd" =~ lxd.* ]]; then
        _green "lxd is installed"
        _green "lxd已安装"
        lxd_lxc_detect=$(lxc list)
        if [[ "$lxd_lxc_detect" =~ "snap-update-ns failed with code1".* ]]; then
            systemctl restart apparmor
            snap restart lxd
        else
            _green "环境检测无问题"
        fi
    else
        _green "开始安装LXD"
        snap install lxd
        if [[ $? -ne 0 ]]; then
            snap remove lxd
            snap install core
            snap install lxd
        fi
        ! lxc -h >/dev/null 2>&1 && echo 'alias lxc="/snap/bin/lxc"' >>/root/.bashrc && source /root/.bashrc
        export PATH=$PATH:/snap/bin
        ! lxc -h >/dev/null 2>&1 && _yellow 'lxc路径有问题，请检查修复' && exit
        _green "LXD安装完成"
    fi
    while true; do
        reading "宿主机需要开设多大的存储池？(存储池就是小鸡硬盘之和的大小，推荐SWAP和存储池加起来达到母鸡硬盘的95%空间，注意是GB为单位，需要10G存储池则输入10)：" disk_nums
        if [[ "$disk_nums" =~ ^[1-9][0-9]*$ ]]; then
            break
        else
            _yellow "输入无效，请输入一个正整数。"
        fi
    done
    temp=$(/snap/bin/lxd init --storage-backend lvm --storage-create-loop "$disk_nums" --storage-pool default --auto 2>&1)
    if [[ $? -ne 0 ]]; then
        status=false
    else
        status=true
    fi
    echo "$temp"
    if command -v lxc >/dev/null 2>&1; then
        echo 'alias lxc="/snap/bin/lxc"' >> /root/.bashrc
        source /root/.bashrc
    fi
    export PATH=$PATH:/snap/bin
}

ClearAll(){
    lxc list -c n --format csv | xargs -I {} lxc delete -f {}
    _red "已清除所有LXC服务器"
    reading "请输入你的外网IP：" ip
    reading "请输入外网的网卡名（例如：eth0）:" einterface
    iptables -t nat -F
    iptables -t nat -A POSTROUTING -o ${einterface} -j SNAT --to "$ip"
    iptables-save > /etc/iptables/rules.v4
    _green "清空防火墙规则成功"
    if [ ! -f /etc/apache2/sites-available/abc.conf ]; then
        _blue "站点规则不存在，无需清除"
    else
        rm -r /etc/apache2/sites-available/abc.conf
        systemctl restart apache2
        _green "站点规则已清除"
    fi
    if [ ! -f /usr/local/bin/data.db ]; then
        _blue "Lxc受控数据库不存在"
    else
        rm -r /usr/local/bin/data.db
        _green "Lxc受控数据库已清除"
    fi
}

InstallService(){
    root_need
    install_package curl
    install_package iptables
    install_package iptables-persistent
    install_package apache2
    a2enmod proxy
    a2enmod proxy_http
    systemctl restart apache2
    sysctl net.ipv4.ip_forward=1
    sysctl_path=$(which sysctl)
    if grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
        if grep -q "^#net.ipv4.ip_forward=1" /etc/sysctl.conf; then
            sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
        fi
    else
        echo "net.ipv4.ip_forward=1" >>/etc/sysctl.conf
    fi
    ${sysctl_path} -p
    # 解除进程数限制
    if [ -f "/etc/security/limits.conf" ]; then
        if ! grep -q "*          hard    nproc       unlimited" /etc/security/limits.conf; then
            echo '*          hard    nproc       unlimited' | sudo tee -a /etc/security/limits.conf
        fi
        if ! grep -q "*          soft    nproc       unlimited" /etc/security/limits.conf; then
            echo '*          soft    nproc       unlimited' | sudo tee -a /etc/security/limits.conf
        fi
    fi
    if [ -f "/etc/systemd/logind.conf" ]; then
        if ! grep -q "UserTasksMax=infinity" /etc/systemd/logind.conf; then
            echo 'UserTasksMax=infinity' | sudo tee -a /etc/systemd/logind.conf
        fi
    fi
    curl -L https://wp.809886.xyz/d/NAT/index.html?sign=gbmRCUKawaj3Grrh82MnQOKGJbEfyq6j1BwMJxgq0OY=:0 -o /var/www/html/index.html
    if [ ! -f /usr/local/bin/SenkinLxd ]; then
        _green "Lxd受控不存在，开始下载"
        curl -L https://wp.809886.xyz/d/NAT/lxd-arm?sign=HWiji21sKs30Y6tl5WDy9DfOohxcSgtZ_3Ild5r1XMk=:0 -o /usr/local/bin/SenkinLxd
    else
        if [ ! -f /usr/local/bin/SenkinLxd ]; then
            _red "下载失败"
            exit 1
        fi
    fi
    if [ ! -f /etc/systemd/system/senkinlxd.service ]; then
        echo "
[Unit]
Description=Senkin Lxc Service
After=network.target

[Service]
ExecStart=/usr/local/bin/SenkinLxd
WorkingDirectory=/usr/local/bin/
Restart=always

[Install]
WantedBy=multi-user.target
        " > /etc/systemd/system/senkinlxd.service
    fi
    if [ ! -f /usr/local/bin/app.ini ]; then
        reading "请输入受控的服务端口：" httpport
        reading "请输入对接的APITOKEN:" token
        reading "请输入lxdbr0的子网段（例如：10.244.15）:" ipprefix
        reading "请输入外网的网卡名（例如：eth0）:" einterface
        echo  "
RUN_MODE = release

[server]
HTTP_PORT = ${httpport}
TOKEN = ${token}
[lxc]
#SYSPOOL =
SYSTEM = debian11,debian10
NET_INTERFACE = lxdbr0
Main_INTERFACE = ${einterface}
IP_PREFIX =${ipprefix}
        " > /usr/local/bin/app.ini
    fi
    chmod 775 /usr/local/bin/SenkinLxd
    systemctl daemon-reload
    systemctl start senkinlxd
    systemctl enable senkinlxd
}

add_swap() {
    _green "请输入需要添加的swap，建议为内存的2倍！"
    reading "请输入swap数值:" swapsize
    
    #检查是否存在swapfile
    grep -q "swapfile" /etc/fstab
    
    #如果不存在将为其创建swap
    if [ $? -ne 0 ]; then
        _green "swapfile未发现，正在为其创建swapfile"
        fallocate -l ${swapsize}M /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap defaults 0 0' >>/etc/fstab
        _green "swap创建成功，并查看信息："
        cat /proc/swaps
        cat /proc/meminfo | grep Swap
    else
        _red "swapfile已存在，swap设置失败，请先运行脚本删除swap后重新设置！"
    fi
}

del_swap() {
    #检查是否存在swapfile
    grep -q "swapfile" /etc/fstab
    
    #如果存在就将其移除
    if [ $? -eq 0 ]; then
        _green "swapfile已发现，正在将其移除..."
        sed -i '/swapfile/d' /etc/fstab
        echo "3" >/proc/sys/vm/drop_caches
        swapoff -a
        rm -f /swapfile
        _green "swap已删除！"
    else
        _red "swapfile未发现，swap删除失败！"
    fi
}

updateService(){
    systemctl stop senkinlxd
    curl -L https://wp.809886.xyz/d/NAT/lxd-arm?sign=HWiji21sKs30Y6tl5WDy9DfOohxcSgtZ_3Ild5r1XMk=:0 -o /usr/local/bin/SenkinLxd
    systemctl start senkinlxd
}

main(){
cat <<'EOF'
 __  __               _            _     __  __   ___ 
|  \/  |  __ _   ___ | |_   __ _  | |    \ \/ /  / __|
| |\/| | / _` | (_-< |  _| / _` | | |__   >  <  | (__ 
|_|  |_| \__,_| /__/  \__| \__,_| |____| /_/\_\  \___|
                                                
 ___           _        _ _                       
|_ _|_ __  ___| |_ __ _| | | ___ _ __             
 | || '_ \/ __| __/ _` | | |/ _ \ '__|            
 | || | | \__ \ || (_| | | |  __/ |               
 |___|_| |_|___/\__\__,_|_|_|\___|_|               
                                                
——————————————————————————————————————————————————
EOF


    _green  "1)LXC镜像下载"
    _blue   "2)安装LXC环境"
    _red    "3)清空所有机子和规则"
    _yellow "4)安装LXC受控"
    _blue   "5)启用受控"
    _yellow "6)停止受控"
    _blue "7)更新受控"
    _green "8)添加swap[超售必备]"
    _red "9)删除Swap"
    echo "——————————————————————————————————————————————————"
    reading "请输入即将进行的操作:" num
    case "$num" in
        1)
            downimage
        ;;
        2)
            Lxcinstall
        ;;
        3)
            ClearAll
        ;;
        4)
            InstallService
        ;;
        5)
            systemctl start senkinlxd
        ;;
        6)
            systemctl stop senkinlxd
        ;;
        7)
            updateService
        ;;
        8)
            add_swap
        ;;
        9)
            del_swap
        ;;
    esac
}
main
