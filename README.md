# rathole docker container
Multiarch docker container for [rathole](https://github.com/rapiz1/rathole)
- [Docker Compose](#docker-compose)
- [Environment Variables](#environment-variables)

# docker-compose
```
  rathole-server:
    image: archef2000/rathole:latest
    environment:
      - "RUST_LOG=info"
      - "ADDRESS=0.0.0.0:2333"
      - "SERVICE_TOKEN_1=***token***"
      - "SERVICE_NAME_1=service1"
      - "SERVICE_ADDRESS_1=0.0.0.0:5202"
    ports:
      - 2333:2333
      - 5202:5202
    restart: unless-stopped

  rathole-client:
    image: archef2000/rathole:latest
    command: client
    environment:
      - "RUST_LOG=info"
      - "ADDRESS=server-ip:2333"
      - "SERVICE_TOKEN_1=***token***"
      - "SERVICE_NAME_1=service1"
      - "SERVICE_ADDRESS_1=10.10.10.10:5202"
    restart: unless-stopped
```

# Environment Variables

## General
| Example | Function |
|---------|----------|
| DEFAULT_TOKEN | The default token of services, if they don't define their own ones |
| TRANSPORT_TYPE | Possible values: ["tcp", "tls", "noise"]. Default: "tcp" |
| TCP_NODELAY | Determine whether to enable TCP_NODELAY, if applicable, to improve the latency but decrease the bandwidth. Default: true |
| KEEPALIVE_INTERVAL | Specify `tcp_keepalive_intvl` in `tcp(7)`, if applicable. Default: 8 seconds |
| KEEPALIVE_SECONDS | Specify `tcp_keepalive_time` in `tcp(7)`, if applicable. Default: 20 seconds |

## Server side
| Name | Function |
|---------|----------|
| ADDRESS | The address that the server listens for clients. Generally only the port needs to be change. |
| PKCS12 | pkcs12 file of server's certificate and private key |
| PKCS12_PASSWORD | Password of the pkcs12 file |
| HEARTBEAT_TIMEOUT | Set to 0 to disable the application-layer heartbeat test. The value must be greater than `server.heartbeat_interval`. Default: 30 seconds |
| HEARTBEAT_INTERVAL | The interval between two application-layer heartbeat. Set to 0 to disable sending heartbeat. Default: 30 seconds |


## Client-side
| Name | Function |
|---------|----------|
| RETRY_INTERVAL | The interval between retry to connect to the server. Default: 1 second |
| HEARTBEAT_TIMEOUT | Set to 0 to disable the application-layer heartbeat test. The value must be greater than `server.heartbeat_interval`. Default: 40 seconds |
| ADDRESS | The address of the server |
| TRUSTED_ROOT | The certificate of CA that signed the server's certificate |
| TLS_HOSTNAME | The hostname that the client uses to validate the certificate. If not set, fallback to `client.remote_addr` |
| PROXY_URL | The proxy used to connect to the server. `http` and `socks5` is supported. |

## Services
| Required | Name | Function |
|----------|---------|----------|
| yes | SERVICE_NAME_$N | Identical to the name in the server's configuration |
| no | SERVICE_TYPE_$N | The protocol that needs forwarding. Possible values: ["tcp", "udp"]. Default: "tcp" |
| yes | SERVICE_TOKEN_$N | Necessary if `DEFAULT_TOKEN` not set |
| yes | SERVICE_ADDRESS_$N | client: service location. server: service listening address |
| no | SERVICE_NODELAY_1 | Override the `TCP_NODELAY` per service |
| no | SERVICE_RETRY_1 | The interval between retry to connect to the server. Default: inherits the global config |

## Noise Protocol
[Officail docs](https://github.com/rapiz1/rathole/blob/main/docs/transport.md#noise-protocol)
| Name | Example |
|---------|----------|
| NOISE_PATTERN | Noise_XX_25519_ChaChaPoly_BLAKE2s / Noise_KK_25519_ChaChaPoly_BLAKE2s |
| NOISE_REMOTE_PUBLIC_KEY |  |
| NOISE_LOCAL_PRIVATE_KEY |  |
