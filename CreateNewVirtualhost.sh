#!/bin/bash
# ZIKUM virtualmin provisioning script, verze 1.18.
#
# changelog:
# -------------------------------------------------------------------------------------------------------------------
# verze 1.1: Backupy maji vlastnika backup. Velikost zaloh se jiz nezapocitava do quoty virtualu.
# verze 1.2: Osetreno rozliseni TOP virtual server/child server na urovni vytvareni zaloh a zapisu do CRONu
# verze 1.3: Osetreno mazani child virtualu - pri odstraneni child virtualu zustavaji backupy, skripty a cron ulohy
# verze 1.4: Mazani virtualu - pri odstraneni TOP virtualu smaze cely home. Nove fixnuto odebrani vsech souvisejicich cron uloh
# verze 1.5: IMPLEMENTACE GEEK HOSTING plus backupy - funkcni!
# verze 1.6: Pridano: nahodne generovani casu zapisu do cronu pro backupy (reseni potizi se spoustenim vice backupu naraz)
# verze 1.7: Odebrano: nadbytecny full backup (k hovnu)
# verze 1.8: Pridano: Pri zastaveni virtualu se zakazi (zakomentuji) souvisejici cron ulohy (backup, awstats). Po spusteni se povoli.
# verze 1.9: Zakazano: statistiky AWSTATS se zapisuji do CRON zakomentovane. Povoleni jen on demand (performance issue)
# verze 1.10: ZRUSENO!!!!!  HACK - Po upgrade na Debian 7.5 pridano dodatecne odstraneni directivy "php_admin_value engine Off" z apache website (nezama chyba Virtualminu)
# verze 1.11: Mazani virtualu - Pridana FCE pro odliti posledni dostupne zalohy virtualu na bezpecne misto. Resi problem s "omylem" smazanymi virtualy
# verze 1.12: Uprava backupu: Kvuli problemu pri vytvareni zalohy pod user accountem (nekdy dochazelo k vycerpani quoty a zaloha diky tomu selhala) je nyni zaloha vytvarena pod userem root.
# verze 1.13: Zmena prav na backupy, automaticky mount backup slozky do home slozky usera (virtualmin-backup) - Zajistuje moznost stahnout backup primo z FTP
# verze 1.14: 17.11.2015 pridana podpora pro LetsEncrypt - automaticke generovani certifikatu, automaticke obnovovani. Revokace zatim manualne. Pridano pro Hosting Web a Web Plus.
# verze 1.15: Rewrite of <virtualHost> with actual IPv4 address assigned to server (because of new FW settings)
# verze 1.16: Prepracovan sync pro Geek hosting. Finalne funkcni obousmerny sync JAIL home <> system home
# Verze 1.17 (11.9.2016): Opravena chyba v zapisu do backup scriptu. Ted se jeste pred tim zjistuje, zda jde o TOP level server, nebo child server.
# Version 1.18 (3.3.2019): Auto detection of actual IPv4 address Added.  

# Get current public IP address
PublicIPv4=`ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`

# id hosting planu
hosting_email_plan_id="129305774627223"
hosting_web_plan_id="12918400401873"
hosting_web_plus_plan_id="12933799876863"
#hosting_ftp_plus_plan_id="12942445852822"
#hosting_eshop_plan_id="130394243423777"
#geek_hosting_plan_id="133909745812676"

# Geek hosting promenne
#sshd_config="/etc/ssh/sshd_config"
#jail="/var/home/JAIL/var/home"
#jail_etc="/var/home/JAIL/etc"
#geek_data="/var/bin/geek_data"
#lsyncd_conf="/etc/lsyncd/lsyncd.conf.lua"

## promenne pro backup ##
crontab="/var/spool/cron/crontabs/root"
BackupMount="/var/bin/MountBackupsToFtp.sh"

#vygenerovani nahodneho casu pro crontab
shuf -n 1 /var/bin/cron_times.txt > /var/bin/crontab_rand_time
crontab_rand_time=`cat /var/bin/crontab_rand_time`
backup_path="/var/backups/virtuals"
deleted_virtuals_backup="/var/backups/virtuals/_deleted_virtuals"
domain_backup_script="/var/bin/backup_scripts"
backup_script="/usr/share/webmin/virtual-server/backup-domain.pl"
#backup_script_geek_daily="/var/bin/geek_backup_daily.sh"
#backup_script_geek_full="/var/bin/geek_backup_weekly.sh"

