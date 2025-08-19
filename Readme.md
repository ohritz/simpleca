# Dockerized: Simple Certificate Authority

This is not meant to be used as a production ready CA for all use cases.
The goal is to provide a simple CA utility to be able to generate ssl certs for client server authentication within a closed system like a kubernetes cluster.

The example use case is a cluster where a api facade needs to communicate with underlying services over tls.

Use the image to setup a root and intermediate CA, and then generate and sign server certificates.
The certificate chain would be placed with the client, to verify the servers.

Inspiration taken from:
- [https://karneliuk.com/2021/02/sec-3-building-your-own-containerised-pki-root-ca-with-linux-and-docker-to-simplify-and-secure-network-automation/]
- [https://jamielinux.com/docs/openssl-certificate-authority]

## Modern quickstart (no -legacy required)

```bash
# Initialize CA (interactive)
simpleca init

# or non-interactive with password file
simpleca init --pass-file /run/secrets/ca.pass

# Issue a server certificate with SANs
auth_sans="DNS:api.local,DNS:api,IP:127.0.0.1"
simpleca issue --cn api.local --sans "$auth_sans" --pass-file /run/secrets/cert.pass

# Artifacts are exported to /opt/export (mount it in Docker usage)
```

Defaults:
- EC P-256 keys, SHA-256, modern PKCS#8/PKCS#12 without legacy provider
- Leaf validity 398 days (configurable via `--days` or `LEAF_DAYS`)

## cert-manager (CA Issuer) export
Export unencrypted intermediate private key and full chain as a Kubernetes `Secret`, and an `Issuer` referencing it.

Security note: this writes an UNENCRYPTED private key to the chosen output directory. Treat it as sensitive.

```bash
# Export manifests for namespace sandbox
simpleca cert-manager export --ns sandbox \
  --issuer-name ca-issuer --secret-name ca-key-pair \
  --out /opt/export/manifests \
  --pass-file /run/secrets/ca.pass

# Optional CRL/OCSP
simpleca cert-manager export --ns sandbox \
  --crl=http://crl.example.com/root.crl \
  --ocsp=http://ocsp.example.com \
  --pass-file /run/secrets/ca.pass

# Apply to cluster
kubectl apply -f /opt/export/manifests/sandbox/ca-issuer/secret.yaml
kubectl apply -f /opt/export/manifests/sandbox/ca-issuer/issuer.yaml
```

Generated files under `/opt/export/manifests/<namespace>/<issuer-name>/`:
- `intermediate.key.unencrypted.pem` (PKCS#8, unencrypted)
- `issuer.fullchain.crt.pem` (intermediate + root)
- `secret.yaml` (kubernetes.io/tls; base64 `tls.crt` and `tls.key`)
- `issuer.yaml` (references the Secret; optional `crlDistributionPoints`/`ocspServers` if provided)

## Environment variables.
The following environment variables needs to be passed in in the init phase, these correspond to values in the certificate Subject.
```
ROOT_ORG=[organizationName]
ROOT_COUNTRY=[countryName]
ROOT_STATE=[stateOrProvinceName]
ROOT_LOCALITY=[localityName]
```
## Volume
It is recommended to run the container with a volume mounted to /opt/ca to persist the certificates.
```bash
docker volume create ca-vol
```
An idea is to use some other volume pluggins to place the certificates in a cloud storage.
see: https://docs.docker.com/engine/extend/legacy_plugins/#volume-plugins

## Build docker image
```bash
docker build . -t osorenan/simpleca
```
### To setup a ca
Create a directory with a .env file with the following filled in.
```
ROOT_ORG=[org name]
ROOT_COUNTRY=[Country code eg. 'SE']
ROOT_STATE=[eg. Goteborg]
ROOT_LOCALITY=[eg. Goteborg]
```

then run:
```bash
docker run \
-it --rm \
--env-file ./.env \
--mount source=ca-vol,target=/opt/ca \
osorenan/simpleca \
--init
```

### To create a server certificate run
```bash
mkdir ${PWD}/certs

docker run \
-it --rm \
--mount source=ca-vol,target=/opt/ca \
--mount type=bind,source=${PWD}/certs,target=/opt/export \
osorenan/simpleca \
[hostname]
```

### To eject the ca to a bind mount
```bash
docker run \
-it --rm \
--mount source=ca-vol,target=/opt/ca \
--mount type=bind,source=${PWD}/ca-backup,target=/opt/export \
osorenan/simpleca \
--eject
```
### To reinitialize from a ejected tarball, run
```bash
docker run \
-it --rm \
--mount source=ca-vol,target=/opt/ca \
--mount type=bind,source=${PWD}/ca-backup,target=/opt/export \
osorenan/simpleca \
--re-init
```

## debug
```bash
./debug
```

## Further ideas to develop.

- A more configurable request process.
    - Be able to add more hostnames to a request.
- Ability to pass in a certificate signing request (csr) to be signed.
- Support Certificate revocation.
    - How the use case would be for that, is not worked out yet.
