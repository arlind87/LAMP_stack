## Create a transition plan for upgrading servers with no to minimal downtime
##############################################################################

#### Requirements

I should write a plan for transitioning production servers from Centos6 + PHP5.5 + MySQL 5.5 to Centos7 + PHP7 + MySQL 5.7
TO be assumed that there is 1 load balancer , 5 web servers, and 3 database servers

Based on the provided Info we have 8 servers in Total. For DB servers I will assume we have 1 Master + 2 Slaves. Also for better HA I have added a HAproxy in front of the MySQL server so that in case there is a replication lag it can remove one of the slaves.


                                                  HL Diagram
                                              -----------------

				                      -----------------
					              | Load Balancer |
                                                  -----------------
						             |
		                                             |
	              ---------------------------------------------------------------------------------                                                   |                  |                     |                   |                    |					
                  |                  |                   |                   |                   |
           --------------     --------------      --------------      --------------      --------------
           | Web Server |     | Web Server |      | Web Server |      | Web Server |      | Web Server |
	       --------------     --------------      --------------      --------------      --------------
                  |                  |                    |                   |                   |
	    	      |		         |                    |                   |                   |
                  ---------------------------------------------------------------------------------
				                              |
		                              Write    -----------------    Read
                                     |-------------|    HA Proxy   |------------|
                                     |             -----------------            |
                                     |                     | Read               |
		                   -------------         -------------         -------------
			           | DB Server |---------| DB Server |         | DB Server |
			           -------------         -------------         -------------
                                     | Master             Slave                 | Slave
                                     |                                          |
                                     --------------------------------------------
	                                               Master/Slave



#### Upgrade Plan

##### 1. Order of Upgrade

	1. CentOs6 -> CentOs7
	2. MySQL 5.5 -> MySQL 5.7
	3. PHP5.5 -> PHP7

##### 1.1 Centos Upgrade

Centos 6.x support in-place upgrade meaning that there is no need to re-install from scratch the OS on the Servers.
For this purpose there are already two tools available:
    - Preupgrade Assistant: Will scan your system and determine what your upgrade status is.
	- redhat-upgrade-tool-cli: This tools does the actual upgrade

Prerequisites:
	- Before Proceeding we should plan a backup strategy in case something goes wrong
	- We should plan what checks should be performed after the upgrade
	- We should decide what order of servers to upgrade

	Backup to be considered:
	- File-system backup:  A full-server snapshot backup is a complete file-system backup that preserves your entire server from a specific point in time
	- Database dump:  Maybe a SQL dump or something similar is better that will get a human-readable file of SQL commands, which can be imported to any other server running the same database type.

	What checks Should be considered after the upgrade:
	- Check that the system behaves as expected after the upgrade
	- Web Servers that will be upgraded should be checked for any impact on customer facing web-site
	- Check that there is no impact in MySQL availability, and replication works as expected
	- System metrics and logs should be checked and compared with metrics before the upgrade in order to observe any anomaly.

Order of Upgrade:
        - 5 Web Servers
	- 3 DB Servers

First we start by upgrading one Web Server using the above two tools. If everything works as expected we than proceed by running the needed checks to make sure that behavior is as per our expectations.
Check server Metrics and logs related to OS parameters and observe if there is any change compared to data collected prior to Upgrade.
Allow for 24 hours of monitoring than if everything is fine proceed with the other 4 servers.

The Same process should be repeated for DB servers. In this case we should first upgrade one of the slave DB servers to make sure nothing unexpected occurs.
After the upgrade finishes successfully we proceed with the same checks and further to this check the consistency of MySQL database and replication compared to the other DB Servers.
We check different DB metrics and if after 2 days of monitoring everything works as expected we than switch this DB server role to master and upgrade the other two DB servers (we make sure to save the last transaction ID from the Master MySQL server after switching to Slave).
After the upgrade finishes for the other 2 DB servers we than return the master role back to its original MySQL server.

###### Note: We should keep an eye specially on metrics and logs that have a reoccurring pattern on a daily or weekly basis. Those might be an indication of a possible issue in the system that needs to be checked.

