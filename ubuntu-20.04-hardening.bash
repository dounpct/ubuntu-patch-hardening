#!/bin/bash

# ChangeLog
#
# ChangeLog

# run with root

AUDITDIR="/root/$(hostname -s)_hardening"
AUDITLOG="/root/$(hostname -s)_hardening/$(hostname -s).log"
RUN_TIME="$(date +%F_%T)"
. /etc/os-release
MAIN_VERSION_ID="$(echo ${VERSION_ID} |cut -f1 -d'.')"
FULL_VERSION_ID=${VERSION_ID}

if [[ ${MAIN_VERSION_ID} -lt 20 ]]; then
  echo "we have test only version 20.04 and your version is ${FULL_VERSION_ID}"
fi

mkdir -p $AUDITLOG

#----------------------------------------------------

echo "Setting core dump security limits"
echo '* hard core 0' > /etc/security/limits.conf

#----------------------------------------------------

echo "Set login.defs (effect with new user)"
upgrade_path=/etc/login.defs
for i in \
"PASS_MAX_DAYS 365" \
"PASS_MIN_DAYS 7" \
"PASS_WARN_AGE 7" \
; do
  [[ `egrep "^${i}" ${upgrade_path}` ]] && continue
  option=${i%% *}
  grep -q "^${option}" ${upgrade_path} && sed -i "s/^${option}.*/$i/g" ${upgrade_path} || echo "$i" >> ${upgrade_path}
done

#----------------------------------------------------

sed -i "s/^UMASK.*/UMASK 027/g" /etc/login.defs

#----------------------------------------------------

cat > /etc/modprobe.d/CIS.conf << "EOF"
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install squashfs /bin/true
install udf /bin/true
install dccp /bin/true
install sctp /bin/true
install rds /bin/true
install tipc /bin/true
install usb-storage /bin/true
install vfat /bin/true
EOF

#----------------------------------------------------

echo "Configuring SSH"
upgrade_path=/etc/ssh/sshd_config
cp ${upgrade_path} $AUDITDIR/sshd_config_$TIME.bak
for i in \
"LogLevel VERBOSE" \
"Protocol 2" \
"X11Forwarding no" \
"MaxAuthTries 3" \
"IgnoreRhosts yes" \
"HostbasedAuthentication no" \
"PermitRootLogin no" \
"PermitEmptyPasswords no" \
"PermitUserEnvironment no" \
"ClientAliveInterval 300" \
"ClientAliveCountMax 2" \
"LoginGraceTime 60" \
"UsePAM yes" \
"MaxStartups 10:30:60" \
"AllowTcpForwarding no" \
"AllowAgentForwarding no" \
"TCPKeepAlive no" \
"Compression no" \
"MaxSessions 2" \
"Ciphers aes128-ctr,aes192-ctr,aes256-ctr" \
; do
  [[ `egrep -q "^${i}" ${upgrade_path}` ]] && continue
  option=${i%% *}
  grep -q ${option} ${upgrade_path} && sed -i "s/.*${option}.*/$i/g" ${upgrade_path} || echo "$i" >> ${upgrade_path}
done

#----------------------------------------------------

# reset mod
echo "Configuring Cron"
for i in crontab cron.hourly cron.daily cron.weekly cron.monthly; do
  chown root:root /etc/$i
  chmod 600 /etc/$i
done
chmod 700 /etc/cron.d

echo "Verifying System File Permissions"
#(6.4) 10690 Status of the Permissions set for the '/etc/passwd-' file
chmod 600 /etc/passwd-
#(6.6) 2188 Permissions set for the '/etc/shadow' file
chmod 000 /etc/shadow
chmod 000 /etc/gshadow
chmod 644 /etc/group
# grub.cfg won't exist on an EFI system
if [ -f /boot/grub2/grub.cfg ]; then
 chmod 600 /boot/grub2/grub.cfg
fi
chmod 600 /etc/at.deny
chmod 750 /etc/sudoers.d
chmod 600 /etc/rsyslog.conf
chown root:root /etc/passwd
chown root:root /etc/shadow
chown root:root /etc/gshadow
chown root:root /etc/group
# reset mod

upgrade_path=/etc/ssh/sshd_config
chown root:root ${upgrade_path}
chmod 600 ${upgrade_path}
chmod 0600 /etc/ssh/ssh_host*key

