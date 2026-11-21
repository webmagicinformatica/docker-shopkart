# A practice "production server" you can run inside a codespace: its own Docker engine (docker:dind)
# plus an SSH server. You deploy to it over SSH, exactly as you would to a real VM.
FROM docker:29.10.0-dind
RUN apk add --no-cache openssh-server \
 && adduser -D -s /bin/sh deploy \
 && passwd -u deploy \
 && addgroup deploy docker \
 && sed -i -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' \
           -e 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
COPY server-entrypoint.sh /usr/local/bin/
EXPOSE 22 80
ENTRYPOINT ["server-entrypoint.sh"]