# promenne pro virtualy
dom_name_path="/etc/webmin/virtual-server"
dom_id_path="/etc/webmin/virtual-server/domains"
dom_id=`cat $dom_name_path/$VIRTUALSERVER_USER.acl |egrep -i domains |awk 'match($0,"="){print substr($0,RSTART+1,20)}'`
dom_plan_id=`cat $dom_id_path/$dom_id |egrep -i plan |awk 'match($0,"="){print substr($0,RSTART+1,20)}'`
#eshop_bin="/var/bin/hosting_eshop_data"
enabled_sites="/etc/apache2/sites-enabled"
#letsencrypt_sign="/var/bin/DomainsToSign"

if [ "$VIRTUALSERVER_ACTION" = "CREATE_DOMAIN" ]; then

    if [ -z "$VIRTUALSERVER_PARENT" ]; then

    echo "TOP level server - nastavuji kompletni backup"


    #ln -s /var/home/zikum.cz/public_html/webmail $VIRTUALSERVER_HOME/public_html/webmail
    #ln -s /usr/share/phpmyadmin $VIRTUALSERVER_HOME/public_html/dbadmin
    #ln -s /var/home/zikum.cz/public_html/webftp $VIRTUALSERVER_HOME/public_html/webftp
    #ln -s /var/www/postgresadmin $VIRTUALSERVER_HOME/public_html/postgresadmin	

    cp -r /var/bin/data/* $VIRTUALSERVER_HOME/public_html/
    #cp -r $geek_data/.bashrc $VIRTUALSERVER_HOME
    cd $VIRTUALSERVER_HOME
    chown -R $VIRTUALSERVER_USER:$VIRTUALSERVER_GROUP public_html/

    # Nastaveni zalohovani
    cd $backup_path
    mkdir $VIRTUALSERVER_USER
    cd $backup_path/$VIRTUALSERVER_USER
    mkdir denni-plna
    chmod -R 755 $backup_path/$VIRTUALSERVER_USER 
    chown -R backup:backup $backup_path/$VIRTUALSERVER_USER

    cd $VIRTUALSERVER_HOME
    mkdir virtualmin-backup
    ln -s $backup_path/$VIRTUALSERVER_USER/denni-plna $VIRTUALSERVER_HOME/virtualmin-backup/denni-plna
    chown -R $VIRTUALSERVER_USER:$VIRTUALSERVER_GROUP virtualmin-backup

	# Zapis noveho mountu do MountBackupsToFtp.sh
	echo "mount --bind $backup_path/$VIRTUALSERVER_USER/ /home/$VIRTUALSERVER_USER/virtualmin-backup/" >> $BackupMount     	
	
    	# Provedeni mountu po dokonceni konfigurace zalohovani
    	mount --bind $backup_path/$VIRTUALSERVER_USER/ /home/$VIRTUALSERVER_USER/virtualmin-backup/

    # kazdodenni zaloha (rotace po 7 dnech)
    mkdir $domain_backup_script/$VIRTUALSERVER_USER
    touch $domain_backup_script/$VIRTUALSERVER_USER/$VIRTUALSERVER_USER.backup-inc
    chmod +x $domain_backup_script/$VIRTUALSERVER_USER/$VIRTUALSERVER_USER.backup-inc

    echo '#!/bin/bash' >> $domain_backup_script/$VIRTUALSERVER_USER/$VIRTUALSERVER_USER.backup-inc
    echo "cd $backup_path/$VIRTUALSERVER_USER/denni-plna/" >> $domain_backup_script/$VIRTUALSERVER_USER/$VIRTUALSERVER_USER.backup-inc
    echo 'mkdir $(date '+%d-%m-%Y')' >> $domain_backup_script/$VIRTUALSERVER_USER/$VIRTUALSERVER_USER.backup-inc	
    echo "$backup_script --dest $backup_path/$VIRTUALSERVER_USER/denni-plna/%d-%m-%Y --user $VIRTUALSERVER_USER --all-features --separate --newformat --strftime --purge 7" >> $domain_backup_script/$VIRTUALSERVER_USER/$VIRTUALSERVER_USER.backup-inc
    echo "chown -R backup:backup $backup_path/$VIRTUALSERVER_USER" >> $domain_backup_script/$VIRTUALSERVER_USER/$VIRTUALSERVER_USER.backup-inc
    echo "chmod -R 755 $backup_path/$VIRTUALSERVER_USER" >> $domain_backup_script/$VIRTUALSERVER_USER/$VIRTUALSERVER_USER.backup-inc	


    # vkladani backup planu do CRONu
    # 11.6.208 Zjisten PROBLEM!! Zakomentovano. Backupy se nabalovaly... 	
    #echo "TOP level server - nastavuji backup (zapis do CRON)"
    #echo "$crontab_rand_time $domain_backup_script/$VIRTUALSERVER_USER/$VIRTUALSERVER_USER.backup-inc" >> $crontab
    
    #else

    #echo "child virtual - preskakuji nastaveni backupu (jiz nastaveno)"     
    fi

#/etc/init.d/apache2 reload
#/etc/init.d/proftpd restart

        #--------------------------------------------------------------------------#
        #porovnani vytvareneho hostingu s id hosting planem a provedeni danych akci#
        #--------------------------------------------------------------------------#

        #hosting email
        #if [ $hosting_email_plan_id = $dom_plan_id ]; then
        #sleep 5
	#echo -e "\e[0;32mAplikuje se nastaveni pro Hosting Email\e[0m"
        #/usr/share/webmin/virtual-server/enable-feature.pl --domain $VIRTUALSERVER_USER --mail --spam --virus --virtualmin-mailman
        #echo -e "\n"
        #echo -e "\e[0;32mDokonceno!\e[0m"
	#fi

	###hosting web###
        if [ $hosting_web_plan_id = $dom_plan_id ]; then
        #sleep 3
        #echo -e "\e[0;32mAplikuje se nastaveni pro Hosting Web\e[0m"
        #/usr/share/webmin/virtual-server/enable-feature.pl --domain $VIRTUALSERVER_USER --unix --dir --mail --web --logrotate --spam --virus --virtualmin-awstats --virtualmin-mailman

        mv $VIRTUALSERVER_HOME/public_html/awstats-icon $VIRTUALSERVER_HOME/public_html/.awstats-icon
        mv $VIRTUALSERVER_HOME/public_html/awstatsicons $VIRTUALSERVER_HOME/public_html/.awstatsicons
        mv $VIRTUALSERVER_HOME/public_html/icon $VIRTUALSERVER_HOME/public_html/.icon
	
	# Workaround - prepis <VirtualHost *:80> NA <VirtualHost $PublicIPv4:80>
	cd /etc/apache2/sites-available/
	sed -i 's|*:80|$PublicIPv4:80|g' $VIRTUALSERVER_DOM.conf

    # Configure MySQL remote access
    virtualmin modify-database-hosts --domain $VIRTUALSERVER_DOM --type mysql --add-host $PublicIPv4


#START - Vygenerovani skriptu letsEncrypt pro pozdejsi podepsani domeny
#touch $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#chmod 755 $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  
#  echo "#!/bin/bash" > $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "#ZIKUM LetsEncrypt provisioning script" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "#Odstraneni puvodnich self-signed certu z virtualu" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "cd $VIRTUALSERVER_HOME" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "rm ssl.cert ssl.key" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "#Vystaveni certifikatu" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "echo Vystavuji LetsEncrypt certifikat..." >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "cd /var/bin/letsencrypt/" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign 
#  echo "su letsencrypt -c './letsencrypt-auto --rsa-key-size 4096 certonly -a webroot --webroot-path /var/home/$VIRTUALSERVER_DOM/public_html --email $VIRTUALSERVER_EMAILTO --text --agree-tos -d $VIRTUALSERVER_DOM -d www.$VIRTUALSERVER_DOM --server https://acme-v01.api.letsencrypt.org/directory'" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "# vytvoreni symlinku certifikatu a priv. klice:" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "ln -s /etc/letsencrypt/live/$VIRTUALSERVER_DOM/cert.pem $VIRTUALSERVER_HOME/ssl.cert" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "ln -s /etc/letsencrypt/live/$VIRTUALSERVER_DOM/privkey.pem $VIRTUALSERVER_HOME/ssl.key" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign 
#  echo "#Webserver reload" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign 
#  echo "/etc/init.d/apache2 reload" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#END - Vygenerovani skriptu letsEncrypt pro pozdejsi podepsani domeny   

#Zapis do CRON - LetsEncrypt certificate auto renew
#echo "0 0 */80 * * cd /var/bin/letsencrypt && su letsencrypt -c './letsencrypt-auto --renew-by-default --rsa-key-size 4096 certonly -a webroot --webroot-path /var/home/$VIRTUALSERVER_DOM/public_html --email $VIRTUALSERVER_EMAILTO --text --agree-tos -d $VIRTUALSERVER_DOM -d www.$VIRTUALSERVER_DOM --server https://acme-v01.api.letsencrypt.org/directory'" >> $crontab
      	
	echo -e "\n"
        echo -e "\e[0;32mDokonceno!\e[0m"
	fi

        ###hosting web plus###
        if [ $hosting_web_plus_plan_id = $dom_plan_id ]; then
        #sleep 5
        #echo -e "\e[0;32mAplikuje se nastaveni pro Hosting Web Plus\e[0m"
        #/usr/share/webmin/virtual-server/enable-feature.pl --domain $VIRTUALSERVER_USER --unix --dir --mail --web --logrotate --spam --virus --virtualmin-awstats --virtualmin-mailman --mysql

        mv $VIRTUALSERVER_HOME/public_html/awstats-icon $VIRTUALSERVER_HOME/public_html/.awstats-icon
        mv $VIRTUALSERVER_HOME/public_html/awstatsicons $VIRTUALSERVER_HOME/public_html/.awstatsicons
        mv $VIRTUALSERVER_HOME/public_html/icon $VIRTUALSERVER_HOME/public_html/.icon
	
	# Workaround - prepis <VirtualHost *:80> NA <VirtualHost $PublicIPv4:80>
        cd /etc/apache2/sites-available/
        sed -i 's|*:80|$PublicIPv4:80|g' $VIRTUALSERVER_DOM.conf

    # Configure MySQL remote access
    virtualmin modify-database-hosts --domain $VIRTUALSERVER_DOM --type mysql --add-host $PublicIPv4    

