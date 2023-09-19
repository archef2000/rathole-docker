FROM alpine:3.16 as downloader
RUN arch=$(uname -m) \
    && arch="${arch//v6/}" \
    && echo $arch \
    && wget -O rathole.zip https://github.com/rapiz1/rathole/releases/download/v0.4.8/rathole-${arch}-unknown-linux-musl.zip \
    && unzip rathole.zip

FROM alpine:3.16
COPY entrypoint.sh /
COPY --from=downloader /rathole .
RUN apk add bash --no-cache \
    && chmod +x /entrypoint.sh

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
CMD [ "server" ]
