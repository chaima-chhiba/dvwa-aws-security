- Learner Lab preflight (2026-10-28): ECS, ECR, RDS, ALB, Secrets Manager, CloudWatch, SNS, CloudTrail, NAT, WAF (regional + CloudFront scope) allowed. CloudFront blocked, ACM unavailable. IAM server certificate upload allowed.
- Decision: HTTPS via self-signed certificate uploaded to IAM, attached to an ALB HTTPS listener (replaces ACM). WAF attached directly to the ALB.
- Evidence: evidence/00-baseline/lab-preflight.txt

## 2026-10-28 - Baseline deployment
- terraform apply succeeded (15 resources). Baseline destroyed at end of session.
- Open issue: browser to task public IP gave ERR_CONNECTION_RESET. To check: curl from WSL, ECS service events, container logs (/ecs/dvwa-baseline), ECR image present.

## 2026-11-02 - Baseline evidence
- attacks.sh on baseline: SQLi (5 users dumped), reflected XSS, direct DB access from internet (3306), plaintext DB_PASSWORD in task definition: all succeeded.
- Evidence: evidence/00-baseline/

## 2026-11-11 - Layer 2 HTTPS troubleshooting
- Saved three user-provided screenshots in evidence/02-https; deployment is not yet verified.
- Certificate upload failed because provider default tags required denied iam:TagServerCertificate. Added an untagged certificate provider.
- Remaining ECS plan change was Stage tags only. Preserved the service's layer1 tag to avoid an unnecessary service update.
- Evidence checklist: evidence/02-https/README.md. Next: validate and review the new plan before applying.

- User-provided revised plan confirms only aws_iam_server_certificate.alb and aws_lb_listener.https will be created: 2 add, 0 change, 0 destroy. Saved evidence/02-https/04-reviewed-plan.png. Deployment success pending.

- Layer 2 apply succeeded (user screenshot): 2 added, 0 changed, 0 destroyed. IAM certificate and HTTPS listener created. Evidence: evidence/02-https/05-apply-complete.png. HTTP redirect and HTTPS response validation pending.

- User evidence confirms HTTP 301 redirect to HTTPS and HTTPS HTTP/2 200 on /login.php using curl -k. Saved sanitized observation in evidence/02-https/08-connectivity-observed.txt; removed Set-Cookie headers from response files. Certificate verification and TLS details remain to be checked.

- TLS handshake confirmed by user output: TLSv1.3, TLS_AES_128_GCM_SHA256, X25519 ephemeral key exchange. Expected self-signed certificate verification error observed. Evidence: evidence/02-https/09-tls-details.txt and 10-tls-handshake.png. This establishes client-to-ALB TLS only; backend remains HTTP and public certificate trust is not established.

- Saved AWS console screenshots: 11-alb-overview.png (active internet-facing ALB) and 12-alb-listeners.png (HTTP:80 redirect to HTTPS:443 with HTTP_301; HTTPS:443 forwards to dvwa-layer1-tg). Full TLS policy and certificate name are truncated in the listener table; detailed evidence remains pending.

- Saved 13-https-listener-details.png and 14-iam-certificate.png. Console confirms imported IAM certificate attached as default to HTTPS:443, forwarding to the app target group. Certificate expires December 11, 2026 at 22:04 (UTC+01:00); expiry warning is consistent with the 30-day lab certificate. Full TLS security policy screenshot still pending.

- Final console evidence saved: evidence/02-https/15-tls-security-policy.png confirms ELBSecurityPolicy-TLS13-1-2-2021-06; mTLS is off. Layer 2 deployment, HTTP redirect, HTTPS response, negotiated TLS 1.3, IAM certificate attachment, and listener policy are documented. Optional packet capture remains uncollected. Limitations: self-signed certificate requires explicit trust; ALB-to-app remains HTTP; application vulnerabilities remain. No claim of end-to-end encryption.

