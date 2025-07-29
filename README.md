# sfcli

A dockerized [Seafile CLI client](https://help.seafile.com/syncing_client/linux-cli/), inspired by [flrnnc/docker-seafile-client](https://gitlab.com/flrnnc-oss/docker-seafile-client), with built-in support for syncing multiple libraries and Two-Factor Authentication (2FA).

- Single-script entrypoint: [`entrypoint.sh`](docker/entrypoint.sh).
- Runs the official Seafile CLI in a slim Debian-based container.
- Supports syncing **multiple libraries** via environment variables.
- Built-in [oathtool](https://www.nongnu.org/oath-toolkit/oathtool.1.html) support for 2FA (TOTP-based).
- Option to **enable/disable SSL verification**.
- Configurable upload/download speed limits.

## Current limitations

- Password-protected libraries are **not yet supported**.
- Seafile's 2FA does **not** accept reused TOTP tokens within their valid time window. As a workaround, the script waits for a fresh token before syncing each library. More info: [haiwen/seafile#2939](https://github.com/haiwen/seafile/issues/2939).

## Docker compose example

```yaml
services:
  sfcli:
    container_name: sfcli
    image: luthfiampas/sfcli:latest
    restart: unless-stopped
    volumes:
      - ./seafile:/seafile
      - ./libraries:/libraries
    environment:
      SFCLI_URL: "https://files.domain.com"
      SFCLI_USERNAME: "mail@domain.com"
      SFCLI_PASSWORD: "the_password"
      SFCLI_TOTP: "TOTP_key" # optional, required if 2FA is enabled
      SFCLI_NOSSL: true # optional, defaults to false
      SFCLI_DL: "5242880" # optional, defaults to 5 MB
      SFCLI_UL: "5242880" # optional, defaults to 5 MB
      SFCLI_LIBS_NOTES: "11111111-1111-1111-1111-111111111111"
      SFCLI_LIBS_WORK: "22222222-2222-2222-2222-222222222222"
    networks:
      - sfcli-network

networks:
  sfcli-network:
    name: sfcli-network
```

## Environment variables

### `SFCLI_URL`

The full URL of your Seafile server, e.g. `https://seafile.example.com/`.

### `SFCLI_USERNAME`

The email address or username of the Seafile account.

### `SFCLI_PASSWORD`

The login password for the Seafile account.

### `SFCLI_TOTP`

TOTP secret used for generating 2FA codes. You can extract this during 2FA setup — it's encoded in the QR code shown in Seafile's web UI.

### `SFCLI_LIBS_*`

Use this pattern to define libraries to sync:

- The `*` suffix becomes the **local folder name** (automatically lowercased).
- The value must be the **UUID** of the Seafile library.
- You can define **as many libraries as needed**, using the same naming convention.

```env
SFCLI_LIBS_NOTES=11111111-1111-1111-1111-111111111111
SFCLI_LIBS_WORK=22222222-2222-2222-2222-222222222222
```

The above will sync:

- The library `1111...` to `/libraries/notes`
- The library `2222...` to `/libraries/work`

### `SFCLI_NOSSL`

Set to `true` to skip SSL certificate verification. Defaults to `false`.

### `SFCLI_DL`, `SFCLI_UL`

Maximum download/upload speed per second in bytes. Both values default to 5242880 (5 MB).
