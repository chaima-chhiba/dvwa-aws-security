# Layer 5 evidence checklist

## Preflight captured
- No trails returned by describe-trails: 01-existing-trails.json and 02-existing-trails-readback.png.
- LabRole trust policy and full-file service-principal check: 03 through 06.
- No VPC-level flow logs returned: 07-existing-flow-logs.json and 08-existing-flow-logs-readback.png.

## Still needed
- [ ] Reviewed plan, expected logging-only additions.
- [ ] Successful apply.
- [ ] WAF log delivery and redaction checked on actual records.
- [ ] VPC Flow Log status and delivered S3 records.
- [ ] CloudTrail status and delivered S3 records.
- [ ] SNS confirmed subscription and received test notification.
- [ ] Alarm metric dimensions/configuration and accurately labeled alert test.
- [ ] Normal application availability retained.

No Layer 5 AWS deployment or runtime delivery is verified yet.
Do not save credentials, cookies, email confirmation tokens, raw state, or unsanitized
request details. Distinguish simulated alarm tests from actual observed detection.