## 2026-11-11 - Layer 3 preparation
- Layer 2 committed and pushed as 5487b4c on layer2; created layer3 branch.
- Added regional WAF managed common and SQL injection rule groups, metrics, sampling, and ALB association. Full log delivery remains for Layer 5.
- Layer 3 explicitly reuses terraform/layer2/terraform.tfstate via a local backend; no state copy. After Layer 3 apply, use Layer 3 for management and teardown. Deployment and filtering results remain unverified.
- Layer 3 initialization and terraform validate passed with pinned providers; workspace is default. AWS plan and deployment pending.

- User-provided Layer 3 plan confirms only aws_wafv2_web_acl.dvwa and aws_wafv2_web_acl_association.alb will be created: 2 add, 0 change, 0 destroy. Evidence: evidence/03-waf/01-reviewed-plan.png. Apply and filtering validation pending.

- Layer 3 apply succeeded per user screenshot: 2 added, 0 changed, 0 destroyed. Saved evidence/03-waf/02-apply-complete.png. WAF association readback, benign HTTPS availability, and rule evidence remain pending; filtering effectiveness is not yet demonstrated.

- User output confirms get-web-acl-for-resource returns dvwa-layer1-waf for the existing ALB, and benign HTTPS /login.php returns 200. Saved evidence/03-waf/05-association-and-availability.png; command outputs saved as 03-alb-waf-association.json and 04-benign-https-check.txt. Managed rule configuration and measured filtering evidence still pending.

- Saved evidence/03-waf/06-waf-console-overview.png: WAF console lists dvwa-layer1-waf with two rules. Rule names/actions and associated resource detail screenshots remain pending.

- Saved 07-managed-rule-groups.png: AWSManagedRulesCommonRuleSet precedes AWSManagedRulesSQLiRuleSet; console shows 700 and 200 WCU respectively. Numeric priorities and override actions are not visible in this screenshot.
- Saved 08-console-resource-permission-limits.png: console denies apprunner:ListAssociatedServicesForWebAcl and wafv2:ListResourcesForWebACL. ALB is displayed, but association proof remains the successful earlier get-web-acl-for-resource readback. No IAM changes needed for this evidence workaround.

- WAF API readback verified in user screenshot: default Allow; AWSManagedRulesCommonRuleSet priority 10 and AWSManagedRulesSQLiRuleSet priority 20; each has OverrideAction None and AWS vendor. Saved evidence/03-waf/10-rule-configuration-readback.png; JSON captured as 09-rule-configuration.json. Deployment, association, benign HTTPS availability, and intended rule configuration verified. Metrics and measured blocking effectiveness remain unverified.

- Saved evidence/03-waf/11-dashboard-insights-overview.png. Dashboard shows zeros in traffic-insight recommendation categories and Last 3 hours selected; request metrics and sampled-request rows are below the visible area. These zeros do not demonstrate zero requests or successful blocking. Request metrics and filtering measurement remain pending.

- WAF dashboard user screenshot shows Last 3 hours: Total 9, Allowed 9, Blocked 0, CAPTCHA 0, Challenged 0, Monetized 0. Saved evidence/03-waf/12-request-metrics.png. Confirms dashboard request metrics are populated; does not establish request origins, absence of false positives generally, or blocking effectiveness. Sampled request rows are not visible.

- Sampled requests subsequently became visible in user screenshot. Saved evidence/03-waf/13-sampled-allowed-requests.png. Visible rows use dvwa-web-acl metric, show ALLOW for paths including /, /sse, /login.php, /favicon.ico, and /mcp; no rule inside a rule group is listed for those rows. Request origins are not attributed. This supersedes the earlier user-reported empty sampling view; no blocking result has been observed.

## 2026-11-11 - Layer 4 preparation
- Layer 3 evidence committed/pushed as c56bf5e after explicit approval to include screenshots with source IPs in the private repository.
- Created layer4 branch. Prepared secret/version/resource policy restricted to existing LabRole, JSON-key ECS secret injection, platform 1.4.0, and shared local state.
- Removed password default in Layer 4 and marked private password input sensitive. Existing database password must be supplied unchanged; no rotation intended.
- Local initialization and Terraform validation passed. AWS plan, permissions, replacement deployment, and runtime retrieval remain unverified. ECS service replacement will interrupt availability; secrets/state/runtime environment limitations documented in terraform/layer4/README.md.

