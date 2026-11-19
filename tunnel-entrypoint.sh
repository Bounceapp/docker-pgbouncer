#!/bin/sh
# Exits when either process dies, so Render restarts the instance.
set -eu

# Render secret files; pgbouncer.ini points auth_file at /etc/secrets/userlist.txt.
config=/etc/secrets/pgbouncer.ini
for f in "$config" /etc/secrets/userlist.txt; do
  if [ ! -r "$f" ]; then
    echo "Cannot read $f as $(id -un) ($(id)). Add it as a Render secret file." >&2
    exit 1
  fi
done

pgbouncer "$config" &
pgbouncer_pid=$!

# Reads TUNNEL_TOKEN and TUNNEL_TRANSPORT_PROTOCOL from the environment.
cloudflared tunnel --no-autoupdate run &
cloudflared_pid=$!

trap 'kill -TERM "$cloudflared_pid" "$pgbouncer_pid" 2>/dev/null' TERM INT

while kill -0 "$pgbouncer_pid" 2>/dev/null && kill -0 "$cloudflared_pid" 2>/dev/null; do
  sleep 5
done

kill -TERM "$cloudflared_pid" "$pgbouncer_pid" 2>/dev/null || true
wait
exit 1
