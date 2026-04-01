# rmq-oauth-keycloak


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


