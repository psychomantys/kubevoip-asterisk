FROM debian:bookworm-slim AS builder
ARG ASTERISK_VERSION=22.10.0
ARG ASTERISK_SHA256=27e49d483efb0739faf7d0a17a9e55f88439347ed9668f24eea909440473c32e
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential ca-certificates curl libedit-dev libjansson-dev libsqlite3-dev \
    libpq-dev libssl-dev libxml2-dev libxslt1-dev pkg-config unixodbc-dev uuid-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN curl -fsSLO "https://downloads.asterisk.org/pub/telephony/asterisk/releases/asterisk-${ASTERISK_VERSION}.tar.gz" \
 && echo "${ASTERISK_SHA256}  asterisk-${ASTERISK_VERSION}.tar.gz" | sha256sum -c - \
 && tar -xzf "asterisk-${ASTERISK_VERSION}.tar.gz"
WORKDIR /src/asterisk-${ASTERISK_VERSION}
RUN ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --with-pjproject-bundled \
 && make menuselect.makeopts \
 && menuselect/menuselect --disable-all \
    --enable CORE-SOUNDS-EN-ALAW \
    --enable CORE-SOUNDS-EN-ULAW \
    --enable app_audiosocket --enable app_dial --enable app_echo --enable app_playback --enable app_voicemail_odbc \
    --enable chan_audiosocket --enable chan_pjsip --enable codec_alaw --enable codec_ulaw --enable format_pcm --enable format_wav \
    --enable pbx_config --enable res_pjproject --enable res_pjsip --enable res_pjsip_authenticator_digest \
    --enable res_pjsip_endpoint_identifier_ip --enable res_pjsip_endpoint_identifier_user --enable res_pjsip_header_funcs --enable res_pjsip_mwi --enable res_pjsip_outbound_publish \
    --enable res_pjsip_pubsub --enable res_pjsip_registrar --enable res_pjsip_sdp_rtp --enable res_adsi --enable res_config_odbc --enable res_odbc --enable res_rtp_asterisk --enable res_smdi \
    --enable res_audiosocket --enable res_geolocation --enable res_statsd menuselect.makeopts \
 && make -j"$(nproc)" && make DESTDIR=/out install

FROM debian:bookworm-slim
LABEL org.opencontainers.image.source="https://github.com/kubevoip/kubevoip-asterisk" \
      org.opencontainers.image.title="KubeVoIP Asterisk" \
      org.opencontainers.image.description="Asterisk runtime image for KubeVoIP" \
      org.opencontainers.image.licenses="MIT"
RUN apt-get update && apt-get install -y --no-install-recommends \
    libedit2 libjansson4 libpq5 libsqlite3-0 libssl3 libxml2 libxslt1.1 libuuid1 odbc-postgresql \
    python3-minimal python3-psycopg tini unixodbc \
 && rm -rf /var/lib/apt/lists/* \
 && groupadd --gid 1000 asterisk && useradd --uid 1000 --gid 1000 --home-dir /var/lib/asterisk asterisk
COPY --from=builder /out/usr/ /usr/
COPY --from=builder /out/var/lib/asterisk/ /var/lib/asterisk/
COPY kubevoip-mwi-publish /usr/local/bin/kubevoip-mwi-publish
COPY *.conf /etc/asterisk/
RUN mkdir -p /var/lib/asterisk /var/log/asterisk /var/run/asterisk /var/spool/asterisk \
 && chmod 0755 /usr/local/bin/kubevoip-mwi-publish \
 && chown -R asterisk:asterisk /etc/asterisk /var/lib/asterisk /var/log/asterisk /var/run/asterisk /var/spool/asterisk
USER 1000:1000
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["asterisk", "-f"]
