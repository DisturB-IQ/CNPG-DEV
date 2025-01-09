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

# Install build dependencies for timestamp9
RUN apt-get update && apt-get install -y \
    build-essential \
    autoconf \
    libtool \
    pkg-config \
    libpq-dev \
    git \
    postgresql-server-dev-17

# Clone/build timestamp9
WORKDIR /tmp/timestamp9
RUN git clone https://github.com/optiver/timestamp9.git .
WORKDIR /tmp/timestamp9
RUN make USE_PGXS=1

# Copy built library
RUN cp -v /tmp/timestamp9/build/lib/timestamp9.so /usr/lib/postgresql/17/lib/

# Final stage TimescaleDB extensions from builder to final image.
FROM --platform=linux/amd64 ghcr.io/cloudnative-pg/postgresql:17

USER root

RUN apt-get update \
    && rm -rf /tmp/* \
    && rm -rf /var/lib/apt/lists \
    && rm -rf /var/cache/apt/archives

COPY --from=builder /usr/lib/postgresql/17/lib/timescaledb* /usr/lib/postgresql/17/lib/
COPY --from=builder /usr/share/postgresql/17/extension/timescaledb* /usr/share/postgresql/17/extension/
COPY --from=builder /usr/lib/postgresql/17/lib/timestamp9.so /usr/lib/postgresql/17/lib/

USER 26
