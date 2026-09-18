#!/bin/bash
# Oracle Cloud 实例优化脚本
# 整合：开启root登录 / 清理开屏信息 / 卸载无用服务 / 限制日志大小 / 安装 fail2ban
set -e

echo "===== 第一步：开启root登录，清除开屏信息 ====="
sudo bash -c 'mkdir -p /root/.ssh && cp /home/ubuntu/.ssh/authorized_keys /root/.ssh/authorized_keys && chown -R root:root /root/.ssh && chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys && sed -i "s/^#\{0,1\}PermitRootLogin.*/PermitRootLogin prohibit-password/" /etc/ssh/sshd_config && sed -i "s/^#\{0,1\}PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config && (grep -q "^disable_root" /etc/cloud/cloud.cfg && sed -i "s/^disable_root:.*/disable_root: false/" /etc/cloud/cloud.cfg || echo "disable_root: false" >> /etc/cloud/cloud.cfg) && chmod -x /etc/update-motd.d/* && truncate -s 0 /etc/motd && sed -i "/pam_motd/ s/^/#/" /etc/pam.d/sshd && sed -i "/pam_motd/ s/^/#/" /etc/pam.d/login && systemctl restart ssh && echo DONE'

echo "===== 第二步：清理服务 + 卸载 + 缓存清理 ====="
sudo systemctl disable --now ModemManager.service fwupd.service open-vm-tools.service apport.service snap.oracle-cloud-agent.oracle-cloud-agent.service snap.oracle-cloud-agent.oracle-cloud-agent-updater.service 2>/dev/null; sudo snap remove oracle-cloud-agent; sudo apt purge -y fwupd modemmanager open-vm-tools apport; sudo apt autoremove -y; sudo apt clean; sudo rm -rf /var/cache/fwupd/* /var/cache/swcatalog/*

echo "===== 第三步：限制日志大小 ====="
sudo sed -i 's/^#\?SystemMaxUse=.*/SystemMaxUse=100M/; s/^#\?RuntimeMaxUse=.*/RuntimeMaxUse=50M/' /etc/systemd/journald.conf
sudo systemctl restart systemd-journald
sudo journalctl --vacuum-size=100M
sudo tee /etc/logrotate.d/rsyslog > /dev/null << 'EOF'
/var/log/syslog
/var/log/mail.log
/var/log/kern.log
/var/log/auth.log
/var/log/user.log
/var/log/cron.log
{
	rotate 7
	daily
	missingok
	notifempty
	compress
	delaycompress
	sharedscripts
	su root root
	size 50M
	postrotate
		/usr/lib/rsyslog/rsyslog-rotate
	endscript
}
EOF
sudo logrotate -f /etc/logrotate.d/rsyslog

echo "===== 第四步：安装并配置 fail2ban ====="
sudo apt install -y fail2ban
sudo tee /etc/fail2ban/jail.local > /dev/null << 'EOF'
[DEFAULT]
bantime = 24h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
EOF
sudo systemctl enable --now fail2ban
sudo systemctl restart fail2ban

echo "===== 全部完成 ====="