- User Layer 4 plan shows 5 add, 1 change, 2 destroy. ECS service/task definition replacements and Secrets Manager additions expected; aws_db_instance.dvwa in-place update is unexpected. Apply paused pending sanitized DB diff review. Evidence: evidence/04-secrets/01-plan-unexpected-db-update.png. Password mismatch is a possibility, not a confirmed diagnosis.

- Sanitized DB diff identifies password as the sole visible changed attribute. Saved evidence/04-secrets/02-db-password-diff.png. User instructed to reuse the existing state-managed password locally without printing it, then re-plan. No apply performed; no database rotation intended.

- Revised user plan after locally reusing the state-managed DB password: 5 add, 0 change, 2 destroy. Only ECS service/requested replacement, task definition replacement, and secret/policy/version additions listed; database update resolved. Saved evidence/04-secrets/03-reviewed-plan.png. Apply and runtime retrieval remain pending.

- User screenshot confirms Layer 4 apply complete: 5 added, 0 changed, 2 destroyed. Saved evidence/04-secrets/04-apply-complete.png. Service health, runtime secret retrieval, sanitized task-definition references, and database-dependent application check remain pending.

- ECS service readback shows ACTIVE, desired/running 1, pending 0, Failures empty, task definition revision 2. Events confirm deployment completed and steady state. Saved evidence/04-secrets/06-service-steady-state.png and user command output 05-service-health.json. Credential-reference inspection and database-dependent functional check remain pending.

- Sanitized local-state check passed for task definition revision 2: no DB_USER/DB_PASSWORD plaintext environment entries; both exact expected Secrets Manager JSON-key references present. Saved evidence/04-secrets/08-secret-reference-check.png; JSON saved as 07-secret-reference-check.json. Revision matches earlier ECS service API readback. This is local-state evidence, not DescribeTaskDefinition API proof. Database-dependent login check remains pending.

- User screenshot shows DVWA home at HTTPS /index.php after certificate-warning guidance. Saved evidence/04-secrets/09-dvwa-home-https.png. Browser flags untrusted self-signed certificate as expected. Screenshot alone does not establish a fresh database-backed login versus an existing session; fresh login confirmation remains pending.

- User clarified that 09-dvwa-home-https.png was captured immediately after logging in, not merely reopening an existing session. Fresh application login succeeded after Layer 4 deployment (user-confirmed functional check). Combined with revision 2 running and sanitized secret-reference check, this supports successful secret-backed database authentication. Remaining evidence: secret metadata/resource policy and explicit target-health readback; plaintext history/state/runtime-environment limitations still apply.

- Saved 10-secrets-manager-list.png and 11-secret-metadata.png: secret exists in us-east-1; name/ARN match configured references; encryption key aws/secretsmanager shown; secret value not retrieved in screenshot. List shows last retrieved November 11, 2026, without identifying the caller. Remaining evidence: resource policy readback and explicit target-health check.

- Secret resource policy readback confirms Allow for arn role/LabRole, action secretsmanager:GetSecretValue, scoped to the database secret ARN. Saved evidence/04-secrets/13-resource-policy-readback.png; JSON captured as 12-secret-resource-policy.json. This is a scoped grant, not proof that only LabRole can access the secret or that LabRole has least privilege overall. Explicit ALB target-health evidence remains pending.

- Final Layer 4 target-group screenshot: one total target, one healthy, zero unhealthy/initial/draining. Saved evidence/04-secrets/14-target-healthy.png. Backend protocol HTTP:80 remains visible and documented as a TLS limitation. Layer 4 evidence collected: apply, ECS steady state/revision 2, sanitized credential reference check, user-confirmed fresh login, secret metadata, scoped resource policy, target health. This does not erase historical plaintext task revisions/state or remove credentials from runtime environment.

