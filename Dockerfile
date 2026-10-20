FROM alpine:3.22 AS build
ARG VERSION=1.26.1

# Inspiration from https://github.com/gmr/alpine-pgbouncer/blob/master/Dockerfile
# hadolint ignore=DL3003,DL3018
RUN apk add --no-cache autoconf automake curl gcc libc-dev libevent-dev libtool make openssl-dev pkgconfig

# build version for release
RUN curl -sS -o /pgbouncer.tar.gz -L https://pgbouncer.github.io/downloads/files/$VERSION/pgbouncer-$VERSION.tar.gz && \
  tar -xzf /pgbouncer.tar.gz && mv /pgbouncer-$VERSION /pgbouncer

RUN cd /pgbouncer && ./configure --prefix=/usr && make -j$(nproc) pgbouncer && strip pgbouncer

FROM alpine:3.22

RUN apk add --no-cache libevent postgresql-client neovim nano && \
  mkdir -p /etc/pgbouncer /var/log/pgbouncer /var/run/pgbouncer && \
  touch /etc/pgbouncer/userlist.txt && \
  chown -R postgres /var/log/pgbouncer /var/run/pgbouncer /etc/pgbouncer

COPY entrypoint.sh /entrypoint.sh
COPY --from=build /pgbouncer/pgbouncer /usr/bin
COPY --from=build /pgbouncer/etc/pgbouncer.ini /etc/pgbouncer/pgbouncer.ini.example
COPY --from=build /pgbouncer/etc/userlist.txt /etc/pgbouncer/userlist.txt.example

COPY pgbouncer.ini /etc/pgbouncer/pgbouncer.ini
COPY userlist.txt /etc/pgbouncer/userlist.txt
RUN chown -c postgres /etc/pgbouncer/pgbouncer.ini
RUN chown -c postgres /etc/pgbouncer/userlist.txt

# Render SSH (https://render.com/docs/ssh#docker-specific-configuration):
# the running user needs a shell, a ~/.ssh dir with 0700, and an unlocked account.
# Use "*" (no password, not locked) instead of `passwd -u`, which would leave the password empty.
# Don't mount a persistent disk on /var/lib/postgresql, Render doesn't support a disk on the user's home.
RUN install -d -m 0700 -o postgres -g postgres /var/lib/postgresql/.ssh && \
  chown postgres:postgres /var/lib/postgresql && \
  sed -i 's/^postgres:![^:]*:/postgres:*:/' /etc/shadow
EXPOSE 5432
USER postgres
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/pgbouncer", "/etc/pgbouncer/pgbouncer.ini"]
