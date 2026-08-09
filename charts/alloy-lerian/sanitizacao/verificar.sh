#!/usr/bin/env bash
# Verifica regras de sanitizacao: injeta entrada conhecida, compara saida com a esperada.
#
# Por que este arcabouco existe: em producao as regras rodam com error_mode "ignore".
# Uma regra malformada NAO gera erro — produz saida que aparenta estar mascarada.
# Verificado empiricamente: $$1 emite o texto literal "$1***" sem qualquer aviso.
# Logo, a unica verificacao valida e comparar a saida observada com a esperada.
#
# Uso: ./verificar.sh                    (todos os casos)
#      ./verificar.sh documento-canonico (um caso)
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGEM="grafana/alloy:v1.18.1"
CONTEINER="alloy-verificacao-sanitizacao"
PORTA="${PORTA:-4318}"
FALHAS=0
TOTAL=0

limpar() {
  docker rm -f "$CONTEINER" >/dev/null 2>&1 || true
}
trap limpar EXIT

# --stability.level=experimental e necessario APENAS por causa do exportador de
# depuracao, usado para inspecionar a saida neste arcabouco. A configuracao de
# producao nao usa componente abaixo de GA.
echo "== subindo agente ($IMAGEM) =="
limpar
docker run -d --name "$CONTEINER" \
  -p "${PORTA}:4318" \
  -v "${RAIZ}/regras.alloy:/etc/alloy/config.alloy:ro" \
  "$IMAGEM" run \
    --server.http.listen-addr=0.0.0.0:12345 \
    --stability.level=experimental \
    /etc/alloy/config.alloy >/dev/null

# Espera por CONDICAO (receptor aceitando), nunca por tempo fixo.
pronto=0
for _ in $(seq 1 40); do
  estado=$(docker inspect "$CONTEINER" --format '{{.State.Status}}' 2>/dev/null || echo "ausente")
  if [ "$estado" != "running" ]; then
    echo "FALHA: o agente nao subiu (estado: $estado). Erro de carga:"
    docker logs "$CONTEINER" 2>&1 | grep -A6 'Error:' | head -20
    exit 1
  fi
  if curl -s -o /dev/null --max-time 2 -X POST "http://localhost:${PORTA}/v1/logs" \
      -H 'Content-Type: application/json' --data '{}' 2>/dev/null; then
    pronto=1; break
  fi
  sleep 0.5
done
[ "$pronto" -eq 1 ] || { echo "FALHA: receptor nao respondeu no prazo"; exit 1; }

# Selecao de casos
if [ "$#" -gt 0 ]; then
  selecionados=("$@")
else
  mapfile -t selecionados < <(find "${RAIZ}/casos" -name '*.json' ! -name '*.esperado.json' \
    -printf '%f\n' | sed 's/\.json$//' | sort)
fi

for caso in "${selecionados[@]}"; do
  TOTAL=$((TOTAL+1))
  entrada="${RAIZ}/casos/${caso}.json"
  esperado="${RAIZ}/casos/${caso}.esperado.json"

  if [ ! -f "$entrada" ] || [ ! -f "$esperado" ]; then
    echo "FALHA [${caso}]: falta arquivo de entrada ou de saida esperada"
    FALHAS=$((FALHAS+1)); continue
  fi

  linhas_antes=$(docker logs "$CONTEINER" 2>&1 | wc -l)

  curl -s -o /dev/null -X POST "http://localhost:${PORTA}/v1/logs" \
    -H 'Content-Type: application/json' --data-binary "@${entrada}"

  # Espera a saida crescer, por condicao.
  for _ in $(seq 1 25); do
    [ "$(docker logs "$CONTEINER" 2>&1 | wc -l)" -gt "$linhas_antes" ] && break
    sleep 0.3
  done

  saida=$(docker logs "$CONTEINER" 2>&1 | tail -n +$((linhas_antes+1)))
  corpo_esperado=$(jq -r '.body' "$esperado")

  if printf '%s' "$saida" | grep -qF "$corpo_esperado"; then
    echo "OK    [${caso}]"
  else
    echo "FALHA [${caso}]"
    echo "  esperado: ${corpo_esperado}"
    echo "  observado:"
    printf '%s' "$saida" | grep -oE 'Body: Str\([^)]*\)' | head -3 | sed 's/^/    /' \
      || echo "    (nenhuma linha de corpo na saida)"
    FALHAS=$((FALHAS+1))
  fi
done

echo "== ${TOTAL} caso(s), ${FALHAS} falha(s) =="
[ "$FALHAS" -eq 0 ]
