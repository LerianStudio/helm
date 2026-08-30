#!/usr/bin/env bash
# Publica as regras de sanitizacao no Fleet Management, gerando o modulo a partir
# do template do chart.
#
# ⚠️ NAO EXECUTE ESTE SCRIPT SEM A PORTA DE ENTREGA TER PASSADO. Ele nao a executa
# por conta propria — quem garante a ordem e o workflow que o chama. Rodar a mao,
# pulando a porta, e exatamente o que ele existe para evitar.
#
# POR QUE ELE EXISTE
#
# Publicar pela console do Grafana e um caminho que NAO passa pelo gate. Uma regra
# editada la chega a todos os coletores em 1 minuto, sem que nada verifique se ela
# funciona. E `error_mode` em producao e "ignore": regra malformada nao gera erro,
# so saida que aparenta estar mascarada.
#
# Este script fecha a console como via de edicao. Ela continua servindo para VER o
# que esta publicado; quem ESCREVE e o workflow, e so depois da porta liberar.
#
# O QUE ELE GARANTE, alem de enviar
#
#   1. as regras saem do template do chart, nao de uma copia
#   2. a ORDEM e preservada — e contrato, medido: inverter telefone e documento
#      produz "+551********21", perdendo o codigo de area
#   3. o modulo DEVOLVE ao fluxo local, nunca exporta direto — medido: exportar
#      direto perde o rotulo client.id e o log some dos paineis
#   4. o publicado e reconferido depois de enviar, pelo verificar-fleet.sh
#
# Uso:
#   FLEET_URL=... FLEET_USER=... FLEET_TOKEN=... CLIENT_ID=aws-devops \
#     ./publicar-fleet.sh [--dry-run]
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${RAIZ}/../templates/_sanitizacao.tpl"
PORTA_ENTRADA="${PORTA_ENTRADA_PONTE:-4319}"
PORTA_RETORNO="${PORTA_RETORNO_PONTE:-4320}"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

for v in FLEET_URL FLEET_USER FLEET_TOKEN CLIENT_ID; do
  if [ -z "${!v:-}" ]; then
    echo "FALHA: $v nao definida."
    echo ""
    echo "  CLIENT_ID identifica o destinatario e entra no matcher da pipeline."
    echo "  Sem ele a regra iria para TODOS os coletores da stack, incluindo os de"
    echo "  outros clientes — o escopo minimo de uma access policy do Fleet e a"
    echo "  stack inteira, entao o matcher e a unica delimitacao que existe."
    exit 2
  fi
done

echo "=============================================="
echo " Publicar regras de sanitizacao no Fleet"
echo "=============================================="
echo "  stack:     ${FLEET_URL}"
echo "  client_id: ${CLIENT_ID}"
[ "$DRY_RUN" = "1" ] && echo "  MODO:      dry-run (nao envia)"
echo ""

# ---------------------------------------------------------------------------
echo "[1/4] Extrair as regras do template do chart"
# ---------------------------------------------------------------------------
# Mesmo extrator da porta de entrega e do verificador. Tres lugares, um extrator:
# se ele mudar, muda para todos, e nao ha como um validar o que o outro nao ve.
mapfile -t REGRAS < <(grep -oE 'replace_pattern\(body, "[^"]+", "[^"]*"\)' "$TEMPLATE")

if [ "${#REGRAS[@]}" -eq 0 ]; then
  echo "  ✗ nenhuma regra extraida de $TEMPLATE"
  echo "    Publicar um modulo VAZIO desligaria a sanitizacao de todos os"
  echo "    coletores que casam o matcher. Abortado."
  exit 1
fi
echo "  ✓ ${#REGRAS[@]} regra(s), na ordem do template"

