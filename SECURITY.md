# Security policy

## Supported versions

| Version | Supported |
|---|---|
| 1.0.0-rc.1 (latest package in the apt repository) | yes |
| older builds | no, upgrade with `apt update && apt install scalws` |

## Reporting a vulnerability

Please do not open a public issue for a security problem. Report it privately, in either
of two ways:

* the form at [scalws.com/security/report](https://scalws.com/security/report/), no
  account needed;
* GitHub: [Report a vulnerability](https://github.com/xsmtx/scalws/security/advisories/new).

Include the ScalWS version (`scalwsd --version`), the relevant part of the configuration,
and the steps or request that trigger the problem. You will get an answer within a few
days; fixes are released as a new package in the apt repository and listed on
[releases.scalws.com](https://releases.scalws.com/).

## Scope

The threat model, with what ScalWS defends against and what it leaves to the operator, is
in [the threat model](https://scalws.com/docs/threat-model/). Experimental features (HTTP/3, eBPF
accounting, the local AI advisor) are opt-in and covered by the same policy.
