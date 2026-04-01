import pika
import requests
import urllib3

# Suppress insecure request warnings for our local self-signed Keycloak cert
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# --- 1. CONFIGURATION ---
KEYCLOAK_URL = "https://10.0.0.173:8443/realms/master/protocol/openid-connect/token"
CLIENT_ID = "rmq-test"
CLIENT_SECRET = "IfDOEPpO7FsKtjurO19cSeuvbwB2lKs9"
RABBITMQ_HOST = "localhost"
RABBITMQ_PORT = 5672
QUEUE_NAME = "oauth2_test_queue"

# --- 2. FETCH THE OAUTH2 TOKEN ---
print("1. Fetching token from Keycloak...")
payload = {
    "grant_type": "client_credentials",
    "client_id": CLIENT_ID,
    "client_secret": CLIENT_SECRET
}

response = requests.post(KEYCLOAK_URL, data=payload, verify=False)
response.raise_for_status()
token = response.json()["access_token"]
print("   [Success] Token acquired!\n")


# --- 3. CONNECT TO RABBITMQ ---
print("2. Connecting to RabbitMQ via AMQP...")

# RabbitMQ OAuth2 accepts the token in the password field with a blank username
credentials = pika.PlainCredentials('', token)

parameters = pika.ConnectionParameters(
    host=RABBITMQ_HOST,
    port=RABBITMQ_PORT,
    virtual_host='/',
    credentials=credentials
)

try:
    connection = pika.BlockingConnection(parameters)
    channel = connection.channel()
    print("   [Success] Connected to RabbitMQ Broker!\n")
except Exception as e:
    print(f"   [Failed] Connection error. Did you add the configure/write/read scopes in Keycloak?\nError: {e}")
    exit(1)


# --- 4. PERFORM AMQP OPERATIONS ---
print(f"3. Declaring queue: '{QUEUE_NAME}'...")
# Requires 'rabbitmq.configure:*/*' scope
channel.queue_declare(queue=QUEUE_NAME)

message_body = "Hello from Python! Authentication powered by OAuth 2.0!"
print(f"4. Publishing message: '{message_body}'...")
# Requires 'rabbitmq.write:*/*' scope
channel.basic_publish(
    exchange='',
    routing_key=QUEUE_NAME,
    body=message_body
)

print("5. Reading message from queue...")
# Requires 'rabbitmq.read:*/*' scope
method_frame, header_frame, body = channel.basic_get(queue=QUEUE_NAME, auto_ack=True)

if method_frame:
    print(f"   [Success] Message Received: {body.decode()}\n")
else:
    print("   [Failed] No message returned.\n")


# --- 5. CLEAN UP ---
print("6. Cleaning up...")
channel.queue_delete(queue=QUEUE_NAME)
connection.close()
print("   [Success] Connection closed. Test Complete!")