# ---------------------------------------------------------------------------
echo ""
echo "[2/4] Montar o modulo"
# ---------------------------------------------------------------------------
MODULO="$(mktemp)"; trap 'rm -f "$MODULO" "${CORPO:-}" "${RESP:-}"' EXIT
{
  echo "// GERADO por sanitizacao/publicar-fleet.sh — nao edite pela console."
  echo "// Edicao manual e sobrescrita na proxima publicacao, e nao passa pela"
  echo "// porta de entrega. Para mudar uma regra: PR em templates/_sanitizacao.tpl."
  echo "//"
  echo "// origem:  ${GITHUB_SHA:-<local>}"
  echo "// regras:  ${#REGRAS[@]}"
  echo ""
  echo "otelcol.receiver.otlp \"ponte_mod_entrada\" {"
  echo "  http {"
  echo "    endpoint = \"127.0.0.1:${PORTA_ENTRADA}\""
  echo "  }"
  echo "  output {"
  echo "    logs = [otelcol.processor.transform.ponte_mod_sanit.input]"
  echo "  }"
  echo "}"
  echo ""
  echo "otelcol.processor.transform \"ponte_mod_sanit\" {"
  echo "  // \"ignore\" e o mesmo de producao. E por isso que a correcao das regras"
  echo "  // e provada pela porta de entrega, e nao confiada a este mecanismo:"
  echo "  // regra malformada nao gera erro, so saida que aparenta estar mascarada."
  echo "  error_mode = \"ignore\""
  echo ""
  echo "  log_statements {"
  echo "    context = \"log\""
  echo "    statements = ["
  for r in "${REGRAS[@]}"; do
    echo "      \`${r}\`,"
  done
  echo "    ]"
  echo "  }"
  echo ""
  echo "  output {"
  echo "    logs = [otelcol.exporter.otlphttp.ponte_mod_saida.input]"
  echo "  }"
  echo "}"
  echo ""
  echo "// ⚠️ DEVOLVE ao fluxo local. Exportar direto ao destino perderia o rotulo"
  echo "// client.id, que o chart aplica num estagio POSTERIOR — medido: o log"
  echo "// chega sem client_id e some de todo painel e do alerta O11Y-LOG-001."
  echo "otelcol.exporter.otlphttp \"ponte_mod_saida\" {"
  echo "  client {"
  echo "    endpoint = \"http://127.0.0.1:${PORTA_RETORNO}\""
  echo "    tls {"
  echo "      insecure = true"
  echo "    }"
  echo "  }"
  echo "}"
} > "$MODULO"
echo "  ✓ modulo montado, $(wc -c < "$MODULO" | tr -d ' ') bytes"
echo "    entrada ${PORTA_ENTRADA} -> sanitizacao -> retorno ${PORTA_RETORNO}"

# ---------------------------------------------------------------------------
echo ""
echo "[3/4] Publicar"
# ---------------------------------------------------------------------------
NOME="sanitizacao_pii_$(echo "$CLIENT_ID" | tr '[:upper:]-' '[:lower:]_')"
CORPO="$(mktemp)"
python3 - "$MODULO" "$NOME" "$CLIENT_ID" > "$CORPO" <<'PY'
import json, sys
conteudo = open(sys.argv[1], encoding="utf-8").read()
# ⚠️ O matcher DELIMITA o destinatario. Sem client_id a regra iria para todos os
# coletores da stack — o escopo minimo de uma access policy do Fleet e a stack
# inteira, entao o matcher e a unica separacao entre clientes que existe.
print(json.dumps({"pipeline": {
    "name": sys.argv[2],
    "contents": conteudo,
    "matchers": ['collector.os="linux"', 'role="node"', f'client_id="{sys.argv[3]}"'],
    "enabled": True,
}}))
PY

if [ "$DRY_RUN" = "1" ]; then
  echo "  · dry-run: nao enviado. Modulo que seria publicado como '$NOME':"
  sed 's/^/      /' "$MODULO"
  echo ""
  echo " ✓ dry-run concluido"
  exit 0
fi

