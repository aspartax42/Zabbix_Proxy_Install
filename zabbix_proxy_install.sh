#!/bin/bash -e

if [ "$UID" -ne 0 ]; then
  echo "Merci d'exécuter en root"
  exit 1
fi

# Principaux paramètres
tput setaf 7; read -p "Entrer le mot de passe root de la base de données: " ROOT_DB_PASS
tput setaf 7; read -p "Entrer le mot de passe zabbix de la base de données: " ZABBIX_DB_PASS
tput setaf 7; read -p "Entrer le nom du proxy: " ZABBIX_PROXY_HOSTNAME
tput setaf 7; read -p "Entrer le nom de l'indentité PSK: " PSK_ID

tput setaf 2; echo ""

# Récupération du paquet Zabbix 4.4
#	rm zabbix-release_4.4-1+buster_all.*

cd /tmp

wget https://repo.zabbix.com/zabbix/4.4/debian/pool/main/z/zabbix-release/zabbix-release_4.4-1%2Bbuster_all.deb

# Ajout de la variable PATH qui peux poser problème
export PATH=$PATH:/usr/local/sbin
export PATH=$PATH:/usr/sbin
export PATH=$PATH:/sbin

# Décompression du paquet
dpkg -i zabbix-release_4.4-1+buster_all.deb

# Mise à jour suite à l'ajout de Zabbix Release dans les sources.list
apt update

# Installation de zabbix-proxy-mysql
apt -y install zabbix-proxy-mysql

# Changement du mdp de la base de données MySQL
mysql_secure_installation <<EOF
y
ROOT_DB_PASS
ROOT_DB_PASS
y
y
y
y
EOF




# Configuration de la base de données
mysql -uroot -p'$ROOT_DB_PASS' -e "drop database if exists zabbix_proxy;"

mysql -uroot -p'$ROOT_DB_PASS' -e "drop user if exists zabbix@localhost;"

mysql -uroot -p'$ROOT_DB_PASS' -e "create database zabbix_proxy character set utf8 collate utf8_bin;"

mysql -uroot -p'$ROOT_DB_PASS' -e "grant all on zabbix_proxy.* to 'zabbix'@'%' identified by '"$ZABBIX_DB_PASS"' with grant option;"


# Ajout de la table SQL dans notre DB zabbix_proxy


mysql -uroot -p'$ROOT_DB_PASS' -D zabbix_proxy -e "set global innodb_strict_mode='OFF';"

zcat /usr/share/doc/zabbix-proxy-mysql*/schema.sql.gz |  mysql -u zabbix --password=$ZABBIX_DB_PASS zabbix_proxy

mysql -uroot -p'$ROOT_DB_PASS' -D zabbix_proxy -e "set global innodb_strict_mode='ON';"

# Execution du script de modification du fichier /etc/zabbix/zabbix_proxy.conf
echo "Server=monitoring.stodeo.com" > /etc/zabbix/zabbix_proxy.conf
echo "Hostname="$ZABBIX_PROXY_HOSTNAME"" >> /etc/zabbix/zabbix_proxy.conf

echo "Conf Debut OK"

echo "" >> /etc/zabbix/zabbix_proxy.conf

echo "LogFile=/var/log/zabbix/zabbix_proxy.log" >> /etc/zabbix/zabbix_proxy.conf
echo "LogFileSize=1024" >> /etc/zabbix/zabbix_proxy.conf

echo "" >> /etc/zabbix/zabbix_proxy.conf

echo "DBName=zabbix_proxy" >> /etc/zabbix/zabbix_proxy.conf
echo "DBUser=zabbix" >> /etc/zabbix/zabbix_proxy.conf
echo "DBPassword="$ZABBIX_DB_PASS >> /etc/zabbix/zabbix_proxy.conf

echo "" >> /etc/zabbix/zabbix_proxy.conf
echo "" >> /etc/zabbix/zabbix_proxy.conf

echo "#====== PROXY SPECIFIC PARAMETERS =======" >> /etc/zabbix/zabbix_proxy.conf

echo "" >> /etc/zabbix/zabbix_proxy.conf

echo "ConfigFrequency=60" >> /etc/zabbix/zabbix_proxy.conf

echo "" >> /etc/zabbix/zabbix_proxy.conf

echo "#====== ADVANCED PARAMETERS =======" >> /etc/zabbix/zabbix_proxy.conf

echo "StartPollers=10" >> /etc/zabbix/zabbix_proxy.conf
echo "StartPollersUnreachable=2" >> /etc/zabbix/zabbix_proxy.conf
echo "StartPingers=5" >> /etc/zabbix/zabbix_proxy.conf
echo "StartDiscoverers=5" >> /etc/zabbix/zabbix_proxy.conf
echo "CacheSize=128M" >> /etc/zabbix/zabbix_proxy.conf
echo "HistoryIndexCacheSize=100M" >> /etc/zabbix/zabbix_proxy.conf
echo "Timeout=30" >> /etc/zabbix/zabbix_proxy.conf
echo "ExternalScripts=/usr/lib/zabbix/externalscripts" >> /etc/zabbix/zabbix_proxy.conf
echo "FpingLocation=/usr/bin/fping" >> /etc/zabbix/zabbix_proxy.conf
echo "Fping6Location=/usr/bin/fping6" >> /etc/zabbix/zabbix_proxy.conf
echo "LogSlowQueries=3000" >> /etc/zabbix/zabbix_proxy.conf

echo "" >> /etc/zabbix/zabbix_proxy.conf

echo "StartVMwareCollectors=5" >> /etc/zabbix/zabbix_proxy.conf
echo "VMwareFrequency=60" >> /etc/zabbix/zabbix_proxy.conf
echo "VMwareCacheSize=8M" >> /etc/zabbix/zabbix_proxy.conf
echo "VMwareTimeout=10" >> /etc/zabbix/zabbix_proxy.conf


echo "" >> /etc/zabbix/zabbix_proxy.conf

echo "#====== TLS-RELATED PARAMETERS =======" >> /etc/zabbix/zabbix_proxy.conf

echo "" >> /etc/zabbix/zabbix_proxy.conf

echo "TLSConnect=psk" >> /etc/zabbix/zabbix_proxy.conf
echo "TLSPSKFile=/etc/zabbix/zabbix_proxy.psk" >> /etc/zabbix/zabbix_proxy.conf
echo "TLSPSKIdentity="$PSK_ID"" >> /etc/zabbix/zabbix_proxy.conf


echo "Fin fichier conf"

systemctl restart zabbix-proxy
systemctl enable zabbix-proxy


# Génération de la clé PSK
openssl rand -hex 32 > /etc/zabbix/zabbix_proxy.psk
chown zabbix:zabbix /etc/zabbix/zabbix_proxy.psk
chmod 644 /etc/zabbix/zabbix_proxy.psk

systemctl restart zabbix-proxy

echo "PSK OK"


echo "Zabbix actif"

clear
echo "-------------------------------------------------"
echo "       => Installation terminée <=       "
echo ""
echo "Voici le nom du proxy: "$ZABBIX_PROXY_HOSTNAME""
echo ""
echo "Voici la clé PSK généré automatiquement: "
echo ""
cat /etc/zabbix/zabbix_proxy.psk

echo ""
echo ""
echo "       By Lilian COLLARD       "
