> [!CAUTION]
> Do not use this feature as a main mail server without a redundancy system and proper knowledge.

> [!WARNING]
> Stalwart and Nextcloud community containers are solutions under development.
>
> The mail server is one of the most difficult services to deploy. 
> This solution is quite stable (used for my own cloud) but it is not enterprise quality.
>
> If you have any suggestions, questions, or want to report a
> bug, [open an issue](https://github.com/winterrific/aio-stalwart/issues)!

# Stalwart Community Container for Nextcloud All-In-One

This container is used in [Nextcloud All-In-One](https://github.com/nextcloud/all-in-one/tree/main/community-containers/stalwart) to provide a mail server. It works with the [Caddy community container](https://github.com/nextcloud/all-in-one/tree/main/community-containers/caddy) as a reverse proxy.

## Features

Compared to a default Stalwart container, this container allows:
- Automatic configuration of a mail server.
- Compatibility with Nextcloud All-In-One backups.
- Work with ClamAV from the All-In-One.
- Automatic migration of the data from Stalwart v0.16.x to v1.x when upgrading (using the bundled `stalwart-migrate`
  tool). See [Upgrading](#upgrading).

## Getting Started

### Prerequisites

1. A server with a static IP address.
2. Ensure that ports `25`, `465`, `993`, `4190`, and `10003` are not used by another program. (Use `sudo netstat -tulpn` to list all used ports).
3. Deploy the [Caddy community container](https://github.com/nextcloud/all-in-one/tree/main/community-containers/caddy) as a reverse proxy. (Other solutions are possible, see: [Use Your Own Reverse Proxy](#use-your-own-reverse-proxy)).

### Installation

See [how to use community containers](https://github.com/nextcloud/all-in-one/tree/main/community-containers#how-to-use-this).

After installation on Nextcloud, go to `https://mail.$NC_DOMAIN/login` and log in with the following credentials:
- **Username**: `admin`
- **Password**: Get password inside the AIO interface
  This is the password for the fallback admin used for configuring the mail server through the JMAP interface. Login
  with this account is just possible after the first start or when enabled explicitly. **You should create an admin
  user for daily use after the first start. And deactivate the fallback admin with
  `sudo docker exec nextcloud-aio-stalwart sed -i 's/RECOVERY_ADMIN="ON"/RECOVERY_ADMIN="OFF"/g' /opt/stalwart-mail/etc/aio-config.env`
  and restart the container**

Once connected, add another domain, configure your DNS zone and create your users.

Additionally, you might want to install and configure [Snappymail](https://apps.nextcloud.com/apps/snappymail) or [Mail](https://apps.nextcloud.com/apps/mail) inside Nextcloud to use your mail accounts for sending and retrieving emails.

### Export Data To Another Instance

If you want to change Stalwart server, you can export your data by following command:

```shell
# Stop stalwart container
docker stop nextcloud-aio-stalwart

# Export the data
# The server must be stopped, because the RocksDB data store must be at rest.
docker run --rm -it -v nextcloud_aio_stalwart:/opt/stalwart-mail -v "$LOCATION:/export" --entrypoint /usr/local/bin/stalwart nextcloud_aio_stalwart --config /opt/stalwart-mail/etc/config.json --export /export
```

Now your data is in the `$LOCATION` folder.

> [!NOTE]
> Since Stalwart v1.x the binary is `stalwart` (not `stalwart-mail`) and the data store is configured in `config.json`
(not `config.toml`). An export can only be imported into an empty data store of the same major version (v1.x). See
also [Upgrading section](#upgrading-from-0.16.27-to-v1.x)

### Import From Exported Data

To import your data to a new Stalwart server for the folder `$LOCATION`, use the following command with:

```shell
# Stop stalwart container
docker stop nextcloud-aio-stalwart

# Import the data
docker run --rm -it -v nextcloud_aio_stalwart:/opt/stalwart-mail -v "$LOCATION:/import" --entrypoint /usr/local/bin/stalwart nextcloud_aio_stalwart --config /opt/stalwart-mail/etc/config.json --import /import
```

Now your data is imported, go inside your All-In-One panel and restart your container.

## Common Issues

### WebAdmin Show Errors

Try to update the container in the Nextcloud All-In-One panel.

Since Stalwart v1.x the WebAdmin is served by the server itself and its WebUI bundle is updated together with the
server, so there is no separate WebAdmin to upgrade anymore (the `webadmin.sh` script and the
`/api/update/webadmin` endpoint only existed up to v0.16). If the WebAdmin still shows errors after the update,
restart the container and check the logs (see the console tracer in [Managed Settings](#managed-settings)).

## Advanced Configuration

> [!IMPORTANT]
> This image overrides the configuration of Stalwart on every start.
> You can find the list of all managed settings in the [Managed Settings](#managed-settings) section.
> The managed settings prevent breaking links with Nextcloud and the Caddy community container.

See the [Stalwart FAQ](https://stalw.art/docs/faq) for all possibilities.

For any questions, [open an issue](https://github.com/winterrific/aio-stalwart/issues)!

### Change the Admin Password

Since v0.16 (and still in v1.x) the fallback admin can only be set and changed during container start with environment
variables. On startup the container sets the recovery admin (`STALWART_RECOVERY_ADMIN`) to `admin` with the
`STALWART_USER_PASS` password from the All-In-One and briefly runs Stalwart in recovery mode on port `8080` to apply
the configuration. The fallback admin is on by default and the password can be found in AIO Admin console. However,
you can disable the fallback admin by setting the environment variable `RECOVERY_ADMIN` to `OFF`.
Before you do so you should create a new admin user using the Webinterface. And deactivate the fallback admin with
`sudo docker exec nextcloud-aio-stalwart sed -i 's/RECOVERY_ADMIN="ON"/RECOVERY_ADMIN="OFF"/g' /opt/stalwart-mail/etc/aio-config.env`
and restart the container. See also [Managed Settings](#managed-settings).

### Enable AIO ClamAV

To enable ClamAV, you need to enable the ClamAV inside the All-In-One panel.

Then it will automatically configure the ClamAV in the Stalwart mail server.

### Use a Custom Domain

To configure a custom domain for the mail server, follow these steps:

1. Disable the managed configuration of certificates `AUTO_CONFIG_TLS_CERT`. See [Managed Settings](#managed-settings).
2. Configure your own reverse proxy. See [Use Your Own Reverse Proxy](#use-your-own-reverse-proxy).
3. Add your own certificate. See [Stalwart Certificate](https://stalw.art/docs/server/tls/certificates).

### Use Your Own Reverse Proxy

Redirect HTTP (or HTTPS) traffic from `mail.$NC_DOMAIN` to port `10003` of the `nextcloud-aio-stalwart` container in HTTP.

**Then add your own certificate.** See: [Use Your Own Certificate](#use-your-own-certificate)

Example with `Caddyfile` syntax:
```caddyfile
https://mail.{$NC_DOMAIN}:443 {
    reverse_proxy http://{$STALWART_HOSTNAME}:10003
}
```

### Use Your Own Certificate

Add a certificate in volume `nextcloud_aio_caddy` in this path:
- `$VOLUME_ROOT/caddy/certificates/acme-v02.api.letsencrypt.org-directory/mail.$NC_DOMAIN/mail.$NC_DOMAIN.key`
- `$VOLUME_ROOT/caddy/certificates/acme-v02.api.letsencrypt.org-directory/mail.$NC_DOMAIN/mail.$NC_DOMAIN.crt`

If you're using Caddy, mount the volume `nextcloud_aio_caddy` to your Caddy container and add this [storage global directive](https://caddyserver.com/docs/caddyfile/options#storage):
```caddyfile
{
    storage file_system {$VOLUME_ROOT}/caddy
}
```

**If you're using another domain**, disable the managed configuration of certificates. See [Managed Settings](#managed-settings) and [Stalwart Certificate](https://stalw.art/docs/server/tls/certificates).

> [!HINT]
> If you disable the managed configuration of certificates, consider to use the official [Stalwart Container](https://stalw.art/docs/install/platform/docker/).

## Managed Settings

Disable some automatic override configurations with environment variables in the file `/opt/stalwart-mail/etc/aio-config.env`.

To edit it run:
```shell
docker exec -it nextcloud-aio-stalwart bash -c "nano /opt/stalwart-mail/etc/aio-config.env"
```

| Variable                         | Description                                                                                                                                                                                             | Default | WebAdmin location (v1.x)                                            |
|----------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------|---------------------------------------------------------------------|
| `SECURE_DATA_AFTER_UPGRADE`      | Prevent the server from starting if the data is in an old format.                                                                                                                                       | `ON`    |                                                                     |
| `ENSURE_MAIL_PORT_CONFIG`        | Manage mail exchange port configuration.<br/>This port is used to receive emails.                                                                                                                       | `ON`    | `https://mail.$NC_DOMAIN` → Settings › Network › Listeners          |
| `ENSURE_SUBMISSION_PORT_CONFIG`  | Manage mail submission port configuration.<br/>This port is used to send emails.                                                                                                                        | `ON`    | `https://mail.$NC_DOMAIN` → Settings › Network › Listeners          |
| `ENSURE_IMAP_PORT_CONFIG`        | Manage IMAP port configuration.<br/>This port is used to read emails.                                                                                                                                   | `ON`    | `https://mail.$NC_DOMAIN` → Settings › Network › Listeners          |
| `ENSURE_WEB_PORT_CONFIG`         | Manage web port configuration.<br/>This port is used to access the WebAdmin.                                                                                                                            | `ON`    | `https://mail.$NC_DOMAIN` → Settings › Network › Listeners          |
| `ENSURE_MANAGESIEVE_PORT_CONFIG` | Manage managesieve port configuration.<br/>This port is used to manage filters.                                                                                                                         | `ON`    | `https://mail.$NC_DOMAIN` → Settings › Network › Listeners          |
| `ENSURE_STORAGE_CONFIG`          | Manage storage configuration.                                                                                                                                                                           | `ON`    | `https://mail.$NC_DOMAIN` → Settings › Storage › Data Store         |
| `ENSURE_DIRECTORY_CONFIG`        | Manage directory configuration.<br/>This is the system to manage users.                                                                                                                                 | `ON`    | `https://mail.$NC_DOMAIN` → Settings › Authentication › Directories |
| `ENSURE_FILE_LOGGING_CONFIG`     | Manage file logging configuration.<br/>This provides access to logs from the WebAdmin.                                                                                                                  | `ON`    | `https://mail.$NC_DOMAIN` → Settings › Telemetry › Tracers          |
| `ENSURE_CONSOLE_LOGGING_CONFIG`  | Manage console logging configuration.<br/>This provides access to logs from Docker and the master container interface.                                                                                  | `ON`    | `https://mail.$NC_DOMAIN` → Settings › Telemetry › Tracers          |
| `ENSURE_FALLBACK_ADMIN_CONFIG`   | Manage fallback admin configuration.<br/>This is the admin account to access the WebAdmin.                                                                                                              | `ON`    |                                                                     |
| `ENSURE_AIO_CLAMAV_CONFIG`       | Manage ClamAV configuration.<br/>This is used to scan emails for viruses.                                                                                                                               | `ON`    | `https://mail.$NC_DOMAIN` → Settings › MTA › Filters › Milters      |
| `AUTO_CONFIG_TLS_CERT`           | Manage configuration of TLS certificates from the Caddy community container.<br/>This is used to secure the connection for the mail protocol.                                                           | `ON`    | `https://mail.$NC_DOMAIN` → Settings › TLS › Certificates           |
| `ENSURE_HTTP_USE_X_FORWARDED`    | Enable Stalwart handling of X-Forwarded headers and trusted network (for reverse proxy setups).                                                                                                         | `ON`    |                                                                     |
| `RECOVERY_ADMIN`                 | Enable recovery admin. Default is "ON".<br/>It is highly recommended to configure an Admin User in the Management Interface and put the ENV to "OFF".                                                   | `ON`    |                                                                     |
| `LOG_LEVEL`                      | Manage the log-level for logging of stalwart to file and stdout.                                                                                                                                        | `info`  |                                                                     |
| `ENSURE_DNSSEC_VALIDATE`         | The setup script check on startup, if the local DNS resolver supports DNSSEC validation. If not, Quad9 is configured as DNS resolver for stalwart. This is needed to ensure that DANE Support can work. | `ON`    | `https://mail.$NC_DOMAIN` → Settings › Network › DNS › DNS Resolver |

> [!NOTE]
> The WebAdmin of Stalwart v1.x was redesigned: the settings are no longer reachable under
> `/account/Settings/x:...` URLs as in v0.16, but in the WebUI at `https://mail.$NC_DOMAIN` under the menu paths
> listed above.

## Upgrading

> [!NOTE]
> Unless the starting script tells you, you have no action to do to update.

See the [Stalwart Upgrading Guide](https://stalw.art/docs/install/upgrade/) and, for the migration from v0.16.x to
v1.x, the [Stalwart migration documentation](https://stalw.art/docs/migration/upgrade-0-16/). The legacy guides are
still available in the [UPGRADING folder](https://github.com/stalwartlabs/stalwart/tree/main/UPGRADING) of the
Stalwart repository.

During a major server update when manual intervention is needed, this message will be displayed:

```
Your data is in an old format.
Make a backup and see https://github.com/winterrific/aio-stalwart#Upgrading
To avoid any loss of data, Stalwart will not launch.
```

> [!CAUTION]
> Before each update, remember to make a backup.

### Upgrading from v1.0.x to v1.1.x

Upgrades within v1.x (e.g. from v1.0.x to v1.1.1, which this container currently ships) are in-place: the on-disk
data format did not change, the data version lock stays at `1.0` and no migration is needed. Simply update the
container in the Nextcloud All-In-One panel and restart it.

Note the following changes of the v1.1.x releases (see the
[release notes](https://github.com/stalwartlabs/stalwart/releases)):

- **v1.1.0** added passkeys (WebAuthn) for accounts in the internal directory. Default roles created by an earlier
  version do not include the new `sysPasskey*` permissions. The container sets
  `STALWART_UPDATE_ROLE_PERMISSIONS=true` automatically once after the v0.16 → v1.0 migration, which adds the missing
  permissions on the next start. If you were already on v1.0.x, add the permissions manually using the recovery
  administrator or restart the server once with the environment variable `STALWART_UPDATE_ROLE_PERMISSIONS=true`, then
  remove the variable again.
- **v1.1.1** moved masked email addresses into the open-source edition and changed the Netcup DNS provider to the
  key-only CloudDNS REST API: existing Netcup entries need the CloudDNS API key in the new `apiKey` field after the
  upgrade. Additionally, v1.1.1 contains many MTA, JMAP, IMAP, Sieve, calendar and WebDAV fixes.

### Upgrading from 0.16.27 to v1.x

Stalwart v1.0 changed the on-disk layout of the data store, so a v0.16.x store **cannot be opened in place** by v1.x.
Instead, all data is copied into a new store with the `stalwart-migrate` tool, which is bundled in this container. See
the [official migration documentation](https://stalw.art/docs/migration/upgrade-0-16/) and the
[stalwart-migrate repository](https://github.com/stalwartlabs/stalwart-migrate). The 0.16.27 needs to be ran on the
server
before the upgrade could be performed.

The migration is driven by the data version lock file `/opt/stalwart-mail/aio.lock` and runs automatically on
container start. Recommended procedure:

1. **While still on a v0.16.x-based container, prepare the migration** (run this before updating to a v1.x-based
   container):

   ```shell
   sudo docker exec -it nextcloud-aio-stalwart prepare-migration
   ```

   This creates `/opt/stalwart-mail/etc/migration/answers.toml` and marks the installation as prepared. Review and
   adjust the `answers.toml` if needed. By default all data categories are migrated (settings, principals, mail,
   calendars, contacts, files, sieve, identities, push subscriptions, spam samples, reports, archive, spam model,
   queue, tasks, telemetry), new permissions are granted, the interoperable OAuth client scope is granted,
   `X-Forwarded-For` is trusted (1 hop) and changed defaults follow the `recommended` policy. See
   [Preparing the migration](https://stalw.art/docs/migration/upgrade-0-16/prepare/).
   Keep `SECURE_DATA_AFTER_UPGRADE=ON` and complete preparation successfully before updating; confirm that
   `answers.toml` was written and that `/opt/stalwart-mail/aio.lock` contains `0.18`.
   The automatic fallback only runs when the lock is `0.17` and no answers file exists: it writes the defaults,
   changes the lock to `0.18`, and exits, so another container start is needed to migrate.
   A lock of `0.16` is instead advanced to `1.0` without store migration, and setting
   `SECURE_DATA_AFTER_UPGRADE=OFF` skips migration entirely. Do not rely on the fallback in those cases.

2. **Back up** the `nextcloud_aio_stalwart` volume (or use the All-In-One backup).

3. **Update the container** to a v1.x-based version in the All-In-One panel. Make sure at least **2x the size of the
   old data directory** (`/opt/stalwart-mail/data`) is free on the volume, because the data is copied into a new store
   (`/opt/stalwart-mail/data_1`) next to the old one.

4. On start, the container runs `stalwart-migrate run --final --yes` and verifies the result with
   `stalwart-migrate verify --full`, then starts Stalwart on the new store. Afterwards the data version lock is set
   to `1.0` and the role permissions are updated once on the first start (`STALWART_UPDATE_ROLE_PERMISSIONS=true`).

If verification fails, the container prints the detailed migration errors (`stalwart-migrate report --severity
error`), waits 5 minutes and exits. A restart policy or manual restart is needed to retry. To rerun migration with
`--allow-errors`, create the following file; full verification must still pass before Stalwart can start:

```shell
sudo docker exec nextcloud-aio-stalwart touch /opt/stalwart-mail/etc/migration/force
```

and restart the container. The `force` file is removed automatically after it was used.

After the migration, it is highly recommended to check all settings in the WebAdmin, as v1.x renamed and restructured
many objects and renumbered internal identifiers (see the
[migration docs](https://stalw.art/docs/migration/upgrade-0-16/)). E.g.:

- accounts now require the domain during login,
- app-specific passwords are not migrated automatically,
- catch-all addresses are configured on the domain itself and are not migrated automatically,
- and so on.

### Upgrading from 0.15.x to 0.16.x

v0.16 removed the TOML configuration files: all configuration is stored in the database and can be edited in the
WebAdmin or via the JMAP API only. Check the
[stalwart upgrading guide for v0.16](https://github.com/stalwartlabs/stalwart/blob/main/UPGRADING/v0_16.md) for more
information.

For installations coming from v0.15.x, the settings export has to exist already while still on v0.15: the automatic
export runs periodically with version v0.2 of aio-stalwart and writes `/opt/stalwart-mail/etc/export.json`. On the
first start of a v1.x-based container this export is applied automatically. **If the export is missing, the container
refuses to start, because otherwise the configuration including users, domains, etc. could be lost.**

Newly introduced with the v0.16 switch were the environment variables `LOG_LEVEL` and `RECOVERY_ADMIN` (see
[Managed Settings](#managed-settings)). The recovery admin is used to apply the configuration and can be used to log
in to the management console. However, it's recommended to configure an admin user in the WebAdmin and set the ENV to
"OFF". This account can be secured with 2FA, which is not possible for the recovery admin. See also the
[Installation](#installation) section.

**Trouble-Shooting**

If the periodical export did not take place, roll back to a v0.15-based version of this container (`aio-stalwart:v0`)
first. To manipulate the version of aio-stalwart see
either [here](https://github.com/nextcloud/all-in-one/tree/main/community-containers#how-to-test-new-containers-in-your-own-installation)
or follow these steps:

- log into a console of your server
- call
  `sudo docker exec -it nextcloud-aio-mastercontainer vi /var/www/docker-aio/community-containers/stalwart/stalwart.json`
- enter edit mode (press "i")
- change the `image_tag` to `v0`
- save and exit (esc + ":wq")
- restart mastercontainer `sudo docker restart nextcloud-aio-mastercontainer`
- update the container in the AIO web interface
- call the export script manually `sudo docker exec nextcloud-aio-stalwart export-settings` OR export the settings
  by yourself and copy them into the docker volume (follow the official stalwart migration guide)
- revert the change in `image_tag`, restart the mastercontainer and update the containers in the web interface (the
  v1.x-based aio-stalwart will pick up the `export.json` and apply it on the first start)

### Upgrading from 0.9.x to 0.10.x

> [!NOTE]
> The sections below are historical and only relevant for installations still on very old versions (≤ 0.10.x). They
> intentionally use the old `stalwartlabs/mail-server` images, which are required to read those old data formats.
> Current upgrades go through the sections above.

To upgrade from 0.9.x to 0.10.x, run the following command:

```shell
# Stop stalwart-mail container
docker stop nextcloud-aio-stalwart

# Check the data version is in 0.9 (output should be '0.9')
docker run --rm -v nextcloud_aio_stalwart:/opt/stalwart-mail --entrypoint /bin/cat stalwartlabs/mail-server:v0.9.4 /opt/stalwart-mail/aio.lock

# Enable the new data version
docker run --rm -v nextcloud_aio_stalwart:/opt/stalwart-mail --entrypoint /bin/sed stalwartlabs/mail-server:v0.10.0 -i 's/^0.9$/0.10/g' /opt/stalwart-mail/aio.lock
```

Then, go inside your All-In-One panel and restart your container.

### Upgrading from 0.8.x to 0.9.x

This migration does not require any action, but the organization of the database and autoconfiguration script has changed.

1. Be vigilant about possible the data loss, see [Stalwart 0.9.0](https://github.com/stalwartlabs/stalwart/releases/tag/v0.9.0)
2. Be careful if you have made any settings, the autoconfiguration script might overwrite them, see [Managed Settings](#managed-settings).

To upgrade from 0.8.x to 0.9.x, run the following steps:

```shell
# Stop stalwart-mail container
docker stop nextcloud-aio-stalwart

# Check the data version is in 0.8.0 (output should be '0.8.0')
docker run --rm -v nextcloud_aio_stalwart:/opt/stalwart-mail --entrypoint /bin/cat stalwartlabs/mail-server:v0.8.0 /opt/stalwart-mail/aio.lock

# BACKUP YOUR CONFIGURATION FILE
docker run --rm -v nextcloud_aio_stalwart:/opt/stalwart-mail --entrypoint /bin/cat stalwartlabs/mail-server:v0.9.0 /opt/stalwart-mail/etc/config.toml

# Enable the new data version
docker run --rm -v nextcloud_aio_stalwart:/opt/stalwart-mail --entrypoint /bin/sed stalwartlabs/mail-server:v0.9.0 -i 's/^0.8.0$/0.9/g' /opt/stalwart-mail/aio.lock
```

Then, go inside your All-In-One panel and restart your container.

You can verify your config file with the following command after starting the container:
```shell
docker run --rm -v nextcloud_aio_stalwart:/opt/stalwart-mail --entrypoint /bin/cat stalwartlabs/mail-server:v0.9.0 /opt/stalwart-mail/etc/config.toml
```

### Upgrading from 0.7.x to 0.8.x

To upgrade from 0.7.x to 0.8.x, run the following steps:

```shell
# Stop stalwart-mail container
docker stop nextcloud-aio-stalwart

# Check the data version is in 0.7.0 (output should be '0.7.0')
docker run --rm -v nextcloud_aio_stalwart:/opt/stalwart-mail --entrypoint /bin/cat stalwartlabs/mail-server:v0.7.3 /opt/stalwart-mail/aio.lock

# Export your data
docker run --rm -v nextcloud_aio_stalwart:/opt/stalwart-mail --entrypoint /bin/stalwart-mail stalwartlabs/mail-server:v0.7.3 --config /opt/stalwart-mail/etc/config.toml --export /opt/stalwart-mail/export_7_to_8

# Import your data
docker run --rm -v nextcloud_aio_stalwart:/opt/stalwart-mail --entrypoint /bin/stalwart-mail stalwartlabs/mail-server:v0.8.0 --config /opt/stalwart-mail/etc/config.toml --import /opt/stalwart-mail/export_7_to_8

# Enable the new data version
docker run --rm -v nextcloud_aio_stalwart:/opt/stalwart-mail --entrypoint /bin/sed stalwartlabs/mail-server:v0.8.0 -i 's/^0.7.0$/0.8.0/g' /opt/stalwart-mail/aio.lock
```

Now go inside your All-In-One panel and restart and upgrade yours containers.
