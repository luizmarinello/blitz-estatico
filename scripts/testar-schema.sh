#!/usr/bin/env sh
# Aplica a migração num PostgreSQL descartável (Docker) e roda as checagens de supabase/testes/schema_test.sql.
# Uso: sh scripts/testar-schema.sh
set -e
raiz="$(cd "$(dirname "$0")/.." && pwd)"
command -v cygpath >/dev/null && raiz="$(cygpath -m "$raiz")"   # Git Bash no Windows
MSYS_NO_PATHCONV=1 docker run --rm \
  -e POSTGRES_PASSWORD=teste \
  -v "$raiz/supabase/migrations:/migracoes:ro" \
  -v "$raiz/supabase/testes:/testes:ro" \
  postgres:17-alpine \
  sh -c 'docker-entrypoint.sh postgres >/dev/null 2>&1 & until pg_isready -U postgres -q; do sleep 0.5; done; sleep 1; psql -U postgres -q -t -A -f /testes/schema_test.sql'
