## Create scripts to provision a new server and deploy code from git

These scripts will be used to install a Lamp stack with all the needed components.
After deploying the scripts a new CentOS7 VM will be created via a Vagrant file with the following components:
- nginx
- 3 instances of MySQL 5.7
- PHP7
- Memcache
- ElasticSearch
- SFTP
- Composer
- NPM
- GIT

Opened Ports: 22, 80, 3306, 9200

#### Dependecies
The PC that will be used to run these scripts should have vagrant installed.
Vagrant can be downloaded from this link:
https://www.vagrantup.com/downloads.html

#### Use Case:
```
git clone https://github.com/sroutier/Laravel-Enterprise-Starter-Kit.git -b task_server_provision_automation
cd task_server_provision_automation
./AllinOne.sh
```
By default the vagrant Box will be build using virtualbox.
If you want to change the virtualization provider to hyperv just make add to the vagrant up command in "AllinOne.sh" below line:
```
--provider hyperv
```

Author - Arlind 
