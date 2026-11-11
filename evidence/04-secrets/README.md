# Layer 4 evidence checklist

- [ ] Reviewed plan with expected ECS service and task definition replacements only.
- [ ] Successful apply summary.
- [ ] Secret metadata and restricted resource policy (never secret value).
- [ ] Current task definition has DB_USER/DB_PASSWORD secret references, no plaintext entries.
- [ ] New task running and target healthy.
- [ ] HTTPS availability and database-dependent application check.

No Layer 4 deployment or secret-retrieval permission has been verified yet.
Protect state, saved plans, credentials, cookies, and runtime environment values.

- 01-plan-unexpected-db-update.png records initial plan with unexpected database update (5 add, 1 change, 2 destroy). Not approved for apply; review database diff without exposing credentials.

- 02-db-password-diff.png identifies planned password update. Resolve private input mismatch and re-plan before applying; do not hide the change with ignore_changes.

- 03-reviewed-plan.png confirms expected 5 additions, 0 changes, 2 destructions after correcting private input. Database no longer changes. Apply pending.

- 04-apply-complete.png records successful apply (5 added, 0 changed, 2 destroyed). Runtime health and secret-reference checks pending.

- 06-service-steady-state.png verifies ACTIVE service, one running task, no pending tasks or API failures, revision 2, completed deployment/steady state. Credential references and DB-dependent application verification pending.

- 08-secret-reference-check.png verifies sanitized state check Passed=true for revision 2, no plaintext credential entries, exact expected secret references. Database-dependent application verification remains pending.

- 09-dvwa-home-https.png captures application home access over HTTPS with expected self-signed trust warning. Fresh database-backed login confirmation remains pending; an existing session alone does not prove DB authentication.

- User confirmed the home screenshot followed a fresh successful login. Database-dependent functional check is now user-confirmed. Remaining checklist captures: secret metadata/restricted policy and explicit target health.

- Secret metadata captured in 10-secrets-manager-list.png and 11-secret-metadata.png, including aws/secretsmanager encryption key. Value remains hidden. Resource policy and explicit ALB target health evidence still pending.

- 13-resource-policy-readback.png verifies the intended LabRole GetSecretValue grant on this secret. Other policies may grant access too; this Allow statement is not exclusive access control. Remaining: explicit ALB target-health capture.

## Current completion status
All Layer 4 checklist categories above now have evidence. 14-target-healthy.png shows one healthy target, zero unhealthy. Backend remains HTTP:80. Fresh login is user-confirmed; credential-reference check uses local state and matches ECS service revision 2. Earlier pending notes are historical. State backups/old task revisions may retain plaintext credentials; runtime variables remain accessible to privileged application code.
