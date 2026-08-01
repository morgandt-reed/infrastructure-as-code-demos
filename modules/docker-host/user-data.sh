#!/bin/bash
# Bootstrap for the Docker host. Rendered by templatefile() from main.tf.
#
# -e so any failed step aborts the boot script instead of leaving a half-built
# host; -u to catch unset variables; -o pipefail so a failure inside a pipe is
# not masked by the exit status of the last command.
set -euo pipefail

exec > >(tee -a /var/log/user-data.log) 2>&1

echo "user-data starting at $(date -Is)"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

# Docker Engine. This also installs the Compose v2 plugin (`docker compose`).
curl -fsSL --retry 3 https://get.docker.com -o /tmp/get-docker.sh
sh /tmp/get-docker.sh
rm -f /tmp/get-docker.sh

# Standalone `docker-compose` shim for tooling that still shells out to the v1
# command name. The release assets are lowercase (docker-compose-linux-x86_64),
# so `uname -s` (which prints "Linux") has to be downcased or the URL 404s.
# -f makes curl exit non-zero on an HTTP error instead of writing the error
# page to disk and then chmod +x'ing it.
COMPOSE_OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
COMPOSE_ARCH="$(uname -m)"
curl -fsSL --retry 3 \
  "https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-$${COMPOSE_OS}-$${COMPOSE_ARCH}" \
  -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
/usr/local/bin/docker-compose version

usermod -aG docker ubuntu

systemctl enable docker
systemctl start docker

%{ if install_cloudwatch_agent ~}
# CloudWatch agent. The instance profile attached in main.tf carries
# CloudWatchAgentServerPolicy, without which the agent starts and publishes
# nothing.
curl -fsSL --retry 3 \
  https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb \
  -o /tmp/amazon-cloudwatch-agent.deb
dpkg -i -E /tmp/amazon-cloudwatch-agent.deb
rm -f /tmp/amazon-cloudwatch-agent.deb
%{ endif ~}

mkdir -p /home/ubuntu/docker
chown ubuntu:ubuntu /home/ubuntu/docker

echo "user-data finished at $(date -Is)"
