# Secure Deployment of a Vulnerable Web Application on AWS

Cloud Security project - Chaima Chhiba and Maha Arfaoui (SSIRE 5).
DVWA on ECS Fargate, hardened one layer at a time. The same `attacks.sh` is re-run after each layer.

## Layout

```
setup-env.sh        installs the tools (Ubuntu/Debian/Kali/WSL)
lab-preflight.sh    checks what the Learner Lab allows, saves evidence
terraform/
  baseline/         vulnerable stage
  layer1/ ... layer5/   each layer adds one control on top of the previous one
evidence/           screenshots, captures, outputs - one folder per stage
report/             final report and diagrams
docker/             DVWA image build context
```

## Session routine (Learner Lab)

1. Start Lab, then AWS Details -> Show, and paste the credentials into `~/.aws/credentials`
   (all three values: key id, secret, **session token**). They change every session.
2. `bash lab-preflight.sh`
3. Work on the current layer.
4. **Before you stop: `terraform destroy`.** ALB, NAT gateway, RDS and WAF bill by the hour.
5. Commit the Terraform and evidence to git.

## Tools

aws cli v2, terraform, docker, trivy, sqlmap, tshark/Wireshark, mysql client, OWASP ZAP (docker image).

## Rules

- All attacks target our own environment only. No DoS or flooding (Learner Lab rules and the AWS penetration testing policy).
- DVWA security level stays on **Low** in every stage.
- Never commit credentials, `.tfstate`, or the session cookie.
