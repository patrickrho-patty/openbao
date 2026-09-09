#!/usr/bin/env python3
import json
with open("/opt/openbao/init-response.json") as f:
    data = json.load(f)
print(f"  Root token: {data['root_token'][:30]}...")
for i, key in enumerate(data["keys"], 1):
    print(f"  Unseal key {i}: {key['key'][:20]}...")
print(f"\n  Total keys: {len(data['keys'])}")
print(f"  Threshold:  {data.get('keys', [0])[0] if data.get('keys') else 'n/a'}")