#----------------------------------------------------

# install AIDE
echo "Install AIDE (advanced intrusion detection environment)"
apt install aide -y
FILE=/var/lib/aide/aide.db
if [ -f "$FILE" ]; then
    echo "$FILE exists."
else
    echo "$FILE does not exist."
    aideinit
    cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
    update-aide.conf
fi
# install AIDE

#----------------------------------------------------

# update swap for Docker Comment this if you don't install docker
status="$(docker info 2>&1 | grep -q "WARNING: No swap limit support" && echo "NO_SWAP" || echo "HAVE_SWAP")"
echo $status
if [ "$status" == "NO_SWAP" ]; then
  upgrade_path=/etc/default/grub
  for i in \
  "GRUB_CMDLINE_LINUX=\"cgroup_enable=memory swapaccount=1\"" \
  ; do
    [[ `grep -q "^$i" ${upgrade_path}` ]] && continue
    option=${i%%=*}
    if [[ `grep "^${option}=" ${upgrade_path}` ]]; then
      sed -i "s/^${option}=.*/$i/g" ${upgrade_path}
    else
      echo "${i}" >> ${upgrade_path}
    fi
  done
  update-grub
fi
# update swap for Docker Comment this if you don't install docker

#----------------------------------------------------

chmod 750 /home/*

#----------------------------------------------------

# password
echo "Install libpam-pwquality (password quality)"
apt -y install libpam-pwquality
echo "Setting Password Quality policies"
upgrade_path=/etc/security/pwquality.conf
for i in \
"minlen = 14" \
"dcredit = -1" \
"ucredit = -1" \
"ocredit = -1" \
"lcredit = -1" \
"retry = 3" \
"minclass = 4" \
; do
  [[ `grep -q "^$i" ${upgrade_path}` ]] && continue
  option=${i%%=*}
  if [[ `grep "^${option}" ${upgrade_path}` ]]; then
    sed -i "s/^${option}.*/$i/g" ${upgrade_path}
  else
    echo "${i}" >> ${upgrade_path}
  fi
done

#----------------------------------------------------

dpkg -l | grep '^rc' | awk '{print $2}'
sudo apt-get -y purge $(dpkg -l | grep '^rc' | awk '{print $2}')

#----------------------------------------------------

echo "change Banner"
sed -i "s/\#Banner none/Banner \/etc\/issue\.net/" /etc/ssh/sshd_config
cat > /etc/issue.net << 'EOF'
/------------------------------------------------------------------------\
|                       *** NOTICE TO USERS ***                          |
|       LOG OFF IMMEDIATELY if you don't have authorization              |
\------------------------------------------------------------------------/
EOF
cat > /etc/motd << 'EOF'
LOCAL Group. Authorized Use Only
EOF
rm -rf /etc/issue
ln -s /etc/issue.net /etc/issue

#----------------------------------------------------

echo "Modifying Network Parameters"
cp /etc/sysctl.conf /etc/sysctl.conf.bak

cat > /etc/sysctl.d/99-CIS.conf << 'EOF'
dev.tty.ldisc_autoload=0
fs.protected_fifos=2
fs.protected_hardlinks=1
fs.protected_regular=2
fs.protected_symlinks=1
fs.suid_dumpable=0
kernel.core_uses_pid=1
kernel.ctrl-alt-del=0
kernel.dmesg_restrict=1
kernel.kptr_restrict=2
kernel.perf_event_paranoid=3
kernel.randomize_va_space=2
kernel.sysrq=0
kernel.unprivileged_bpf_disabled=1
kernel.yama.ptrace_scope=123
net.core.bpf_jit_harden=2
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.all.bootp_relay=0
net.ipv4.conf.all.forwarding=0
net.ipv4.conf.all.log_martians=1
net.ipv4.conf.all.mc_forwarding=0
net.ipv4.conf.all.proxy_arp=0
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.default.accept_source_route=0
net.ipv4.conf.default.log_martians=1
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.icmp_ignore_bogus_error_responses=1
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_timestamps=01
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.all.accept_source_route=0
net.ipv6.conf.default.accept_redirects=0
net.ipv6.conf.default.accept_source_route=0
EOF

#----------------------------------------------------

echo ""
echo "Successfully Completed"
echo "Please check $AUDITDIR"