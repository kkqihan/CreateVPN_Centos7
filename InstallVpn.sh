#!/bin/bash

vpn_account=${1}
vpn_passwd=${2}

if [[ ${vpn_account} == "" || ${vpn_passwd} == "" ]]; then
    echo -e "请输入账号密码,如: \n\t./InstallVpn.sh  account passwd"
else
    echo -e "账号: ${vpn_account} 密码: ${vpn_passwd}"
fi

# 切换权限
su root

# 安装软件
yum -y install epel-release
yum -y install firewalld net-tools ppp pptpd

# 开启内核转发
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
sysctl -p

#添加pptp的登录账号密码，账号是admin 密码admin888
echo  "${vpn_account} *  ${vpn_passwd} *" >> /etc/ppp/chap-secrets

# 开启客户端虚拟IP分配
sed -i 's/#localip 192.168.0.1/localip 192.168.0.1/' /etc/pptpd.conf
sed -i 's/#remoteip 192.168.0.234-238,192.168.0.245/remoteip 192.168.0.2-254/' /etc/pptpd.conf

# 添加 pptp 的DNS解析服务器 格式：ms-dns 8.8.8.8 ，ip改为你自己的可以了
sed -i 's/#ms-dns 10.0.0.1/ms-dns 192.168.0.1/' /etc/ppp/options.pptpd
sed -i 's/#ms-dns 10.0.0.2/ms-dns 8.8.8.8/' /etc/ppp/options.pptpd
exit 0

# Firewall 通过防火墙规则
ens=$(ls /etc/sysconfig/network-scripts/ | grep 'ifcfg-e.*[0-9]' | cut -d- -f2)
systemctl restart firewalld.service
systemctl enable firewalld.service
firewall-cmd --set-default-zone=public
firewall-cmd --add-interface=m=$ens
firewall-cmd --add-port=1723/tcp --permanent
firewall-cmd --add-masquerade --permanent
firewall-cmd --permanent --direct --add-rule ipv4 filter INPUT 0 -i $ens -p gre -j ACCEPT
firewall-cmd --reload
# 修改Mtu
cat >/etc/ppp/ip-up.local <<END
/sbin/ifconfig \$1 mtu 1400
END
chmod +x /etc/ppp/ip-up.local
# 重启pptpd
systemctl restart pptpd.service
systemctl enable pptpd.service
