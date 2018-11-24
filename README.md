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
To perform this task you will need to clone this repo and just run the script "AllinOne.sh" in the repository folder.

```
1. git clone https://github.com/arlind87/LAMP_stack.git -b task_server_provision_automation
2. cd LAMP_stack
3. ./AllinOne.sh
```
By default the vagrant Box will be build using virtualbox.
If you want to change the virtualization provider to hyperv just add to the vagrant up command in "AllinOne.sh" script below line:
```
--provider hyperv
```

Author - Arlind 
