# rmq-oauth-keycloak

Intructions to setup and test RabbitMQ with Keycloak Oauth setup.

```
openssl req -newkey rsa:2048 -nodes \
  -keyout keycloak.key \
  -x509 -days 365 \
  -out keycloak.crt \
  -subj "/CN=host.docker.internal"
```

```
chmod 777 keycloak.key keycloak.crt
```

```
docker run --platform linux/arm64 -p 8080:8080 -p 8443:8443 \
  -e KC_BOOTSTRAP_ADMIN_USERNAME=admin \
  -e KC_BOOTSTRAP_ADMIN_PASSWORD=password \
  -v $(pwd)/keycloak.crt:/opt/keycloak/server.crt \
  -v $(pwd)/keycloak.key:/opt/keycloak/server.key \
  quay.io/keycloak/keycloak:latest start-dev \
  --https-certificate-file=/opt/keycloak/server.crt \
  --https-certificate-key-file=/opt/keycloak/server.key
```


````
export TOKEN=$(curl -s -k -X POST https://10.0.0.173:8443/realms/master/protocol/openid-connect/token \
  -d "grant_type=client_credentials" \
  -d "client_id=arul" \
  -d "client_secret=xxxxxxxxxxx" | grep -o '"access_token"\s*:\s*"[^"]*"' | awk -F'"' '{print $4}')

```

```
echo $TOKEN
```

```
curl -i -H "Authorization: Bearer $TOKEN" http://localhost:15673/api/whoami
HTTP/1.1 200 OK
allow: HEAD, GET, OPTIONS
cache-control: no-cache
content-length: 65
content-security-policy: script-src 'self' 'unsafe-eval' 'unsafe-inline'; object-src 'self'
content-type: application/json
date: Wed, 01 Apr 2026 13:21:56 GMT
server: Cowboy
vary: accept, accept-encoding, origin

{"name":"arul","tags":["administrator"],"is_internal_user":false}%

```