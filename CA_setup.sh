#!/bin/bash
# Collecting basic information
echo 'Enter details for creating Certificate Authority'
read -p 'Enter CA FQDN: ' SERVER
read -p 'Enter Company Name: ' CORPORATION
read -p 'Enter OU Name: ' GROUP
read -p 'Enter City Name: ' CITY
read -p 'Enter State Name: ' STATE
read -p 'Enter Country Code: ' COUNTRY
cert_path=$(pwd)
cd ${cert_path}
mkdir signed_cert
cd -

#generating random password
CERT_AUTH_PASS=`openssl rand -base64 32`
echo $CERT_AUTH_PASS > cert_auth_password
CERT_AUTH_PASS=`cat cert_auth_password`

# create the certificate authority
openssl \
  req \
  -subj "/CN=$SERVER.ca/OU=$GROUP/O=$CORPORATION/L=$CITY/ST=$STATE/C=$COUNTRY" \
  -new \
  -x509 \
  -passout pass:$CERT_AUTH_PASS \
  -keyout ca-cert.key \
  -out ca-cert.crt \
  -days 36500

# create client private key (used to decrypt the cert we get from the CA)
openssl genrsa -out ${SERVER}.key

# Creating csr_signer.sh script

echo '# Creating script for signing .CSR file' > csr_signer.sh
echo '#!/bin/bash' >> csr_signer.sh
echo '# sign the certificate with the certificate authority' >> csr_signer.sh
echo '#read -p "Enter server FQDN name of .CSR file: " SERVER' >> csr_signer.sh
echo '[[ -a $1 ]] || { echo "Missing .csr file as argument" >&2; exit 1; }' >> csr_signer.sh
echo 'arg_file=$1' >> csr_signer.sh
echo 'SERVER=${arg_file::-4}' >> csr_signer.sh
echo 'CERT_AUTH_PASS=$(cat < cert_auth_password)' >> csr_signer.sh
echo 'openssl \' >> csr_signer.sh
echo 'x509 \' >> csr_signer.sh
echo '-req \' >> csr_signer.sh
echo '-days 36500 \' >> csr_signer.sh
echo '-in ${SERVER}.csr \' >> csr_signer.sh
echo '-CA ca-cert.crt \' >> csr_signer.sh
echo '-CAkey ca-cert.key \' >> csr_signer.sh
echo '-CAcreateserial \' >> csr_signer.sh
echo '-out ${SERVER}.crt \' >> csr_signer.sh
echo '-extfile <(cat /etc/ssl/openssl.cnf <(printf "[SAN]\nsubjectAltName=DNS:$SERVER")) \' >> csr_signer.sh
echo '-extensions SAN \' >> csr_signer.sh
echo '-passin pass:${CERT_AUTH_PASS}' >> csr_signer.sh
echo 'path=$(pwd)' >> csr_signer.sh
echo 'cd ${path}' >> csr_signer.sh
echo 'mv ${path}/${SERVER}.crt ./signed_cert/${SERVER}.pem' >> csr_signer.sh
echo 'mv ${path}/${SERVER}.csr ./signed_cert/' >> csr_signer.sh
echo 'cd signed_cert' >> csr_signer.sh
echo 'zip ${SERVER}.zip root_CA.pem ${SERVER}*' >> csr_signer.sh
echo 'rm -f ${SERVER}.csr ${SERVER}.pem' >> csr_signer.sh
echo 'echo ".csr signed!"' >> csr_signer.sh

chmod u+x csr_signer.sh
# create the CSR(Certitificate Signing Request)

openssl \
  req \
  -new \
  -nodes \
  -subj "/CN=$SERVER/OU=$GROUP/O=$CORPORATION/L=$CITY/ST=$STATE/C=$COUNTRY" \
  -sha256 \
  -extensions v3_req \
  -reqexts SAN \
  -key $SERVER.key \
  -out $SERVER.csr \
  -config <(cat /etc/ssl/openssl.cnf <(printf "[SAN]\nsubjectAltName=DNS:$SERVER")) \
  -days 36500

openssl x509 -in ca-cert.crt -out signed_cert/root_cert.pem -outform PEM
echo 'Require zip to be installed and available'
echo 'sudo apt install zip unzip'