#START - Vygenerovani skriptu letsEncrypt pro pozdejsi podepsani domeny
#touch $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#chmod 755 $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  
#  echo "#!/bin/bash" > $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "#ZIKUM LetsEncrypt provisioning script" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "#Odstraneni puvodnich self-signed certu z virtualu" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "cd $VIRTUALSERVER_HOME" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "rm ssl.cert ssl.key" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "#Vystaveni certifikatu" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "echo Vystavuji LetsEncrypt certifikat..." >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "cd /var/bin/letsencrypt/" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign 
#  echo "su letsencrypt -c './letsencrypt-auto --rsa-key-size 4096 certonly -a webroot --webroot-path /var/home/$VIRTUALSERVER_DOM/public_html --email $VIRTUALSERVER_EMAILTO --text --agree-tos -d $VIRTUALSERVER_DOM -d www.$VIRTUALSERVER_DOM --server https://acme-v01.api.letsencrypt.org/directory'" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "# vytvoreni symlinku certifikatu a priv. klice:" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "ln -s /etc/letsencrypt/live/$VIRTUALSERVER_DOM/cert.pem $VIRTUALSERVER_HOME/ssl.cert" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "ln -s /etc/letsencrypt/live/$VIRTUALSERVER_DOM/privkey.pem $VIRTUALSERVER_HOME/ssl.key" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign 
#  echo "#Webserver reload" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign 
#  echo "/etc/init.d/apache2 reload" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#END - Vygenerovani skriptu letsEncrypt pro pozdejsi podepsani domeny

