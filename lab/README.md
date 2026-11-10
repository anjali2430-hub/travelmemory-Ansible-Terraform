# Local test lab

The Ansible playbooks were tested end to end against two Docker containers that stand in for the EC2 instances. This lets you check playbook changes without paying for AWS.

| "Instance" | IP | Like on AWS |
|---|---|---|
| `lab-web` | 10.0.1.10 | public-subnet web server, SSH bastion |
| `lab-db`  | 10.0.2.10 | private-subnet DB server, reached only via ProxyJump |

Each container runs **Ubuntu 22.04 (jammy) with systemd and OpenSSH**, has an `ubuntu` user with passwordless sudo, and accepts only the lab SSH key. This matches the Canonical AMI.

## What is different from AWS (lab-only overrides)

`lab/inventory/group_vars/all.yml` overrides **only package sources and IPv6**. The roles and tasks are unchanged.

- The build sandbox could not reach `repo.mongodb.org` or `deb.nodesource.com`. The same software (MongoDB 7.0.34, Node.js 20.20 + npm 10) was packaged as `mongodb-org` and `nodejs` `.deb` files in a **GPG-signed** local apt repo. The roles add that repo exactly the way they add the official ones.
- The sandbox kernel has no IPv6, so `nginx_listen_ipv6: false`.
- `start-lab.sh` also trusts the sandbox's HTTPS proxy CA and installs Docker's usual `policy-rc.d`, so package scripts don't start services; Ansible starts them explicitly.

## Run

```bash
./lab/start-lab.sh
cd ansible
ansible-playbook -i ../lab/inventory/hosts.ini site.yml --ask-vault-pass
```

You need a `group_vars/all/vault.yml` (see `vault.yml.example`). Building the base image (`debootstrap jammy` → `docker import`) and the signed mirror are one-off steps, described in the comments of `start-lab.sh`.
