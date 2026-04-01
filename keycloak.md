# Keycloak OAuth2 Configuration for RabbitMQ
This guide details how to configure Keycloak as an OAuth 2.0 provider for RabbitMQ. It uses the Client Credentials flow (machine-to-machine) and leverages Keycloak's Realm Roles to pass RabbitMQ tags (Management UI access) and AMQP scopes (Queue/Message access) directly into the token payload.

Note: This exact concept—creating custom roles and assigning them to a service principal—maps 1:1 with how Azure Entra ID (App Roles) works!

- Step 1: Create the RabbitMQ Client
First, we need to create the application representation (Client) in Keycloak.

Log in to the Keycloak Admin Console.

Ensure you are in the correct Realm (e.g., master).

In the left-hand navigation menu, click on Clients.

Click the Create client button.

- General Settings:

Client type: OpenID Connect

Client ID: rmq-test (or your preferred name)

Click Next.

Capability Config:

Client authentication: Set to ON (This enables the client_secret).

Standard flow: Set to OFF (Since this is a backend service, we don't need browser logins).

Direct access grants: Set to OFF.

Service accounts roles: Set to ON (This enables the Client Credentials grant type).

Click Save.

Go to the Credentials tab of your new client and copy the Client secret. You will need this for your scripts.

- Step 2: Create the RabbitMQ Realm Roles
RabbitMQ expects specific string formats for its permissions. We will create these as Keycloak Realm Roles so they are automatically injected into the realm_access.roles array of the JWT.

In the left-hand navigation menu, click on Realm Roles.

Click Create role.

Create the following four roles exactly as written (create them one by one):

rabbitmq.tag:administrator (Grants full access to the HTTP Management API)

rabbitmq.configure:*/* (Grants AMQP permission to declare queues/exchanges on any vhost)

rabbitmq.write:*/* (Grants AMQP permission to publish messages on any vhost)

rabbitmq.read:*/* (Grants AMQP permission to consume messages on any vhost)

-   Step 3: Assign Roles to the Client's Service Account
Now we must link the permissions to the client we created in Step 1.

In the left-hand navigation menu, click on Clients.

Click on your client (rmq-test).

Click on the Service accounts roles tab at the top.

Click the Assign role button.

In the filter/search box, find and select the four roles you just created:

rabbitmq.tag:administrator

rabbitmq.configure:*/*

rabbitmq.write:*/*

rabbitmq.read:*/*

Click Assign.

Step 4: Verify the Configuration
You can now generate a token and verify that Keycloak is formatting the payload correctly for RabbitMQ.

1. Fetch the Token (Bash)
Use the Client Credentials grant to fetch a token. Replace YOUR_IP and YOUR_SECRET with your actual values.

Bash
export TOKEN=$(curl -s -k -X POST https://YOUR_IP:8443/realms/master/protocol/openid-connect/token \
  -d "grant_type=client_credentials" \
  -d "client_id=rmq-test" \
  -d "client_secret=YOUR_SECRET" | grep -o '"access_token"\s*:\s*"[^"]*"' | awk -F'"' '{print $4}')
2. Decode and Inspect
If you decode the $TOKEN (e.g., using jwt.io or a local script), you must see all four roles sitting inside the realm_access block:

JSON
"realm_access": {
  "roles": [
    "default-roles-master",
    "rabbitmq.tag:administrator",
    "rabbitmq.configure:*/*",
    "rabbitmq.write:*/*",
    "rabbitmq.read:*/*"
  ]
}
3. Test the HTTP API
If the rabbitmq.tag:administrator role is present, this curl command will return a 200 OK:

Bash
curl -i -H "Authorization: Bearer $TOKEN" http://localhost:15673/api/whoami
4. Test AMQP (Python)
If the configure, write, and read roles are present, your Python pika client will successfully authenticate:

Python
import pika

# RabbitMQ OAuth2 uses the token as the password with a blank username
```
credentials = pika.PlainCredentials('', 'YOUR_OAUTH_TOKEN_STRING')
parameters = pika.ConnectionParameters(host='localhost', port=5672, virtual_host='/', credentials=credentials)

connection = pika.BlockingConnection(parameters)
print("Successfully connected via AMQP!")
connection.close()
```