#Zapis do CRON - LetsEncrypt certificate auto renew
#echo "0 0 */80 * * cd /var/bin/letsencrypt && su letsencrypt -c './letsencrypt-auto --renew-by-default --rsa-key-size 4096 certonly -a webroot --webroot-path /var/home/$VIRTUALSERVER_DOM/public_html --email $VIRTUALSERVER_EMAILTO --text --agree-tos -d $VIRTUALSERVER_DOM -d www.$VIRTUALSERVER_DOM --server https://acme-v01.api.letsencrypt.org/directory'" >> $crontab
	
	echo -e "\n"
        echo -e "\e[0;32mDokonceno!\e[0m"
        fi

        #hosting FTP plus
        #if [ $hosting_ftp_plus_plan_id = $dom_plan_id ]; then
        #sleep 5
        #echo -e "\e[0;32mAplikuje se nastaveni pro Hosting FTP Plus\e[0m"
        #/usr/share/webmin/virtual-server/enable-feature.pl --domain $VIRTUALSERVER_USER --unix --dir
        #echo -e "\n"
        #echo -e "\e[0;32mDokonceno!\e[0m"
        #fi
        
	###Geek hosting###
	#if [ $geek_hosting_plan_id = $dom_plan_id ]; then
        #echo -e "\e[0;32mAplikuje se nastaveni pro Geek hosting\e[0m"
        #/usr/share/webmin/virtual-server/enable-feature.pl --domain $VIRTUALSERVER_USER --unix --dir --dns --mail --web --webalizer --ssl --logrotate --spam --virus --virtualmin-awstats --virtualmin-mailman --mysql --status --webmin --virtualmin-dav --virtualmin-svn 

        #mv $VIRTUALSERVER_HOME/public_html/awstats-icon $VIRTUALSERVER_HOME/public_html/.awstats-icon
        #mv $VIRTUALSERVER_HOME/public_html/awstatsicons $VIRTUALSERVER_HOME/public_html/.awstatsicons
        #mv $VIRTUALSERVER_HOME/public_html/icon $VIRTUALSERVER_HOME/public_html/.icon
        
	# Workaround - prepis <VirtualHost *:80> NA <VirtualHost 95.168.204.225:80>
        #cd /etc/apache2/sites-available/
        #sed -i 's|*:80|95.168.204.225:80|g' $VIRTUALSERVER_DOM.conf

	# Nastaveni obousmerneho syncu se slozkami v JAIL a mimo JAIL (lsyncd)
	#echo "--$VIRTUALSERVER_DOM sync config_A" >> $lsyncd_conf
        #echo "sync {" >> $lsyncd_conf
        #echo "default.rsync," >> $lsyncd_conf
        #echo target='"'"$jail/$VIRTUALSERVER_DOM"'",' >> $lsyncd_conf
        #echo source='"'"/var/home/$VIRTUALSERVER_DOM/"'",' >> $lsyncd_conf
        #echo "rsync = {" >> $lsyncd_conf
        #echo _extra = '{ "'"--links"'", "'"--perms"'", "'"--times"'", "'"--group"'", "'"--owner"'", "'"--devices"'" }' >> $lsyncd_conf
        #echo "          }" >> $lsyncd_conf
        #echo "}" >> $lsyncd_conf

	#echo "--$VIRTUALSERVER_DOM sync config_B" >> $lsyncd_conf
        #echo "sync {" >> $lsyncd_conf
        #echo "default.rsync," >> $lsyncd_conf
        #echo source='"'"$jail/$VIRTUALSERVER_DOM"'",' >> $lsyncd_conf
        #echo target='"'"/var/home/$VIRTUALSERVER_DOM/"'",' >> $lsyncd_conf
        #echo "rsync = {" >> $lsyncd_conf
        #echo _extra = '{ "'"--links"'", "'"--perms"'", "'"--times"'", "'"--group"'", "'"--owner"'", "'"--devices"'" }' >> $lsyncd_conf
        #echo "          }" >> $lsyncd_conf
        #echo "}" >> $lsyncd_conf

		
	#presunuti uzivatele do JAILu a povoleni SSH prihlaseni
    	#if [ -z "$VIRTUALSERVER_PARENT" ]; then
	#echo "Parent server - povoluji remote SSH login"

       	#sed -i '/AllowUsers/s|$| '$VIRTUALSERVER_USER'|' $sshd_config
        #/etc/init.d/ssh reload

	#else
	
	#echo "child virtual - preskakuji nastaveni povoleni SSH"
   	#fi



