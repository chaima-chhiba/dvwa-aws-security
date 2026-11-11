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

- 09-reviewed-plan.png confirms 14 logging/alerting additions, 0 changes, 0 destruction. Contains recipient email; anonymize before public sharing. Apply and delivery validation pending.

- 10-partial-apply-s3-read-denied.png documents partial apply blocked by SCP on Object Lock read. 11-existing-bucket-accessible.png confirms HeadBucket succeeds. Prepared no-delete ownership handoff; recovery plan and successful deployment still pending. S3 bucket will require explicit teardown cleanup after handoff.

- 12-reviewed-recovery-plan.png: reviewed recovery plan has 7 additions, 0 changes, 0 destruction; existing bucket retained through destroy=false handoff. Recovery apply remains pending.

- 13-recovery-apply-complete.png records successful recovery (7 added, 0 changed, 0 destroyed). Next: normal-refresh plan, actual log delivery, subscription confirmation and alert delivery.

- 14-refreshed-plan-no-changes.png verifies normal refreshed convergence. Deployment configuration is converged; actual delivery checks remain pending.

- 16-cloudtrail-initial-status.png: logging enabled, no reported delivery error, delivery/digest timestamps null. CloudTrail delivery remains pending, not confirmed.

- 18-flow-log-delivery-status.png confirms ACTIVE/SUCCESS, no error, expected S3 destination. Next verify actual archive objects.

- 20-initial-archive-folder-markers.png shows visible zero-byte folder markers only. Actual log-file delivery remains unverified; next list non-empty objects.

- 22-no-nonempty-objects-yet.png records empty non-zero-size object lists for both prefixes. S3 runtime delivery remains unverified.

- 24-waf-query-no-events.png confirms HTTPS 200 but no WAF events returned. WAF actual record delivery still unverified; investigate configuration/streams and recheck trail status.

- 28-logging-config-and-delivery-readback.png confirms WAF destination/redaction configuration, a stream last-event timestamp, and CloudTrail successful delivery timestamp. Next inspect sanitized WAF records and actual non-empty S3 objects.

- 30-filter-query-still-empty.png records repeat empty filter query despite stream timestamp. Direct stream read pending; do not claim actual WAF record inspection yet.

- 32-waf-records-direct-read.png: 9 parsed records via direct stream read, visible BLOCK/CommonRuleSet and ALLOW/Default_Action, query-string redaction true. WAF delivery and observed block decisions verified; no attribution to a controlled exploit test. Cookie/Authorization redaction not empirically verified by empty header-check maps.

- 35-alarm-and-pending-subscription.png shows alarm OK due to missing data and SNS PendingConfirmation. Email receipt and metric-based triggering remain unverified.

- 36-blocked-metric-dimensions.json and 37-blocked-metric-dimensions.png reveal alarm WebACL mismatch. Corrected configuration to WebACL=dvwa-layer1-waf with Rule=ALL/Region=us-east-1. Plan/apply and automatic metric evaluation still pending.

- 38-reviewed-alarm-fix-plan.txt captures user-pasted expected alarm-only plan. Apply pending.

- 39-alarm-fix-apply-complete.png confirms successful alarm-only update. Next verify corrected dimensions, alarm evaluation, confirmed subscription and received notification.

- 42-corrected-alarm-subscription-pending.png verifies corrected dimensions; subscription still PendingConfirmation. Automatic triggering and email delivery remain unverified.

- 43-sns-confirmation-email-received.png proves confirmation invitation receipt for the expected topic; activation and alarm-email delivery still pending.

- 45-sns-subscription-confirmed.png verifies active email subscription by ARN. Notification receipt and automatic metric-based alarm triggering remain unverified.

- 46-simulated-alarm-test-command.png records manual simulated alarm request without visible CLI error. Action execution and email receipt still need verification.

- 48-simulated-alarm-email-received.png proves received email for explicitly manual simulated alarm test. Notification path verified; automatic WAF metric-triggered alarm remains unverified. Non-empty S3 log objects still need capture.

- 49-delivered-log-objects.txt and 51-archive-delivery-summary.json confirm non-empty log files under both flowlogs/ and cloudtrail/. 50-cloudtrail-delivered-files.png captures CloudTrail portion. Actual S3 object delivery verified; contents/digest cryptographic integrity not independently validated.

## Current verified status
52-final-plan-no-changes.png confirms final refreshed convergence. WAF direct-stream records, query redaction, Flow Logs/CloudTrail non-empty archive objects, confirmed SNS subscription, and received simulated alarm email are documented. Earlier pending notes are historical where superseded by later evidence. Automatic metric-based alarm triggering, cookie/authorization redaction behavior, and log-content/digest validation remain unverified. Bucket itself is now managed separately and must be explicitly cleaned up after Terraform teardown.