# CreatePipeline falha se o nome ja existe; UpdatePipeline exige o id. Descobre
# qual usar consultando o que esta publicado.
RESP="$(mktemp)"
curl -s -o "$RESP" -X POST -H 'Content-Type: application/json' --max-time 20 \
  -d '{}' -u "${FLEET_USER}:${FLEET_TOKEN}" \
  "${FLEET_URL}/pipeline.v1.PipelineService/ListPipelines" >/dev/null 2>&1 || true
ID_EXISTENTE=$(python3 - "$RESP" "$NOME" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print(""); raise SystemExit
for p in d.get("pipelines", []):
    if p.get("name") == sys.argv[2]:
        print(p.get("id", "")); raise SystemExit
print("")
PY
)

# ⚠️ OUTRO modulo ja escutando a MESMA porta para o MESMO cliente?
#
# MEDIDO na primeira publicacao real: havia um modulo publicado A MAO com outro
# NOME e o mesmo matcher. Os dois casaram o mesmo coletor, disputaram a porta
# 4319, e o segundo falhou com "address already in use". O log seguiu funcionando
# pelo primeiro — a falha era SILENCIOSA do ponto de vista do dado.
#
# Qual dos dois vence depende da ordem de carga, que nao e deterministica.
# Publicar por cima disso deixaria a duvida em producao. Aborta.
CONFLITANTES=$("${RAIZ}/publicar-fleet-conflitos.py" "$RESP" "$NOME" "$CLIENT_ID" "$PORTA_ENTRADA")

if [ -n "$CONFLITANTES" ]; then
  echo "  ✗ OUTRO modulo ja escuta a porta ${PORTA_ENTRADA} para ${CLIENT_ID}:"
  echo "$CONFLITANTES" | sed 's/^/        /'
  echo ""
  echo "    Publicar deixaria dois modulos disputando a mesma porta. Um deles"
  echo "    falha com address already in use, e qual deles depende da ordem de"
  echo "    carga — o log continua fluindo pelo vencedor, entao a falha e"
  echo "    silenciosa do ponto de vista do dado."
  echo ""
  echo "    Remova ou desabilite o outro modulo antes de publicar."
  echo ""
  echo " ✗ ABORTADO — nada foi publicado"
  exit 1
fi

if [ -n "$ID_EXISTENTE" ]; then
  METODO="UpdatePipeline"
  python3 - "$CORPO" "$ID_EXISTENTE" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
d["pipeline"]["id"] = sys.argv[2]
open(sys.argv[1], "w").write(json.dumps(d))
PY
  echo "  · pipeline '$NOME' ja existe (id $ID_EXISTENTE) — atualizando"
else
  METODO="CreatePipeline"
  echo "  · pipeline '$NOME' nao existe — criando"
fi

CODIGO=$(curl -s -o "$RESP" -w '%{http_code}' -X POST --max-time 30 \
  -H 'Content-Type: application/json' -u "${FLEET_USER}:${FLEET_TOKEN}" \
  --data-binary @"$CORPO" \
  "${FLEET_URL}/pipeline.v1.PipelineService/${METODO}")

if [ "$CODIGO" != "200" ]; then
  echo "  ✗ ${METODO} respondeu HTTP ${CODIGO}"
  head -c 300 "$RESP" | sed 's/^/      /'
  echo ""
  echo " ✗ FALHOU — nada foi publicado"
  exit 1
fi
echo "  ✓ ${METODO} respondeu 200"

# ---------------------------------------------------------------------------
echo ""
echo "[4/4] Reconferir o publicado"
# ---------------------------------------------------------------------------
# ⚠️ Publicar sem reconferir deixa o resultado por suposicao. O verificador compara
# o que ESTA la com o template, na ordem, e acusa exportador que nao devolva.
echo ""
PORTA_RETORNO_PONTE="$PORTA_RETORNO" "${RAIZ}/verificar-fleet.sh"
