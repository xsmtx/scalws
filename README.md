<p align="center">
  <a href="https://scalws.com">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="docs/assets/scalws-logo-dark.svg">
      <img src="docs/assets/scalws-logo-light.svg" alt="ScalWS" width="420">
    </picture>
  </a>
</p>

<h3 align="center">The adaptive web server.</h3>

<p align="center">
  <a href="https://scalws.com/docs/">Documentation</a> ·
  <a href="https://github.com/xsmtx/scalws/releases">Downloads</a> ·
  <a href="https://releases.scalws.com/">Release notes and checksums</a> ·
  <a href="SECURITY.md">Security</a> ·
  <a href="LICENSE">License: Apache-2.0</a>
</p>

# ScalWS

A Linux web and application server written in Rust. It serves static sites, runs PHP
through PHP-FPM, puts Node.js and Python applications and any HTTP upstream behind a
reverse proxy with load balancing, hosts several tenants with cgroup v2 limits, and runs
in Kubernetes as an Ingress controller or a Gateway API implementation. Its **Adaptive
Runtime** adds web-tier capacity only when the web tier is the bottleneck.

This repository holds the released packages and the installer. Documentation is at
[scalws.com/docs](https://scalws.com/docs/).

> **Status: 1.0.0-rc.1, release candidate.** Ubuntu 24.04+ and Debian 13+, amd64.
> Feedback and bug reports are welcome in the [issues](https://github.com/xsmtx/scalws/issues).

## Install

One command, as root:

```sh
curl -fsSL https://raw.githubusercontent.com/xsmtx/scalws/main/install.sh | sudo sh
```

The [installer](install.sh) adds the signed ScalWS apt repository and installs the
`scalws` package. The same by hand, as root (`sudo -i`); like the installer, it checks
that the downloaded key file holds exactly the pinned key and installs only that key:

```sh
FPR=0B49CE4488DC3A3E4F631218CBBBF99C69B99EF0
apt-get install -y curl gnupg
key=$(mktemp)
curl -fsSL https://apt.scalws.com/scalws-archive-keyring.gpg -o "$key"
# The file must hold exactly one primary key, the pinned one: stop if this says WRONG.
test "$(gpg --show-keys --with-colons "$key" \
    | awk -F: '$1=="pub"{p=1;next} p&&$1=="fpr"{print $10;p=0}')" = "$FPR" \
    && echo "repository key OK" || echo "WRONG repository key: stop here"
# Install only that key, re-exported from a scratch keyring (never the downloaded file).
export GNUPGHOME=$(mktemp -d)
gpg --quiet --import "$key"
gpg --export "$FPR" > /usr/share/keyrings/scalws-archive-keyring.gpg
rm -rf "$GNUPGHOME" "$key"; unset GNUPGHOME
echo 'deb [signed-by=/usr/share/keyrings/scalws-archive-keyring.gpg] https://apt.scalws.com stable main' \
    > /etc/apt/sources.list.d/scalws.list
apt update && apt install scalws
```

Repository signing key: `0B49 CE44 88DC 3A3E 4F63  1218 CBBB F99C 69B9 9EF0`.

The server starts right away on ports 80 and 443; `http://<server address>/` shows its
welcome page. If another web server (nginx, Apache) holds those ports, the installation
says so and leaves ScalWS stopped; see
[moving from nginx or Apache](https://scalws.com/docs/sites/#moving-from-nginx-or-apache-scalwsctl-migrate).

On a server with cPanel or DirectAdmin the first install lets ScalWS take over the panel's
web server and serve its sites (undo: `sudo scalwsctl panel disable`). If the switch fails,
everything is undone, the package stays installed and the panel's web server keeps serving.
To leave the panel's web server alone, install with `--panel=none`:

```sh
curl -fsSL https://raw.githubusercontent.com/xsmtx/scalws/main/install.sh | sudo sh -s -- --panel=none
```

See [control panels](https://scalws.com/docs/guide/control-panels/).

## Publish a site

1. Point the domain's DNS records at the server (`A`, and `AAAA` if it has IPv6).
2. Add the site:

   ```sh
   sudo scalwsctl site add example.com
   ```

3. Put the files into `/srv/www/example.com`. HTTPS is set up automatically with a Let's
   Encrypt certificate, and `www.example.com` redirects to `example.com`.

Other kinds of sites:

```sh
sudo scalwsctl site add blog.example.com --php-fastcgi unix:/run/php/php8.3-fpm.sock
sudo scalwsctl site add app.example.com --proxy http://127.0.0.1:3000
sudo scalwsctl site add old.example.com --redirect https://example.com
sudo scalwsctl site list
sudo scalwsctl site remove old.example.com
```

If the ufw firewall is active, open the web ports with `sudo ufw allow 'ScalWS'`; on a
cloud server, also in the provider's firewall. More in the
[installation guide](https://scalws.com/docs/guide/installation/) and
[site files](https://scalws.com/docs/sites/).

## Upgrade

```sh
sudo apt update && sudo apt upgrade
```

Running sites keep serving during the upgrade. Every build, with its release notes and
checksums, is listed on [releases.scalws.com](https://releases.scalws.com/).

## Downloads

Each [GitHub release](https://github.com/xsmtx/scalws/releases) carries the `.deb` package
and its `SHA256SUMS`. It is the same file as in the apt repository:

```sh
sha256sum -c SHA256SUMS
sudo apt install ./scalws_*_amd64.deb
```

A package installed from a file does not update itself; add the apt repository for that.

## What it does

* **Protocols:** HTTP/1.1, HTTP/2, TLS 1.2/1.3 with SNI, automatic Let's Encrypt
  certificates. HTTP/3 is experimental.
* **Sites:** one short file per domain (`scalwsctl site add`), migration from nginx and
  Apache (`scalwsctl migrate`), `.htaccess` support with a safe subset.
* **Applications:** static files, PHP through PHP-FPM, reverse proxy with WebSockets,
  load-balanced upstream pools, redirects, rewrites, header rules, CORS, basic
  authentication, response cache.
* **Adaptive Runtime:** `scalws-controller` runs several server instances on shared
  sockets and adds capacity only when the web tier is the bottleneck. It is never on the
  request path; zero-downtime reloads and upgrades.
* **Multi-tenant:** cgroup v2 CPU, memory and I/O limits per tenant, per-tenant quotas
  and accounting.
* **Operations:** the ScalWS Console (web administration on port 8090), `scalwsctl`,
  Prometheus metrics, JSON access logs, diagnostics.
* **Kubernetes:** Ingress controller and Gateway API
  ([guide](https://scalws.com/docs/guide/ingress-controller/)).

Benchmarks against nginx and LiteSpeed, losses included:
[scalws.com/benchmarks](https://scalws.com/benchmarks/).

## Security

Please report security problems privately:
[scalws.com/security/report](https://scalws.com/security/report/) or
[GitHub private reporting](https://github.com/xsmtx/scalws/security/advisories/new). See
[SECURITY.md](SECURITY.md).

## License

[Apache License, Version 2.0](LICENSE).
