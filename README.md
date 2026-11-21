# TLS demo: from JKS keystore to PEM

A minimal Spring Boot (WebFlux / Reactor Netty, the same embedded server as
Spring Cloud Gateway) application that shows a server moving its TLS identity
from a JKS keystore to a PEM file, in three steps.

It uses two different test identities, one packaged as a JKS and one as a
single combined PEM file. Because their certificates differ, the fingerprint
the server presents tells you which one is in use.

## Scenarios

| Scenario | Jar contains keystore lines? | External config | Expected result |
| --- | --- | --- | --- |
| `1-jks` | yes | keystore path and password | JKS identity served, 2 certificates sent |
| `1b-jks-wrong-password` | yes | as 1, wrong password | startup fails (negative control) |
| `2-pem-over-jks` | yes | as 1, plus a PEM SSL bundle | PEM identity served, 1 certificate sent |
| `2b-pem-over-jks-dummy-password` | yes | as 2, wrong keystore password | PEM identity served; the JKS is not opened |
| `3-pem-only` | no | PEM SSL bundle only | PEM identity served, 1 certificate sent |

- **Scenario 1** is the starting point: `server.ssl.key-store=${user.keystore}`
  is baked into the jar and resolved from the external properties file.
- **Scenario 2** is the migration step that needs no new build: the external
  file adds `spring.ssl.bundle.pem.*` and `server.ssl.bundle`, and the bundle
  replaces the keystore even though the jar still contains the keystore lines.
- **Scenario 3** is the target state: the keystore lines are gone from the jar
  and only the PEM bundle is configured.

Scenarios 1b and 2b belong together. 1b shows that a wrong keystore password
is fatal when the JKS is in use; 2b uses the same wrong password and still
starts, which shows the JKS is not opened once the bundle is configured.

## How the "jar with keystore lines" is modelled

- `src/main/resources/application.properties` has no TLS identity settings.
  This is the jar after cleanup.
- `src/main/resources/application-legacy.properties` holds the two keystore
  lines. Activating the `legacy` profile reproduces the jar as it is today.
  `scripts/run.sh` activates it for scenarios 1x and 2x only.
- Each scenario's external file lives in `scenarios/<scenario>/` and is loaded
  with `--spring.config.additional-location`, so it can add or override
  properties but cannot remove the ones in the jar.

## Run it

Requirements: JDK 17+, Maven, `openssl`, `keytool`, `curl`, `bash`.

```bash
scripts/gen-certs.sh      # creates ./certs (demo CA, JKS identity, PEM identity)
scripts/demo-all.sh       # builds, runs every scenario, prints a summary table
```

Or one scenario at a time:

```bash
scripts/run.sh 2-pem-over-jks     # terminal 1
scripts/verify.sh                 # terminal 2
```

`verify.sh` prints the subject, expiry and SHA-256 fingerprint of the served
certificate, how many certificates the server sent, the result of a client
trust check against the demo CA, and which identity is in use.

To see TLS connection details with `curl`, trust the generated demo CA:

```bash
curl -v --cacert ./certs/ca/ca.crt https://localhost:8443/
```

The `-v` option prints connection and TLS details; `--cacert` lets `curl`
verify the server certificate using the demo CA.

Expected summary from `demo-all.sh`:

```text
Scenario                           | Expected       | Observed       | Match
1-jks                              | JKS identity   | JKS identity   | OK
1b-jks-wrong-password              | startup fails  | startup fails  | OK
2-pem-over-jks                     | PEM identity   | PEM identity   | OK
2b-pem-over-jks-dummy-password     | PEM identity   | PEM identity   | OK
3-pem-only                         | PEM identity   | PEM identity   | OK
```

A row marked `DIFFERENT` means that Spring Boot version behaves differently
from what is described here; check `logs/<scenario>.log`.

## Things to know

- **Set the Spring Boot version** in `pom.xml` to the version of the real
  application. The demo then proves the behaviour for that version.
- **Scenario 2 is a transition, not a target.** The Spring Boot reference
  says `server.ssl.bundle` "can not be combined" with the discrete
  `server.ssl.key-store` options. The bundle taking precedence is observed
  behaviour; scenario 3 is the configuration the documentation supports.
- **With a bundle, `server.ssl.ciphers`, `server.ssl.enabled-protocols` and
  `server.ssl.protocol` are ignored.** Set them under
  `spring.ssl.bundle.pem.<name>.options.*` instead.
- **The PEM identity is leaf-only.** The server sends one certificate, where
  the JKS sent two (leaf + CA). Clients must already trust the issuing CA.
  To send the chain as well, append the CA certificate to the file used for
  `keystore.certificate`.
- **One combined PEM file** (certificate + private key) is used for both the
  `certificate` and `private-key` properties.
- **`certs/` is generated and git-ignored.** The keys are throwaway test keys;
  do not commit them and do not reuse them anywhere.

## Layout

```text
pom.xml
src/main/java/demo/TlsDemoApplication.java
src/main/resources/application.properties          jar config, no TLS identity
src/main/resources/application-legacy.properties   today's jar: keystore lines
scenarios/<scenario>/application.properties           external config per scenario
scripts/gen-certs.sh   scripts/run.sh   scripts/verify.sh   scripts/demo-all.sh
```