## 2026-11-11 - Layer 5 preflight
- CloudTrail describe-trails with shadow trails in us-east-1 returned an empty list for the lab session. Saved evidence/05-logging/02-existing-trails-readback.png; command output saved as 01-existing-trails.json. This does not imply CloudTrail Event history is unavailable. Logging configuration not yet prepared or applied.

- Saved evidence/05-logging/04-labrole-trust-policy.png. Visible LabRole trust statement includes multiple AWS service principals; screenshot ends before the full policy is visible. Presence/absence of vpc-flow-logs.amazonaws.com is not yet determined. Full JSON was saved by the user command as 03-labrole-trust-policy.json.

- Full-file trust-policy check returned no explicit vpc-flow-logs.amazonaws.com principal. Saved evidence/05-logging/06-flow-logs-trust-check.png. Decision: prepare VPC Flow Logs delivery to S3 rather than modifying LabRole trust for CloudWatch delivery. S3 delivery permissions/configuration remain unverified; existing VPC flow logs must be checked before creating resources.

- VPC-filtered describe-flow-logs returned an empty list per user screenshot; saved evidence/05-logging/08-existing-flow-logs-readback.png. No VPC-level flow log returned. Layer 5 preparation will add logging without changing application deployment.

- Prepared Layer 5 on layer5 branch: WAF logs to CloudWatch with Cookie/Authorization/query redaction; VPC Flow Logs and regional CloudTrail to a private encrypted S3 archive; blocked-request alarm and SNS email subscription. Existing application configuration retained. Alert recipient supplied by user will be a sensitive runtime input, not committed.
- Initialized against the same Layer 2 state; default workspace; terraform validate passed. Expected 14 resource additions, no changes/destruction, pending real AWS plan. Delivery permissions, alarm dimensions, subscription confirmation and actual log/alert delivery remain unverified. Lab log archive is force-deleted on teardown; export needed evidence first.

- User Layer 5 plan matches expected logging/alerting additions: 14 add, 0 change, 0 destroy. Saved evidence/05-logging/09-reviewed-plan.png. Existing application, network, WAF rules, and secrets have no listed resource changes. Apply, subscription confirmation, and actual log/alert delivery remain pending. Screenshot includes alert recipient; anonymize before public report use.

- Layer 5 partial apply: user screenshot shows SNS subscription and alarm creation completed; aws_s3_bucket.audit errored while reading GetObjectLockConfiguration (403, explicit SCP deny). Saved evidence/05-logging/10-partial-apply-s3-read-denied.png. Bucket may exist despite error; inspect state/provider behavior before retry. Full deployment and log delivery not verified.

- HeadBucket succeeds for dvwa-audit-20261111221542314000000001 in us-east-1; saved 11-existing-bucket-accessible.png. Existing bucket can be retained. Investigating explicit ownership handoff for only the generic bucket resource, while dedicated Terraform resources continue managing logging controls. No bucket deletion performed.

- Prepared a Terraform removed block with destroy=false for aws_s3_bucket.audit and direct references to the accessible existing bucket. Dedicated bucket policy/encryption/public-access/ownership/retention resources remain managed. Terraform >=1.7 required; local installed version 1.17.0. Formatting and validation passed. No handoff/state mutation applied yet. One-time no-refresh recovery plan needed because old binding triggers denied read; subsequent plans must restore normal refresh. Bucket cleanup is now explicit after Terraform teardown.

- User recovery plan with refresh disabled shows 7 add, 0 change, 0 destroy; aws_s3_bucket.audit will no longer be managed but will not be destroyed. Remaining additions are CloudTrail, Flow Log, and five dedicated bucket controls. Saved evidence/05-logging/12-reviewed-recovery-plan.png. Recovery apply and subsequent normal-refresh convergence check pending.

- User recovery apply succeeded: 7 added, 0 changed, 0 destroyed. Saved evidence/05-logging/13-recovery-apply-complete.png. Outputs include trail, flow log, WAF log group and alert topic. Bucket retained through no-delete handoff. Normal refreshed convergence plan and actual log/notification delivery remain unverified. Use Layer 5 for all further management; bucket cleanup remains explicit.

