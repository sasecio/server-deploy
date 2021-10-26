#!/bin/bash

# INPUT VARIABLES:
# <UDF name="USERNAME" Label="Default login username" />
# <UDF name="PASSWORD" Label="Default login password" />
# <UDF name="GITHUB_UN" Label="GitHub Username" />
# <UDF name="SSHKEY" Label="SSH Public Key" />
# <UDF name="SETUP_FIREWALL_SSH" Label="Open firewall for SSH (Port 22122)" oneOf="yes,no" default="yes" />
# <UDF name="SETUP_FIREWALL_WG" Label="Open firewall for Wireguard (Port 30003)" oneOf="yes,no" default="yes" />
# <UDF name="SETUP_F2B" Label="Fail2ban with default configuration" oneOf="yes,no" default="yes" />
# <UDF name="TIMEZONE" Label="TZ Database Timezone" default="Europe/London" />
# <UDF name="HOST" Label="System Hostname" default="" />
# <UDF name="FQDN" Label="FQDN" default="packetsync.net" />


# Enable logging

exec 1> >(tee -a "/var/log/new_linode.log") 2>&1


# Display branding on login

cat /etc/motd


# Print Stackscript Banner

echo("██████╗  █████╗  ██████╗██╗  ██╗███████╗████████╗███████╗██╗   ██╗███╗   ██╗ ██████╗   ███╗   ██╗███████╗████████╗")
echo("██╔══██╗██╔══██╗██╔════╝██║ ██╔╝██╔════╝╚══██╔══╝██╔════╝╚██╗ ██╔╝████╗  ██║██╔════╝   ████╗  ██║██╔════╝╚══██╔══╝")
echo("██████╔╝███████║██║     █████╔╝ █████╗     ██║   ███████╗ ╚████╔╝ ██╔██╗ ██║██║        ██╔██╗ ██║█████╗     ██║   ")
echo("██╔═══╝ ██╔══██║██║     ██╔═██╗ ██╔══╝     ██║   ╚════██║  ╚██╔╝  ██║╚██╗██║██║        ██║╚██╗██║██╔══╝     ██║   ")
echo("██║     ██║  ██║╚██████╗██║  ██╗███████╗   ██║   ███████║   ██║   ██║ ╚████║╚██████╗██╗██║ ╚████║███████╗   ██║   ")
echo("╚═╝     ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚══════╝   ╚═╝   ╚═╝  ╚═══╝ ╚═════╝╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ")
                                                                                                                  

# Harden SSH Access

sed -i -e 's/#Port 22/Port 22122/g' /etc/ssh/sshd_config
sed -i -e 's/#AddressFamily any/AddressFamily inet/g' /etc/ssh/sshd_config
sed -i -e 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
sed -i -e 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
sed -i -e 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/g' /etc/ssh/sshd_config
sed -i -e 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' /etc/ssh/sshd_config

cat 'AllowUsers $USERNAME' >> /etc/ssh/sshd_config

systemctl restart sshd


# Login account setup

if [ "$USERNAME" != "" ] && [ "$USERNAME" != "root" ]; then
    passwd --lock root
    apt -y install sudo
    adduser $USERNAME --disabled-password --gecos ""
    echo "$USERNAME:$PASSWORD" | chpasswd
    usermod -aG sudo $USERNAME
    SSHOMEDIR="/home/$USERNAME/.ssh"
    mkdir $SSHOMEDIR && echo "$SSHKEY" >> $SSHOMEDIR/authorized_keys
    chmod -R 700 $SSHOMEDIR && chmod 600 $SSHOMEDIR/authorized_keys
    chown -R $USERNAME:$USERNAME $SSHOMEDIR
fi

# Add Github user

#if [ "$GITHUB_USER" != "" ]; then
#    adduser $GITHUB_USER --disabled-password --gecos ""
#    echo "$GITHUB_USER:$PASSWORD" | chpasswd
#    usermod -aG sudo $GITHUB_USER
#    SSHOMEDIR="/home/$GITHUB_USER/.ssh"
#    mkdir $SSHOMEDIR && echo "$SSHKEY" >> $SSHOMEDIR/authorized_keys
#    chmod -R 700 $SSHOMEDIR && chmod 600 $SSHOMEDIR/authorized_keys
#    chown -R $GITHUB_USER:$GITHUB_USER $SSHOMEDIR
#fi


# Update system over IPv4 without any interaction

apt-get -o Acquire::ForceIPv4=true update

DEBIAN_FRONTEND=noninteractive \
  apt-get \
  -o Dpkg::Options::=--force-confold \
  -o Dpkg::Options::=--force-confdef \
  -y --allow-downgrades --allow-remove-essential --allow-change-held-packages


# Configure hostname and configure entry to /etc/hosts

IPADDR=`hostname -I | awk '{ print $1 }'`
echo -e "\n# Added by Packetsync Networks Stackscript" >> /etc/hosts
if [ "$FQDN" == "" ]; then
    FQDN=`dnsdomainname -A | cut -d' ' -f1`
fi
if [ "$HOST" == "" ]; then
    HOSTNAME=`echo $FQDN | cut -d'.' -f1`
else
    HOSTNAME="$HOST"
fi
echo -e "$IPADDR\t$FQDN $HOSTNAME" >> /etc/hosts
hostnamectl set-hostname "$HOSTNAME"


# Configure timezone

timedatectl set-timezone "$TIMEZONE"

if [ "$SETUP_FIREWALL_SSH" == "yes" ]; then
    apt install -y ufw
    ufw default allow outgoing
    ufw default deny incoming
    ufw allow 22122
    ufw enable
fi

if [ "$SETUP_FIREWALL_WG" == "yes" ]; then
    ufw allow 30003
fi

if [ "$SETUP_F2B" == "yes" ]; then
    apt install -y fail2ban
    cp /etc/fail2ban/fail2ban.conf /etc/fail2ban/fail2ban.local
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    systemctl start fail2ban
    systemctl enable fail2ban
fi


# Install networking utils

apt install -y dnsutils net-tools nmap whois netcat


# Install default system utils

apt install -y zsh git powerline fonts-powerline


# Install Wireguard

apt install -y wireguard
wget https://raw.githubusercontent.com/angristan/wireguard-install/master/wireguard-install.sh
chmod +x wireguard-install.sh
./wireguard-install.sh


# Install Unbound

apt install -y unbound


# Core functionality

# Fetch GitHub SSH Keys

function get_github_keys {
    GITHUBKEYS="https://github.com/${1}.keys"
    if [ ! -n "$GITHUB_USER" ]; then
        echo "Error: Username required."
        return 1;
    fi

    adduser $GITHUB_USER --disabled-password --gecos ""
    HOMEDIR="$(grep "$GHUSER" /etc/passwd | cut -f6 -d:)"
    mkdir -p $HOMEDIR/.ssh
    echo "$GITHUB_USER:$PASSWORD" | chpasswd
    wget -q -O- "${GITHUBKEYS}" >> "$HOMEDIR/.ssh/authorized_keys"
    chown -R "$GHUSER":"$GHUSER" "$HOMEDIR/.ssh"
    chmod 600 "$HOMEDIR/.ssh/authorized_keys"
    usermod -aG sudo $GITHUB_USER
}
