# Layer 4 evidence checklist

- [ ] Reviewed plan with expected ECS service and task definition replacements only.
- [ ] Successful apply summary.
- [ ] Secret metadata and restricted resource policy (never secret value).
- [ ] Current task definition has DB_USER/DB_PASSWORD secret references, no plaintext entries.
- [ ] New task running and target healthy.
- [ ] HTTPS availability and database-dependent application check.

No Layer 4 deployment or secret-retrieval permission has been verified yet.
Protect state, saved plans, credentials, cookies, and runtime environment values.