#START - Vygenerovani skriptu letsEncrypt pro pozdejsi podepsani domeny
#touch $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#chmod 755 $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  
#  echo "#!/bin/bash" > $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "#ZIKUM LetsEncrypt provisioning script" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "#Odstraneni puvodnich self-signed certu z virtualu" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "cd $VIRTUALSERVER_HOME" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "rm ssl.cert ssl.key" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "#Vystaveni certifikatu" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "echo Vystavuji LetsEncrypt certifikat..." >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "cd /var/bin/letsencrypt/" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign 
#  echo "su letsencrypt -c './letsencrypt-auto --rsa-key-size 4096 certonly -a webroot --webroot-path /var/home/$VIRTUALSERVER_DOM/public_html --email $VIRTUALSERVER_EMAILTO --text --agree-tos -d $VIRTUALSERVER_DOM -d www.$VIRTUALSERVER_DOM --server https://acme-v01.api.letsencrypt.org/directory'" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "# vytvoreni symlinku certifikatu a priv. klice:" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "ln -s /etc/letsencrypt/live/$VIRTUALSERVER_DOM/cert.pem $VIRTUALSERVER_HOME/ssl.cert" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#  echo "ln -s /etc/letsencrypt/live/$VIRTUALSERVER_DOM/privkey.pem $VIRTUALSERVER_HOME/ssl.key" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign 
#  echo "#Webserver reload" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign 
#  echo "/etc/init.d/apache2 reload" >> $letsencrypt_sign/$VIRTUALSERVER_DOM.cert.sign
#END - Vygenerovani skriptu letsEncrypt pro pozdejsi podepsani domeny

