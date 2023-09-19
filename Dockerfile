FROM alpine:3.16 as downloader
ARG VERSION=v0.4.8
RUN base_url=https://github.com/rapiz1/rathole/releases/download/${VERSION}/ \
    && file=$(case "$(uname -m)" in "x86_64") echo "rathole-x86_64-unknown-linux-musl.zip";; "aarch64") echo "rathole-aarch64-unknown-linux-musl.zip";; "armv7l") echo "rathole-armv7-unknown-linux-musleabihf.zip";; "arm") echo "rathole-arm-unknown-linux-musleabihf.zip";; *);; esac) \
    && wget -O rathole.zip ${base_url}${file} \
    && unzip rathole.zip

FROM alpine:3.16
COPY entrypoint.sh /
COPY --from=downloader /rathole .
RUN apk add bash --no-cache \
    && chmod +x /entrypoint.sh

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
CMD [ "server" ]
