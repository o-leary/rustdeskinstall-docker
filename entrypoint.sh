HTTP_USER="$(< /run/secrets/http_user)"
HTTP_PASS="$(< /run/secrets/http_pass)"

cd /opt/rustdesk
./hbbs &
./hbbr &
cd /opt/gohttp
./gohttpserver -r ./public --port 8000 --auth-type http --auth-http $HTTP_USER:$HTTP_PASS &

sleep infinity
