#!/bin/sh -x

printenv

export HTTP_IP="127.0.0.1"
export HTTP_PORT="8080"
if [ "x${BACKEND_PORT}" != "x" ]; then
   HTTP_IP=`echo "${BACKEND_PORT}" | sed 's%/%%g' | awk -F: '{ print $2 }'`
   HTTP_PORT=`echo "${BACKEND_PORT}" | sed 's%/%%g' | awk -F: '{ print $3 }'`
fi

KEYDIR=/etc/ssl
mkdir -p $KEYDIR
export KEYDIR

if [ ! -f "$KEYDIR/private/${PUBLIC_HOSTNAME}.key" -o ! -f "$KEYDIR/certs/${PUBLIC_HOSTNAME}.crt" ]; then
   make-ssl-cert generate-default-snakeoil --force-overwrite
   cp /etc/ssl/private/ssl-cert-snakeoil.key "$KEYDIR/private/${PUBLIC_HOSTNAME}.key"
   cp /etc/ssl/certs/ssl-cert-snakeoil.pem "$KEYDIR/certs/${PUBLIC_HOSTNAME}.crt"
fi

CHAINSPEC=""
export CHAINSPEC
if [ -f "$KEYDIR/certs/${PUBLIC_HOSTNAME}.chain" ]; then
   CHAINSPEC="SSLCertificateChainFile $KEYDIR/certs/${PUBLIC_HOSTNAME}.chain"
elif [ -f "$KEYDIR/certs/${PUBLIC_HOSTNAME}-chain.crt" ]; then
   CHAINSPEC="SSLCertificateChainFile $KEYDIR/certs/${PUBLIC_HOSTNAME}-chain.crt"
elif [ -f "$KEYDIR/certs/${PUBLIC_HOSTNAME}.chain.crt" ]; then
   CHAINSPEC="SSLCertificateChainFile $KEYDIR/certs/${PUBLIC_HOSTNAME}.chain.crt"
elif [ -f "$KEYDIR/certs/chain.crt" ]; then
   CHAINSPEC="SSLCertificateChainFile $KEYDIR/certs/chain.crt"
elif [ -f "$KEYDIR/certs/chain.pem" ]; then
   CHAINSPEC="SSLCertificateChainFile $KEYDIR/certs/chain.pem"
fi


cat>/etc/apache2/sites-available/default.conf<<EOF
<VirtualHost *:80>
       ServerAdmin noc@sunet.se
       ServerName ${PUBLIC_HOSTNAME}
       DocumentRoot /var/www/

       RewriteEngine On
       RewriteCond %{HTTPS} off
       RewriteRule !_lvs.txt$ https://%{HTTP_HOST}%{REQUEST_URI}
</VirtualHost>
EOF

cat>/etc/apache2/sites-available/default-ssl.conf<<EOF
ServerName ${PUBLIC_HOSTNAME}
<VirtualHost *:443>
        ServerName ${PUBLIC_HOSTNAME}
        SSLProtocol All -SSLv2 -SSLv3
        SSLCompression Off
        SSLCipherSuite "EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+AESGCM EECDH EDH+AESGCM EDH+aRSA HIGH !MEDIUM !LOW !aNULL !eNULL !LOW !RC4 !MD5 !EXP !PSK !SRP !DSS"
        SSLEngine On
        SSLCertificateFile $KEYDIR/certs/${PUBLIC_HOSTNAME}.crt
        ${CHAINSPEC}
        SSLCertificateKeyFile $KEYDIR/private/${PUBLIC_HOSTNAME}.key
        DocumentRoot /var/www/
        
        ServerAdmin noc@nordu.net

        Header set Host "${PUBLIC_HOSTNAME}"
        RequestHeader set X-Forwarded-Proto "https"

        ProxyRequests On
 
        AddDefaultCharset utf-8

        ErrorLog /var/log/apache2/error.log
        LogLevel warn
        CustomLog /var/log/apache2/access.log combined
        ServerSignature off

        AddDefaultCharset utf-8

        ProxyPreserveHost  On
  	ProxyRequests      Off
  	ProxyPass          /  http://${HTTP_IP}:${HTTP_PORT}/
  	ProxyPassReverse   /  http://${HTTP_IP}:${HTTP_PORT}/

        <Location />
           Order deny,allow
           Allow from all

           <RequireAll>
              <RequireAny>
                 Require method GET
                 <RequireAll>
                    SSLVerifyClient require
                    SSLVerifyDepth 1
                    SSLCACertificateFile /etc/ssl/certs/${PUBLIC_HOSTNAME}-client-ca.crt
                 </RequireAll>
              </RequireAny>
           </RequireAll>

        </Location>

</VirtualHost>
EOF

cat /etc/apache2/sites-available/default.conf
cat /etc/apache2/sites-available/default-ssl.conf

a2ensite default
a2ensite default-ssl

rm -f /var/run/apache2/apache2.pid

exec apache2 -DFOREGROUND
