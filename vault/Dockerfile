FROM vault:0.7.3

MAINTAINER Ivan Suftin <isuftin@usgs.gov>

RUN apk --no-cache add curl jq

HEALTHCHECK --interval=5s --timeout=3s CMD curl -k -s https://localhost:${VAULT_SERVER_PORT:-8200}/v1/sys/health | jq -r '.standby | tostring | test("true")' | grep -q 'true' || exit 1
