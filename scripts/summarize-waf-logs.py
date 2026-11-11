"""Summarize CloudWatch filter-log-events JSON without exposing request values."""
import json
import sys

response = json.load(sys.stdin)
records = []
unparsed = 0
for event in response.get("events", []):
    try:
        record = json.loads(event["message"])
    except (KeyError, TypeError, json.JSONDecodeError):
        unparsed += 1
        continue
    request = record.get("httpRequest", {})
    checks = {}
    for header in request.get("headers", []):
        name = header.get("name", "").lower()
        if name in {"cookie", "authorization"}:
            checks[name] = header.get("value") == "REDACTED"
    records.append({
        "Timestamp": record.get("timestamp"),
        "Action": record.get("action"),
        "TerminatingRuleId": record.get("terminatingRuleId"),
        "SensitiveHeaderRedactionChecks": checks,
        "QueryStringRedacted": request.get("args") == "REDACTED",
    })
print(json.dumps({"ParsedRecords": len(records), "UnparsedEvents": unparsed,
                  "Records": records}, indent=2))