#Zapis do CRON - LetsEncrypt certificate auto renew
#echo "0 0 */80 * * cd /var/bin/letsencrypt && su letsencrypt -c './letsencrypt-auto --renew-by-default --rsa-key-size 4096 certonly -a webroot --webroot-path /var/home/$VIRTUALSERVER_DOM/public_html --email $VIRTUALSERVER_EMAILTO --text --agree-tos -d $VIRTUALSERVER_DOM -d www.$VIRTUALSERVER_DOM --server https://acme-v01.api.letsencrypt.org/directory'" >> $crontab

        #echo -e "\n"
        #echo -e "\e[0;32mDokonceno!\e[0m"
        
	# Jail usera
	#sleep 20
	#jk_jailuser -m -s /bin/bash -j /var/home/JAIL $VIRTUALSERVER_USER
        #cp -r $VIRTUALSERVER_HOME $jail
        #chown -R $VIRTUALSERVER_USER:$VIRTUALSERVER_USER $jail/$VIRTUALSERVER_DOM
        #find $jail/$VIRTUALSERVER_DOM -type d -exec chmod 750 {} \;
        #find $jail/$VIRTUALSERVER_DOM -type f -exec chmod 644 {} \;

	#/etc/init.d/lsyncd force-reload

	#fi

        ##hosting Eshop##
	#if [ $hosting_eshop_plan_id = $dom_plan_id ]; then
        #sleep 5
        #echo -e "\e[0;32mAplikuje se nastaveni pro Hosting Eshop\e[0m"
        #/usr/share/webmin/virtual-server/enable-feature.pl --domain $VIRTUALSERVER_USER --unix --dir --mail --web --logrotate --spam --virus --virtualmin-awstats --virtualmin-mailman --mysql
		
	#rm $VIRTUALSERVER_HOME/public_html/index.php
	#cd $eshop_bin/data/
        #cp -r ./ $VIRTUALSERVER_HOME/public_html
	#rm $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
	#touch $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
	
