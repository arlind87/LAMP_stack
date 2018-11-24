#!/bin/bash
# Single server, LAMP Stack Installation with MySQL Multi-Instances
# Tech-project task

#############################################################
echo " #########Starting firewall....##############"
sudo systemctl start firewalld
sudo systemctl enable firewalld

echo " #########Intalling epel packages...##############"
sudo yum -y install epel-release

#############################################################
echo " #########Intalling Nginx...###############"
sudo yum -y install nginx
sudo systemctl enable nginx
#Open Nginx port as per Firewall rules requested
sudo firewall-cmd --add-port=80/tcp
sudo firewall-cmd --add-port=80/tcp --permanent

###############################################################
echo " #########Intalling 3 MySQL 5.7 Instances...###################"
#Install needed packages
sudo sudo yum localinstall https://dev.mysql.com/get/mysql57-community-release-el7-9.noarch.rpm -y
sleep 10s
sudo sudo yum install mysql-server -y 
 
############################################################
echo " #########Enabling multi-instance MySQL Systemd setup####################"

cat >~/mysqld@.service <<EOF
[Unit]
After=network.target
After=syslog.target

[Install]
WantedBy=multi-user.target

[Service]
User=mysql
Group=mysql
Type=forking
PIDFile=/var/lib/mysql-%i/mysqld-%i.pid
TimeoutSec=0
PermissionsStartOnly=true
ExecStartPre=/usr/bin/mysqld_pre_systemd %I
ExecStart=/usr/sbin/mysqld --defaults-file=/etc/my%i.cnf --datadir=/var/lib/mysql-%i --pid-file=/var/lib/mysql-%i/mysqld-%i.pid --daemonize
LimitNOFILE = 5000
Restart=on-failure
RestartPreventExitStatus=1
PrivateTmp=false
EOF

sudo cp ~/mysqld@.service /etc/systemd/system/mysqld@.service
sudo systemctl daemon-reload

#########################################################################
echo " #########Create config files for each instance...###############"
sleep 5s

for x in {1..3}; do {
if [ $x == 2 ]
then
y=2
else
y=0
fi
cat >~/my${x}.cnf <<EOF
[mysqld]
socket     = /var/lib/mysql-${x}/mysql.sock
port       = `echo "$((3306+(${x}-1)+${y}+2*(${x}-1)))"`
datadir    = /var/lib/mysql-${x}
log_error  = /var/lib/mysql-${x}/mysql-error.log
user       = mysql
server-id  = ${x}
EOF
sudo cp ~/my${x}.cnf /etc/my${x}.cnf
}
done

#####################################################################
echo " #########Creating Directories and give correct permissions for each instance... #########################"
sleep 10s

for x in {1..3}; do
sudo mkdir -p /var/lib/mysql-${x}
done
 
for x in {1..3}; do
sudo chown -R mysql:mysql /var/lib/mysql-${x}
done

# Manage Selinux attributes for the newly created folders in case selinux is enabled.
#sudo restorecon -vvRF /var/lib/mysql-*

echo "#########Add Selinux port fcontext so that instances will be started properly...###########"
sudo yum install policycoreutils-python -y

sudo semanage port -a -t mysqld_port_t -p tcp 3306
sleep 10s
sudo semanage port -a -t mysqld_port_t -p tcp 3311
sleep 10s
sudo semanage port -a -t mysqld_port_t -p tcp 3312

for x in {1..3}; do
sudo semanage fcontext -a -t mysqld_db_t "/var/lib/mysql-${x}(/.*)?"
done
for x in {1..3}; do
sudo restorecon -R -v /var/lib/mysql-${x}
done

sleep 10s

#####################################################################

echo "##############Initialize MySQL Instances...################"

for x in {1..3}; do
sudo mysqld --datadir=/var/lib/mysql-${x} --log-error=/var/lib/mysql-${x}/mysql-error.log --initialize
done

# Reassure that Datadir ownership is set to mysql
for x in {1..3}; do
sudo chown -R mysql:mysql /var/lib/mysql-${x}
done

