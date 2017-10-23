#!/bin/sh -x

printenv

export V2_IP="127.0.0.1"
export V2_PORT="8081"

if [ "x${API_V2_PORT}" != "x" ]; then
   V2_IP=`echo "${API_V2_PORT}" | sed 's%/%%g' | awk -F: '{ print $2 }'`
   V2_PORT=`echo "${API_V2_PORT}" | sed 's%/%%g' | awk -F: '{ print $3 }'`
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
        SSLCACertificateFile /etc/ssl/certs/${PUBLIC_HOSTNAME}-client-ca.crt
        SSLVerifyClient optional
        SSLVerifyDepth 1
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
        ProxyPass          /v2  http://${V2_IP}:${V2_PORT}/v2
        ProxyPassReverse   /v2  http://${V2_IP}:${V2_PORT}/v2

        <Location />
           Order deny,allow
           Allow from all
           <RequireAll>
              Require ssl
              <RequireAny>
                 Require method GET
                 Require ssl-verify-client
              </RequireAny>
           </RequireAll>
        </Location>

</VirtualHost>
EOF

cat /etc/apache2/sites-available/default-ssl.conf

a2ensite default
a2ensite default-ssl
a2dismod status

rm -f /var/run/apache2/apache2.pid

mkdir -p /var/lock/apache2 /var/run/apache2
env APACHE_LOCK_DIR=/var/lock/apache2 APACHE_RUN_DIR=/var/run/apache2 APACHE_PID_FILE=/var/run/apache2/apache2.pid APACHE_RUN_USER=www-data APACHE_RUN_GROUP=www-data APACHE_LOG_DIR=/var/log/apache2 apache2 -DFOREGROUND
