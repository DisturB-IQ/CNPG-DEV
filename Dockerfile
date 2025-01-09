# Builder stage
FROM --platform=linux/amd64 ghcr.io/cloudnative-pg/postgresql:17 as builder

ENV DEBIAN_FRONTEND noninteractive
ENV DEBCONF_NOWARNINGS="yes"

USER root

RUN apt-get update \
    && apt-get install -y apt-transport-https lsb-release wget git \
    postgresql-17 postgresql-server-dev-17 clang libssl-dev libssl1.1 \
    software-properties-common ca-certificates build-essential gnupg curl \
    make gcc clang pkg-config

# Install TimescaleDB Community
RUN echo "deb https://packagecloud.io/timescale/timescaledb/debian/" \
    "$(lsb_release -c -s) main" \
    > /etc/apt/sources.list.d/timescaledb.list \
    && wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | \
    gpg --dearmor >/etc/apt/trusted.gpg.d/timescaledb.gpg \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    timescaledb-tools \
    timescaledb-toolkit-postgresql-17 \
    timescaledb-2-loader-postgresql-17 \
    timescaledb-2-postgresql-17

# Install timestamp9 extension - Corrected
RUN git clone --depth=1 https://github.com/optiver/timestamp9.git \
    && cd timestamp9 \
    && make USE_PGXS=1 \ #Crucial Change
    && make USE_PGXS=1 install

# Final stage - Copy only necessary files
FROM --platform=linux/amd64 ghcr.io/cloudnative-pg/postgresql:17

USER root

RUN apt-get update \
    && rm -rf /tmp/* \
    && rm -rf /var/lib/apt/lists \
    && rm -rf /var/cache/apt/archives

COPY --from=builder /usr/lib/postgresql/17/lib/timescaledb* /usr/lib/postgresql/17/lib/
COPY --from=builder /usr/share/postgresql/17/extension/timescaledb* /usr/share/postgresql/17/extension/
COPY --from=builder /usr/lib/postgresql/17/lib/timestamp9.so /usr/lib/postgresql/17/lib/
COPY --from=builder /usr/share/postgresql/17/extension/timestamp9.control /usr/share/postgresql/17/extension/

USER 26
