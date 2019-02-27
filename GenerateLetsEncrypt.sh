#!/bin/bash
#Generates Let's Encrypt requests for selected domains using Webmin LLet's Encrypt subsystem 
#Addressing issue in Webmin/Virtualmin with Let's Encrypt auto renew function (just workaround)
#v0.1 - initial quick version

#Get fresh list of domains with SSL enabled (master domains, subservers and aliases)
Domains=`virtualmin list-domains --with-feature ssl |awk '{print $1}' |tail -n+3`

#Save the output
echo "$Domains" > Domains.list

#Request certificate for each domain

while IFS= read -r var
do
echo kricim: "$var"
done < "Domains.list"

#Generate certificate requests
#virtualmin generate-letsencrypt-cert --domain $Domain
