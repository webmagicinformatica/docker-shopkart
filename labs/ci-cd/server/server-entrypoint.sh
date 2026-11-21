#!/bin/sh
# Install the deploy key, start sshd, then hand over to the normal dind entrypoint (dockerd).
set -e
if [ -z "$AUTHORIZED_KEY" ]; then
  echo "Set AUTHORIZED_KEY to your public key (docker run -e AUTHORIZED_KEY=\"\$(cat key.pub)\" ...)" >&2
  exit 1
fi
mkdir -p /home/deploy/.ssh
echo "$AUTHORIZED_KEY" > /home/deploy/.ssh/authorized_keys
chown -R deploy:deploy /home/deploy/.ssh
chmod 700 /home/deploy/.ssh && chmod 600 /home/deploy/.ssh/authorized_keys
ssh-keygen -A >/dev/null
/usr/sbin/sshd
exec dockerd-entrypoint.sh --group docker
