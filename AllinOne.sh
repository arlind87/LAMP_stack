#!/bin/bash
#Allinonesetup

vagrant up
sleep 30
vagrant ssh -c "/vagrant/server_provision.sh; /bin/bash"