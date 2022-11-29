#!/bin/bash

cat <<EOT > /etc/systemd/journald.conf
[Journal]
RateLimitInterval=30s
RateLimitBurst=20000
EOT

cat <<EOT > /etc/rsyslog.d/rate-limit.conf
$imjournalRatelimitInterval 30
$imjournalRatelimitBurst 20000
EOT