- Normal Layer 5 plan with refresh enabled reports No changes; infrastructure matches configuration. Saved evidence/05-logging/14-refreshed-plan-no-changes.png. One-time no-refresh recovery completed; subsequent runs use default refresh. Actual log delivery, SNS confirmation and notification testing remain pending.

- Initial CloudTrail status: IsLogging true; LatestDeliveryTime, LatestDeliveryError, and LatestDigestDeliveryTime null. Saved evidence/05-logging/16-cloudtrail-initial-status.png and user JSON 15-cloudtrail-status.json. Logging enabled, but successful record/digest delivery not yet demonstrated; recheck after other delivery checks.

- Flow Log readback: ACTIVE, DeliverLogsStatus SUCCESS, delivery error null, expected S3 flowlogs/ destination. Saved evidence/05-logging/18-flow-log-delivery-status.png and user JSON 17-flow-log-status.json. Actual S3 object listing/content verification remains pending; CloudTrail first delivery still pending in last recorded status.

- Initial archive listing screenshot shows zero-byte prefix/folder-marker objects under flowlogs/ and cloudtrail/. Saved evidence/05-logging/20-initial-archive-folder-markers.png. Screenshot is cropped; visible zero-byte objects do not demonstrate delivered log records. Need filtered non-empty object listing; Flow Logs status SUCCESS alone is insufficient for content verification.

- Filtered archive listing returned [] for both flowlogs/ and cloudtrail/; saved evidence/05-logging/22-no-nonempty-objects-yet.png and user text 21-nonempty-log-objects.txt. Neither S3 destination has demonstrated non-empty log delivery yet. Continue WAF CloudWatch verification, then recheck S3 delivery and status/errors; do not infer successful delivery from folder markers.

- User check returned HTTPS 200 and CloudWatch WAF summary ParsedRecords 0, UnparsedEvents 0, Records []. Saved evidence/05-logging/24-waf-query-no-events.png. Application availability retained; WAF log-event delivery not yet verified. Need WAF logging configuration/streams readback and refreshed CloudTrail status before attributing missing logs to delay.

- User recheck confirms WAF destination aws-waf-logs-dvwa-layer1, redaction for query string/authorization/cookie, and log stream with last-event timestamp. CloudTrail IsLogging true, LatestDeliveryTime 2026-11-11 23:25:16 +01:00 and successful delivery attempt timestamp. Saved evidence/05-logging/28-logging-config-and-delivery-readback.png. Earlier empty queries were point-in-time observations; sanitized WAF record inspection and non-empty S3 listings still needed. CloudTrail digest delivery not demonstrated in visible screenshot.

- WAF filter-log-events recheck still returns ParsedRecords 0, UnparsedEvents 0 despite stream last-event metadata. Saved evidence/05-logging/30-filter-query-still-empty.png and user summary 29-waf-record-summary.json. Actual WAF record retrieval/redaction verification remains unresolved; next inspect named stream directly without changing logging configuration.

- Direct CloudWatch stream read returned 9 parsed WAF records, 0 unparsed. Screenshot shows at least three BLOCK decisions attributed to AWSManagedRulesCommonRuleSet and ALLOW decisions attributed to Default_Action; visible query-string redaction checks true. Saved evidence/05-logging/32-waf-records-direct-read.png and user JSON 31-direct-stream-summary.json. This demonstrates actual WAF record delivery and observed blocking, but does not establish request origin, maliciousness, specific SQLi/XSS test effectiveness, or subrule attribution. Empty sensitive-header checks do not verify cookie/authorization redaction. Filter API discrepancy remains unexplained.

- Alarm readback: OK, ActionsEnabled true; reason is no datapoints for one period with missing data treated as non-breaching. Dimensions Region us-east-1, Rule ALL, WebACL dvwa-web-acl. SNS email subscription PendingConfirmation. Saved evidence/05-logging/35-alarm-and-pending-subscription.png. Notification delivery not ready; user must confirm subscription. Alarm metric matching/history still requires verification; current OK is not proof of successful block detection.