##Vlozeni konfigurace z virtualmin promennych##
		#echo "<?xml version="1.0"?>" > $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "<!--" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "/**" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "* Online Shopper auto config" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "* Do not overwrite!" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo " */" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "-->" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "<config>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "   <global>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "       <install>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "           <date><![CDATA[Thu, 24 Mar 2011 14:25:37 +0000]]></date>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "       </install>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "       <crypt>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "           <key><![CDATA[dda1dc19c02075c61d88c66e37e837ec]]></key>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "       </crypt>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "       <disable_local_modules>false</disable_local_modules>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "       <resources>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "           <db>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "               <table_prefix><![CDATA[]]></table_prefix>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "           </db>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "           <default_setup>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "               <connection>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "                   <host><![CDATA[localhost]]></host>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "                   <username><![CDATA[$VIRTUALSERVER_DOM]]></username>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "                   <password><![CDATA[$VIRTUALSERVER_PASS]]></password>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "                   <dbname><![CDATA[$VIRTUALSERVER_DB]]></dbname>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "                   <active>1</active>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "               </connection>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "           </default_setup>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "       </resources>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "       <session_save><![CDATA[files]]></session_save>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "   </global>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "   <admin>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "       <routers>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "           <adminhtml>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "               <args>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "                   <frontName><![CDATA[admin]]></frontName>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "               </args>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "           </adminhtml>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "       </routers>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "   </admin>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
		#echo "</config>" >> $VIRTUALSERVER_HOME/public_html/app/etc/local.xml
        
        #chown -R $VIRTUALSERVER_USER:$VIRTUALSERVER_GROUP $VIRTUALSERVER_HOME/public_html
	#mysql -u $VIRTUALSERVER_DOM -p$VIRTUALSERVER_PASS -h localhost $VIRTUALSERVER_DB < $eshop_bin/sql/eshop.sql
	#cd $VIRTUALSERVER_HOME/public_html
        #php -f install.php -- --license_agreement_accepted yes \
	#		   --locale cs_CZ --timezone "Europe/Budapest" --default_currency CZK \
	#		   --db_host localhost --db_name $VIRTUALSERVER_DB --db_user $VIRTUALSERVER_DOM --db_pass $VIRTUALSERVER_PASS \
	#		   --url "http://$VIRTUALSERVER_DOM/" --use_rewrites yes \
	#		   --use_secure no --secure_base_url no --use_secure_admin no \
	#		   --skip_url_validation yes \
	#		   --admin_lastname $VIRTUALSERVER_DOM --admin_firstname Admin --admin_email "$VIRTUALSERVER_EMAILTO" \
	#		   --admin_username admin --admin_password $VIRTUALSERVER_PASS \
	#		   --encryption_key


        #mv $VIRTUALSERVER_HOME/public_html/awstats-icon $VIRTUALSERVER_HOME/public_html/.awstats-icon
        #mv $VIRTUALSERVER_HOME/public_html/awstatsicons $VIRTUALSERVER_HOME/public_html/.awstatsicons
        #mv $VIRTUALSERVER_HOME/public_html/icon $VIRTUALSERVER_HOME/public_html/.icon
        # Odstraneni direktivy - php_admin_value engine Off
        ##sed -i /"php_admin_value engine Off"/d $enabled_sites/$VIRTUALSERVER_DOM.conf
	#echo -e "\n"
        #echo -e "\e[0;32mDokonceno!\e[0m"
        #fi

# Reload apache - pro aplikaci zmen v configu
echo "RELOADING APACHCE2 SERVER CONFIG..."
/etc/init.d/apache2 reload


fi

##Akce pri zakazani/povoleni virtualu - zakomentovani backupu a awstats##

#Zakazani
if [ "$VIRTUALSERVER_ACTION" = "DISABLE_DOMAIN" ]; then

sed -i "/$VIRTUALSERVER_DOM/ s/^/# /" $crontab
fi

#Povoleni
if [ "$VIRTUALSERVER_ACTION" = "ENABLE_DOMAIN" ]; then

sed -i "/$VIRTUALSERVER_DOM/ s/# *//" $crontab
fi


#Cisteni pri SMAZANI virtualu
if [ "$VIRTUALSERVER_ACTION" = "DELETE_DOMAIN" ]; then

                        if [ -z "$VIRTUALSERVER_PARENT" ]; then
                        echo "Odlevani posledni zalohy virtualu..."                        
                        FIND_NEWEST_BACKUP=$(ls -t $backup_path/$VIRTUALSERVER_USER/denni-plna | head -1)
                        cp -r $backup_path/$VIRTUALSERVER_USER/denni-plna/$FIND_NEWEST_BACKUP $deleted_virtuals_backup
                        cd $deleted_virtuals_backup
                        mv $FIND_NEWEST_BACKUP $VIRTUALSERVER_DOM
                        echo "Zaloha dokoncena..."
                        
                        echo "Mazu veskery obsah vcetne zaloh a backup skriptu..."
                        rm -r $backup_path/$VIRTUALSERVER_USER
                        rm -r $domain_backup_script/$VIRTUALSERVER_USER
                        rm -r $VIRTUALSERVER_HOME
			# Smazani zapisu z BackupMount
                        sed -i /$VIRTUALSERVER_DOM/d $BackupMount 
                        
			#specialne pro geek hosting#
			rm -r $jail/$VIRTUALSERVER_DOM
			sed -i /$VIRTUALSERVER_DOM/d $jail_etc/passwd
			sed -i /$VIRTUALSERVER_DOM/d $jail_etc/group
			sed -i /^AllowUsers/s/\$VIRTUALSERVER_DOM$// $sshd_config
			#END - specialne pro geek hosting#
			
			sed -i /$VIRTUALSERVER_DOM/d $crontab
			
                        else

                        echo "child virtual - preskakuji mazani backupu, backup scriptu a home adresare"
                        fi

fi
