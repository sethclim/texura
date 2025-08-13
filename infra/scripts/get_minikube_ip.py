#!/usr/bin/env python3
import subprocess
import json

ip = subprocess.check_output(["minikube", "ip", "--profile", "texura-dev"]).decode("utf-8").strip()
print(json.dumps({"ip": ip}))