- Full saved list-metrics output confirms aggregate BlockedRequests dimensions WebACL=dvwa-layer1-waf, Region=us-east-1, Rule=ALL. Original alarm incorrectly used visibility metric name dvwa-web-acl, so it observed a different/missing series. Corrected Terraform to web ACL name; apply pending. Saved screenshot 37-blocked-metric-dimensions.png. Subrule series include NoUserAgent_HEADER/UserAgent_BadBots_HEADER, but these do not establish specific test attribution or SQLi/XSS mitigation results. SNS confirmation still pending in last recorded readback.

- User pasted alarm-fix plan summary: only aws_cloudwatch_metric_alarm.blocked updated in place; 0 add, 1 change, 0 destroy. Saved evidence/05-logging/38-reviewed-alarm-fix-plan.txt. Corrected alarm apply and notification confirmation/delivery remain pending.

- User screenshot confirms alarm dimension correction applied: 0 added, 1 changed, 0 destroyed. Saved evidence/05-logging/39-alarm-fix-apply-complete.png. Updated alarm API readback/evaluation, SNS subscription confirmation and email receipt remain pending; successful alarm apply alone is not notification proof.

- Corrected alarm API readback confirms Region us-east-1, WebACL dvwa-layer1-waf, Rule ALL. Current OK is due to no datapoints in evaluated period; automatic breach detection not demonstrated. SNS remains PendingConfirmation. Saved evidence/05-logging/42-corrected-alarm-subscription-pending.png. Email-delivery test deferred until recipient confirmation; do not claim notification success.

- User screenshot shows AWS Notification Subscription Confirmation email for the expected dvwa-layer1-security-alerts topic. Saved evidence/05-logging/43-sns-confirmation-email-received.png. Only link label is visible, not its confirmation token/URL. Confirms invitation receipt, not subscription confirmation or alarm notification delivery.

- SNS API readback now returns a concrete subscription ARN for protocol email instead of PendingConfirmation. Saved evidence/05-logging/45-sns-subscription-confirmed.png and user JSON 44-confirmed-subscription.json. Subscription activation verified. Next notification test will be explicitly simulated via manual alarm state; no claim of automatic metric-based detection from that test.

- User ran set-alarm-state ALARM with explicitly SIMULATED notification-test reason; command returned without visible error. Saved evidence/05-logging/46-simulated-alarm-test-command.png. Alarm action history and recipient email receipt remain unverified; this test is manual and not evidence of automatic WAF metric triggering.

- Received alarm email verified by screenshot evidence/05-logging/48-simulated-alarm-email-received.png. Email shows OK -> ALARM, explicitly SIMULATED test reason, corrected dimensions WebACL=dvwa-layer1-waf / Region=us-east-1 / Rule=ALL, timestamp 2026-11-11 22:39:39 UTC (23:39:39 Lagos). Confirms manual CloudWatch alarm action -> SNS -> recipient email delivery. Does not prove automatic metric-based triggering. Outstanding: non-empty Flow Logs/CloudTrail object evidence and final convergence/health checks; alarm action history optional supporting evidence.

- Saved 50-cloudtrail-delivered-files.png. Inspected complete user output 49-delivered-log-objects.txt: non-empty .log.gz objects under flowlogs/ and .json.gz records under cloudtrail/CloudTrail/. Both archive destinations now have actual non-empty objects, beyond prior folder markers. Saved metadata summary in 51-archive-delivery-summary.json. Object content parsing and CloudTrail digest cryptographic validation have not been performed.

- Final user refreshed Layer 5 plan: No changes; configuration matches infrastructure. Saved evidence/05-logging/52-final-plan-no-changes.png. Verified: WAF records with observed BLOCK/ALLOW and query redaction, non-empty S3 Flow Logs/CloudTrail objects, confirmed SNS email subscription, manual simulated alarm email received. Limits: automatic metric-based alarm triggering not demonstrated; cookie/header redaction not empirically checked; object content/digest cryptographic validation not performed. Separate S3 bucket cleanup required after Terraform teardown; preserve report evidence first.