##### 1.2 MySQL Upgrade

Prerequisite Before the Upgrade
	- Make sure you have a Backup for the Databases
	- Download the needed Repository for the new version of MySQL
	- Check dependencies of new Version and see the Compatibility with the other packages installed in the MySQL Servers
	- Make sure there are no errors or other issues present in the MySQL server that will be upgraded
	- Prepare the order of Upgrade for the MySQL servers
	- Prepare a contingency plan in case there is any major issue present after the upgrade

Regarding the upgrade process of MySQL DB there is a tool "mysql_upgrade" that handles system tables upgrades, which is very helpful during the upgrade.

###### Note: Upgrading from MySQL 5.5 to MySQL 5.7 requires to upgrade every table that have TIME, DATETIME, and TIMESTAMP columns, in order to add support for fractional seconds precision

We first do the Upgrade with one of the Slave MySQL servers. After Upgrade finishes successfully including all the necessary checks we than proceed by upgrading the other slave DB Server.
In the second Slave DB node since we already have a running DB node in version 5.7, we just use a backup-restore solution similar to "innobackupex" in order to make the restore process much faster and than upgrading the tables via a mysql_upgrade which can make the process very lengthy if there are lots of data to be restored.
Before upgrading the last DB server which is also the Master DB, we should first make sure to switch the Master role to one of the newly upgraded Slave nodes.
To help in this process we should instruct load balancer to allow writes on the Slave DB node that will become the master Node and than restart all the writing processes on the Master DB node to kill the remaining connections.
After Slave DB node is now Master DB now, and after checking that the status of MySQL replication works as expected we than proceed on upgrading the last DB node.
After finishing the upgrade on the last node we run a backup-restore solution similar as per second DB node to restore the tables.
When all three DB servers are upgraded successfully and no anomaly is observed we switch back the master role to the initial master DB node.

To be considered when upgrading that when we switch the masters roles we should keep the last transaction executed on master, so that in case of any problems we have the chance to stop the process,
exported the missing transactions and load the data and switch back to original master.

##### 1.3 PHP Upgrade

Prerequisite Before the Upgrade
	- Backup any custom config files (ex, /etc/php.ini , /etc/php-fpm.d/www.conf , etc...)
	- Check dependencies of new Version and see the Compatibility with the other packages
	- Determine the order of upgrade by choosing first the server with lowest priority from business perspective (ex, the server that handles less request than others)
	- Prepare a contingency plan in case things do not go as expected
	- Determine e test list to be done after the upgrade


We begin by removing existing PHP packages. After old packages are removed we proceed by installing the new PHP 7 packages. We check the installed php version via the "php -v" command.
When Installation is finished depending on the Web Server we use, Apache or Nginx, we need to check respective socket paths they are using to handle PHP files and config files in order to make sure that there is no issue present.
Based on the old Config files that we saved prior to upgrade, we will need to go through the newly config files on the upgraded PHP system and make the necessary changes.
For Testing we can create a test file in the web server's document root. Although its location depends on your server configuration, the document root is typically set to one of these directories:
/var/www/html
/var/www/
/usr/share/nginx/html

We use a text editor and past the following text to info.php file
```
info.php
<?php
phpinfo();
```
When we hit the webpage with the /info.php in the end we should be able to see the PHP 7 information page, which lists the running version and configuration.
After we finish with this test we can delete the info.php file.
We keep an eye for metrics related to latency and performance and observe if there is any degradation.
If everything works as expected than we proceed by making the PHP upgrade on the other servers too.


##### 2. CR Process

Since the upgrade is being performed on production systems we need to inform all involved stakeholder about the upgrade and cross check any additional business impact not considered.
The Upgrade is recommended to be performed in a maintenance window when traffic is very low and therefore in case something goes wrong there is enough time to rollback with none to minimal impact.
There should be a clear plan on the upgrade process and rollback plan. All efforts for upgrade, post-upgrades processes should be planned carefully in order to make sure there are enough resources to monitor the systems after the upgrade


Author: Arlind

