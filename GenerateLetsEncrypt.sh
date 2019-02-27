#!/bin/bash
#Generates Let's Encrypt requests for selected domains using Webmin Let's Encrypt subsystem 
#Addressing issue in Webmin/Virtualmin with Let's Encrypt auto renew function (just workaround)
#Intended to be run via crontab within reasonable time period (once per two months)
#v0.1 - initial quick version without logging

#Get fresh list of domains with SSL enabled (master domains, subservers and aliases)
Domains=`virtualmin list-domains --with-feature ssl |awk '{print $1}' |tail -n+3`

#Save the output
echo "$Domains" > Domains.list

#Request certificate for each domain
while IFS= read -r domain
do
virtualmin generate-letsencrypt-cert --domain "$domain"
done < "Domains.list"

exit
