"""Emit credential names and references only; never print raw state or values."""
import json
from pathlib import Path

state = json.loads(Path("terraform/layer2/terraform.tfstate").read_text())
resources = state["resources"]
task = next(r for r in resources if r["mode"] == "managed"
            and r["type"] == "aws_ecs_task_definition" and r["name"] == "dvwa")
attributes = task["instances"][0]["attributes"]
container = next(c for c in json.loads(attributes["container_definitions"])
                 if c["name"] == "dvwa")
credentials = {"DB_USER", "DB_PASSWORD"}
plaintext_names = sorted(e["name"] for e in container.get("environment", [])
                         if e["name"] in credentials)
secret = next(r for r in resources if r["mode"] == "managed"
              and r["type"] == "aws_secretsmanager_secret" and r["name"] == "db")
secret_arn = secret["instances"][0]["attributes"]["arn"]
expected = {"DB_USER": f"{secret_arn}:username::",
            "DB_PASSWORD": f"{secret_arn}:password::"}
references = {e["name"]: e.get("valueFrom", "")
              for e in container.get("secrets", []) if e["name"] in credentials}
valid = not plaintext_names and references == expected
print(json.dumps({
    "EvidenceSource": "Local Terraform state; not an ECS API readback",
    "TaskDefinition": attributes["arn"],
    "PlaintextCredentialNames": plaintext_names,
    "ExpectedSecretReferencesPresent": references == expected,
    "CredentialReferences": {name: ref if ref == expected.get(name)
                              else "[unexpected reference withheld]"
                              for name, ref in references.items()},
    "Passed": valid,
}, indent=2))
raise SystemExit(0 if valid else 1)
