
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'
export TEMPORAL_ADDRESS="neil-terraform-demo-f188279a.sdvdw.tmprl.cloud:7233"
export TEMPORAL_NAMESPACE="neil-terraform-demo-f188279a.sdvdw"
export TEMPORAL_TLS_CERT="$(pwd)/client.pem"
export TEMPORAL_TLS_KEY="$(pwd)/client.key"

rm *.pem *.key
vault secrets disable pki
vault secrets enable pki
vault secrets tune -max-lease-ttl=87600h pki

vault write pki/config/urls \
     issuing_certificates="$VAULT_ADDR/v1/pki/ca" \
     crl_distribution_points="$VAULT_ADDR/v1/pki/crl"

vault write pki/root/generate/internal \
    common_name="dahlke" \
    organization="dahlke" \
    key_type="rsa" \
    key_bits=4096 \
    exclude_cn_from_sans=true

vault write pki/roles/temporal-client-cert \
    allowed_domains="dahlke.io" \
    allow_subdomains=true \
    max_ttl="720h" \
    key_type="ec" \
    key_bits=384

vault write pki/roles/temporal-client-cert \
    allowed_domains="dahlke.io" \
    allow_subdomains=true \ max_ttl="720h" \
    key_type="rsa" \
    key_bits=2048 \
    allow_any_name=true \
    key_usage="DigitalSignature" \
    ext_key_usage="ClientAuth" \
    require_cn=false

vault write -format=json pki/issue/temporal-client-cert \
    organization="dahlke" \
    ttl="720h" \
    private_key_format="pkcs8" \
    > cert_output.json

cat cert_output.json | jq -r '.data.certificate' > client.pem
cat cert_output.json | jq -r '.data.private_key' > client.key
cat cert_output.json | jq -r '.data.ca_chain[]' > ca_chain.pem

tcld namespace accepted-client-ca add --namespace $TEMPORAL_NAMESPACE --ca-certificate $(cat ca_chain.pem | base64)
tcld namespace accepted-client-ca remove --namespace $TEMPORAL_NAMESPACE --fp $(tcld namespace accepted-client-ca list --namespace $TEMPORAL_NAMESPACE | jq '.[0].fingerprint')

# temporal workflow list