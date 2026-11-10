#!/usr/bin/env bash
# Local test lab: two systemd + SSH Ubuntu 22.04 containers that stand in for the EC2 instances.
#   web  10.0.1.10  ("public subnet")      db  10.0.2.10  ("private subnet")
# Prerequisites (built once, see lab/README.md): image lab/ubuntu-jammy-ec2, /srv/lab/lab-key,
# signed apt mirror in /srv/lab/repo. The Ansible roles run against this lab unchanged.
set -euo pipefail

docker network inspect lab-vpc >/dev/null 2>&1 || \
  docker network create --subnet 10.0.0.0/16 --gateway 10.0.0.1 lab-vpc

for spec in web:10.0.1.10 db:10.0.2.10; do
  name=${spec%%:*}; ip=${spec##*:}
  docker rm -f "lab-$name" >/dev/null 2>&1 || true
  docker run -d --name "lab-$name" --hostname "ip-${ip//./-}" --network lab-vpc --ip "$ip" \
    --privileged --cgroupns=host -v /sys/fs/cgroup:/sys/fs/cgroup:rw --tmpfs /run --tmpfs /run/lock \
    lab/ubuntu-jammy-ec2 >/dev/null

  # Sandbox-only: trust the egress proxy CA, and don't auto-start services from package scripts
  # (standard in Docker images; Ansible starts every service explicitly).
  if [ -d /srv/lab/cas ]; then
    docker exec "lab-$name" mkdir -p /usr/local/share/ca-certificates/lab
    for f in /srv/lab/cas/*.crt; do docker cp -q "$f" "lab-$name:/usr/local/share/ca-certificates/lab/"; done
    docker exec "lab-$name" sh -c 'update-ca-certificates >/dev/null 2>&1;
      mkdir -p /usr/etc; echo cafile=/etc/ssl/certs/ca-certificates.crt > /usr/etc/npmrc;
      printf "[global]\ncert = /etc/ssl/certs/ca-certificates.crt\n" > /etc/pip.conf'
  fi
  docker exec "lab-$name" sh -c 'printf "#!/bin/sh\nexit 101\n" > /usr/sbin/policy-rc.d; chmod +x /usr/sbin/policy-rc.d'
done

# Serve the signed apt mirror (MongoDB 7.0 + Node.js 20 packages) on the "VPC" gateway
pgrep -f "http.server 8080" >/dev/null || \
  (cd /srv/lab/repo && nohup python3 -m http.server 8080 --bind 10.0.0.1 >/srv/lab/http.log 2>&1 &)

ssh-keygen -R 10.0.1.10 >/dev/null 2>&1 || true
ssh-keygen -R 10.0.2.10 >/dev/null 2>&1 || true
sleep 5
echo "Lab ready: web=10.0.1.10 db=10.0.2.10"
