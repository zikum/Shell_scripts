# Virtualmin script for creating new SMTP user

if [ "$VIRTUALSERVER_ACTION" = "CREATE_DOMAIN" ]; then

#import DB
echo importuji DB
mysql -u $db_user -p$db_pass -h localhost $VIRTUALSERVER_DB < $db_bin

#editace conf. souboru
echo nastavuji conf. soubor
cd $VIRTUALSERVER_HOME/public_html/
sed -i 's/install/'$VIRTUALSERVER_DB'/g' configuration.php

#vytvoreni mailboxu pro procesing nedorucitelnych zprav a vygenerovani hesla
#Password generator:
cd /var/bin/
/bin/bash randpass &> tmp_pass
pass=`cat tmp_pass`
virtualmin create-user --domain profimailing.cz --user $VIRTUALSERVER_DB --pass $pass --quota 512000 --real "$VIRTUALSERVER_DB"

exit
