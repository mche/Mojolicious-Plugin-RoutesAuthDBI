openssl req -x509 -nodes -days 365 -newkey rsa:1024 \
    -keyout ssl.key \
    -out ssl.crt <<EOF
BE
Brussels

My project
Development
api.dropbox.com

EOF