#remove the setup build during install, since is for single MySQL instance
sudo rm -rf /var/lib/mysql/*
sudo systemctl stop mysqld
sudo systemctl disable mysqld


###########################################################################
#SET again Selinux fcontext just for double check :)

for x in {1..3}; do
sudo semanage fcontext -a -t mysqld_db_t "/var/lib/mysql-${x}(/.*)?"
done
for x in {1..3}; do
sudo restorecon -R -v /var/lib/mysql-${x}
done

###############################################################################

echo " #########Start MySQL instances"

for x in {1..3}; do
sudo systemctl start mysqld@${x}
done

#Enable MySQL Instances at startup

for x in {1..3}; do
sudo systemctl enable mysqld@${x}
done

#############################################################################

sleep 20s

echo "##############Assigning root user to DB...#####################"

for x in {1..3}; do
sudo cat /var/lib/mysql-${x}/mysql-error.log | gawk -F " " '/root\@localhost/ {print $NF}' > ~/pass
sudo chown vagrant:vagrant ~/pass
PWORD=`cat ~/pass | head -1`
sudo mysql --connect-expired-password -S /var/lib/mysql-${x}/mysql.sock -p${PWORD} -e "SET SQL_LOG_BIN=0;ALTER USER 'root'@'localhost' IDENTIFIED BY 'P@ssw0rd';SET SQL_LOG_BIN=1;"
sleep 10s
done

sudo echo -e "[client]\nuser=root\npassword=P@ssw0rd\n" > ~/.my.cnf
sudo cp ~/.my.cnf /root/.my.cnf
sudo chmod 600 /root/.my.cnf

###################################################
echo " #########Opening Mysql port as per Firewall rules requested.... ######################"
sudo firewall-cmd --add-port=3306/tcp
sudo firewall-cmd --add-port=3306/tcp --permanent

###################################################
echo " #########Installing PHP7...################"
sudo yum install http://rpms.remirepo.net/enterprise/remi-release-7.rpm -y
sudo yum-config-manager --enable remi-php70
sudo yum install php php-mcrypt php-cli php-gd php-curl php-mysql php-ldap php-zip php-fileinfo -y

###################################################
echo " #########Installing Memcached...##############"

sudo yum clean all
sudo yum install -y memcached
sudo systemctl enable memcached

##################################################
echo " #########Installing ElasticSearch...#################"
# add repo for Elasticsearch 
cat >~/elasticsearch-6.x.repo <<EOF
[elasticsearch-6.x]
name=Elasticsearch repository for 6.x packages
baseurl=https://artifacts.elastic.co/packages/6.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF

sudo cp ~/elasticsearch-6.x.repo /etc/yum.repos.d/elasticsearch-6.x.repo

sudo yum install java-1.8.0-openjdk -y
sudo yum install elasticsearch -y
sudo systemctl daemon-reload
sudo systemctl enable elasticsearch


echo " #########Opening Elasticsearch port as per Firewall rules requested....###############"
sudo firewall-cmd --add-port=9200/tcp
sudo firewall-cmd --add-port=9200/tcp --permanent

####################################################
echo " #########Setting up SFTP...##########################"

# Add SFTP user
sudo adduser sftpuser
sudo echo -e "p@ssw0rd123\np@ssw0rd123" | (passwd sftpuser)

#add needed directories for SFTP
sudo mkdir -p /var/sftp/uploads
sudo chown root:root /var/sftp
sudo chmod 755 /var/sftp
sudo chown sftpuser:sftpuser /var/sftp/uploads

#Config SFTP access
cat >~/sshd_config <<EOF
Match User sftpuser
ForceCommand internal-sftp
PasswordAuthentication yes
ChrootDirectory /var/sftp
PermitTunnel no
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
EOF

sudo cat ~/sshd_config >> /etc/ssh/sshd_config

echo "#########Opening port 22...###############"
sudo firewall-cmd --add-port=22/tcp
sudo firewall-cmd --add-port=22/tcp --permanent

######################################################
echo "#########Installing Composer...#############"

sudo php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer

######################################################
echo "#########Installing NPM...################"
sudo yum install npm -y

######################################################
echo "#########Installing GIT...##################"
sudo yum install git -y

######################################################
#Restart SSH service
echo "#########Restarting SSH service... #################"
sudo systemctl restart sshd