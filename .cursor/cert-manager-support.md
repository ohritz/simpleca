### cert-manager support plan (CA Issuer)

Objective
- Add a subcommand to export artifacts and manifests so Kubernetes users can create a cert-manager CA Issuer that signs leaf certs using our intermediate CA.
- Requirements from docs: Secret must contain the issuer's private key (unencrypted) and a certificate that includes the full chain in order `issuer -> intermediates -> root`. We will create an Issuer (not ClusterIssuer).
- Reference: [cert-manager CA Issuer deployment](https://cert-manager.io/docs/configuration/ca/#deployment)

Scope
- Do not change existing CA structure. Add a safe export path that never overwrites internal encrypted keys.
- Use existing `root` and `intermediate` from `src/init.sh`.

New subcommand
- Name: `cert-manager`
- Mode: `export`
- Example:
  - `simpleca cert-manager export --ns sandbox --issuer-name ca-issuer --secret-name ca-key-pair --out /opt/export/manifests`
- Options:
  - `--ns, --namespace` (required): Kubernetes namespace for Secret/Issuer
  - `--issuer-name` (default: `ca-issuer`)
  - `--secret-name` (default: `ca-key-pair`)
  - `--out` (default: `/opt/export/manifests`)
  - `--crl` (optional, repeatable): CRL Distribution Points URLs
  - `--ocsp` (optional, repeatable): OCSP server URLs
  - `--force` (optional): overwrite files in output dir

Generated files (under `<out>/<ns>/<issuer-name>/`)
- `intermediate.key.unencrypted.pem` — PKCS#8 unencrypted private key for the intermediate CA
- `issuer.fullchain.crt.pem` — concatenation: `intermediate.cert.pem` + `root/ca.cert.pem`
- `secret.yaml` — Kubernetes TLS Secret manifest (`type: kubernetes.io/tls`) with base64-encoded `tls.crt` (full chain) and `tls.key` (unencrypted intermediate key)
- `issuer.yaml` — Kubernetes Issuer referencing the Secret; includes optional CRL/OCSP

Implementation details
- Compute paths using `src/common.sh`:
  - Intermediate key (encrypted): `$intermediateKey`
  - Intermediate cert: `$intermediateCert`
  - Chain (already generated): `$certificateChain` which is `intermediate + root`
- Produce unencrypted PKCS#8 for Kubernetes Secret (do not replace the source key on disk):
```bash
# Prompt for intermediate key password once (respect NON_INTERACTIVE/PASS_FILE if implemented)
openssl pkey \
  -in "$intermediateKey" \
  -passin pass:"$INTERMEDIATE_PASS" \
  -out "$workdir/intermediate.key.unencrypted.pem"
chmod 600 "$workdir/intermediate.key.unencrypted.pem"
```
- Use the existing full chain file or rebuild to be explicit:
```bash
cat "$intermediateCert" "$rootCaCert" > "$workdir/issuer.fullchain.crt.pem"
chmod 644 "$workdir/issuer.fullchain.crt.pem"
```
- Render Secret manifest (no kubectl required). Use base64 without line wraps:
```bash
b64_crt=$(base64 -w0 < "$workdir/issuer.fullchain.crt.pem")
b64_key=$(base64 -w0 < "$workdir/intermediate.key.unencrypted.pem")
cat > "$outdir/secret.yaml" <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: simpleca
type: kubernetes.io/tls
data:
  tls.crt: ${b64_crt}
  tls.key: ${b64_key}
YAML
```
- Render Issuer manifest:
```bash
cat > "$outdir/issuer.yaml" <<YAML
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: ${ISSUER_NAME}
  namespace: ${NAMESPACE}
spec:
  ca:
    secretName: ${SECRET_NAME}
YAML
```
- Append optional CRL/OCSP arrays if provided:
```bash
# Pseudocode; in script, loop args into YAML lists
#   crlDistributionPoints:
#   - "http://example.com/my.crl"
#   ocspServers:
#   - "http://ocsp.example.com"
```

Safety & UX
- Never store the unencrypted key inside `/opt/ca`; only write it into the export directory.
- Create output under a unique timestamped folder unless `--force` specified.
- Print clear warnings that the unencrypted key will be written to disk; remind to treat export dir as sensitive.

Validation
- Verify chain and key match:
```bash
openssl x509 -noout -subject -issuer -in "$workdir/issuer.fullchain.crt.pem"
openssl verify -CAfile "$rootCaCert" "$intermediateCert"
# public key match (leaf check for intermediate cert)
openssl x509 -noout -pubkey -in "$intermediateCert" | openssl pkey -pubin -pubout >/dev/null 2>&1 || exit 1
```
- Validate manifests are syntactically correct (optional): `yq eval '.' secret.yaml >/dev/null`

End-to-end usage
1) Initialize CA (already supported):
```bash
docker run --rm -it \
  --env-file ./.env \
  --mount source=ca-vol,target=/opt/ca \
  osorenan/simpleca --init
```
2) Export cert-manager artifacts:
```bash
docker run --rm -it \
  --mount source=ca-vol,target=/opt/ca \
  --mount type=bind,source="$PWD/export",target=/opt/export \
  osorenan/simpleca cert-manager export \
    --ns sandbox \
    --issuer-name ca-issuer \
    --secret-name ca-key-pair \
    --out /opt/export/manifests
```
3) Apply in the cluster:
```bash
kubectl apply -f export/manifests/sandbox/ca-issuer/secret.yaml
kubectl apply -f export/manifests/sandbox/ca-issuer/issuer.yaml
kubectl get issuers -n sandbox
```

Notes
- Issuer only; not ClusterIssuer per requirement.
- Per cert-manager docs, including the full chain in `tls.crt` ensures consumers of issued certs can verify trust. See the upstream guidance: [cert-manager CA Issuer deployment](https://cert-manager.io/docs/configuration/ca/#deployment)
- Consider adding flags later for alternative chain order or excluding root if some environments require it, but default should be full chain as recommended.
