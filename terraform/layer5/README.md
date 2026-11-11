# Layer 5: logging and monitoring

## Recovery from partial apply (Object Lock read denied)

The bucket was created, but aws_s3_bucket failed its automatic Object Lock read
because of an explicit lab SCP deny. HeadBucket subsequently confirmed access.
The generic resource is now replaced by a removed block with destroy=false,
and all dedicated bucket controls reference the existing bucket name directly.
No Object Lock permissions or protections are changed.

Review a ONE-TIME plan with -refresh=false to avoid the denied read while the
old bucket binding is still in state. This skips drift detection for that plan;
do not use it routinely. The plan must say the bucket will no longer be managed
but will not be destroyed, and must show no application/network replacements.
Back up the shared state locally before applying the reviewed recovery plan;
never publish that backup. After handoff, run a normal plan with refresh enabled
to verify convergence and detect drift. No state mutation has been performed by
editing the configuration alone.

The bucket now remains after terraform destroy. Record its name for cleanup.
For a fresh lab deployment, create an ordinary private bucket using the permitted
S3 CreateBucket API first, pass its name through audit_bucket_name, and let the
dedicated Terraform resources configure encryption, policy, retention and access.

Adds WAF CloudWatch logging (7-day retention), VPC Flow Logs to S3, regional
CloudTrail management-event delivery with log validation, and a CloudWatch
BlockedRequests alarm connected to an SNS email subscription.

## Preflight decisions

User readbacks returned no trails and no VPC-level flow logs. LabRole trust had
no explicit Flow Logs service principal. Flow Logs therefore use S3 delivery
without changing IAM roles. Trail coverage is us-east-1 plus global service events;
it is not a multi-region trail. S3 object/data events are not enabled.

The private S3 archive uses public-access blocking, BucketOwnerEnforced ownership,
AES256 encryption, TLS-only access, and source-scoped service delivery policies.
Objects expire after 30 days. The bucket itself is managed separately after the lab
SCP blocked the generic Terraform bucket read; see recovery below. This archive is
not immutable or production-grade; there is no Object Lock or versioning.

WAF log redaction covers Cookie, Authorization, and query strings; it does not
redact sampled requests or every possible sensitive custom header/path. Source IPs
remain in logs. Share only sanitized evidence; logging adds storage/ingestion costs.
AWS automatically sets up the WAF CloudWatch resource policy when logging is enabled;
lab permissions for that action must still be verified against actual apply output.

## State and private inputs

Uses the SAME local state at terraform/layer2/terraform.tfstate. No state copying.
After applying, use Layer 5 for plans/applies/destroy; earlier configurations omit
these resources and could remove them. Only the default workspace is supported.

Supply the existing DB password through TF_VAR_db_password unchanged, and recipient
through TF_VAR_alert_email. Both are sensitive Terraform inputs. The email is not
committed but still stored in state/subscription metadata. Never publish state or
saved plans, which also contain DB credentials and the TLS private key.

From the repository root in WSL Bash:

```bash
terraform -chdir=terraform/layer5 init -lockfile=readonly
terraform -chdir=terraform/layer5 validate
terraform -chdir=terraform/layer5 plan -no-color
```

Review the actual plan. Initial expected plan was 14 additions. After partial apply and handoff, review the remaining additions and state-only removal (plus
output changes). No ECS replacement flag is needed for this layer. Stop for any
database, task definition, service, VPC, ALB, or existing WAF rule change.
Do not apply until the plan has been reviewed.

## Evidence and verification

1. Apply completion; confirm SNS subscription by email before expecting notifications.
2. WAF logging configuration and redaction; make a benign HTTPS request and locate
   its delivered record. A configured log destination alone does not prove delivery.
3. Flow Logs ACTIVE/delivery status and an actual log object under flowlogs/ in S3.
4. CloudTrail IsLogging, LatestDeliveryTime/errors, and actual cloudtrail/ objects.
5. Inspect real AWS/WAFV2 metric dimensions and compare with the alarm before
   claiming correct evaluation. Alarm threshold is Sum >= 1 over one minute;
   missing data is notBreaching. Sparse metrics may initially have no blocked series.
6. Confirm SNS subscription and test notification plumbing separately from detection.
   Any manual alarm-state test must be labeled simulated; it does not prove WAF
   detection or automatic metric-based alarm triggering. Never claim a measured
   blocking result without matching observed evidence.
7. Confirm normal HTTPS access and application/service health remain unchanged.

Save sanitized evidence in evidence/05-logging/. Log delivery is asynchronous;
record time windows and exact permission errors rather than guessing or broadening
policies. The SNS subscription confirmation may require a second Terraform refresh
before the confirmed ARN appears in state.

## Teardown

Export the required report evidence first. Review and run destroy from Layer 5
with the same private variable inputs. Terraform deletes the WAF log group but
leaves the existing S3 bucket and log objects. After evidence export, explicitly
empty/delete ONLY that lab bucket and verify cleanup. Unset both TF_VAR variables,
then End Lab. The database secret retains its existing 7-day recovery window.

