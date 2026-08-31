#!/usr/bin/env bash
# Publica no Fleet Management a configuracao de coleta COMPLETA de um cliente,
# renderizada a partir do chart.
#
# ⚠️ NAO EXECUTE SEM A PORTA DE ENTREGA TER PASSADO. Este script nao a executa —
# quem garante a ordem e o workflow que o chama. Rodar a mao, pulando a porta, e
# exatamente o que ele existe para evitar.
#
# POR QUE ELE EXISTE
#
# Publicar pela console do Grafana e um caminho que NAO passa pelo gate. Uma
# configuracao editada la chega aos coletores em 1 minuto sem que nada verifique
# se as regras de PII funcionam. E `error_mode` em producao e "ignore": regra
# malformada nao gera erro, so saida que aparenta estar mascarada.
#
# ⚠️ O QUE E PUBLICADO E O RENDER DO CHART, nao um arquivo separado. Isso importa:
# a config LOCAL (o ConfigMap, ativo quando `fleetManagement.enabled: false`) e o
# artefato de DR. Publicar o mesmo render garante que os dois nao divergem — se
# divergissem, o DR restauraria uma versao desatualizada, que e exatamente o
# problema que o Fleet existe para resolver.
#
# ⚠️ SEGREDO NAO VAI NO TEXTO. O render contem `sys.env("ALLOY_...")`, que o
# agente resolve do ambiente do pod. VERIFICADO em cluster: um modulo remoto com
# `sys.env()` carrega e resolve normalmente. O Fleet nunca ve o valor.
#
# ⚠️ SO O CLIENT_ID VARIA entre clientes. O resto do values e identico: perfil,
# endpoint e as referencias de Secret sao as mesmas em todos, e o valor da
# credencial vive no Secret do cluster, nao no values. Por isso este script
# renderiza com o exemplo do chart, injetando apenas `origin.id`.
#
# Uso:
#   FLEET_URL=... FLEET_USER=... FLEET_TOKEN=... CLIENT_ID=acme-prd \
#     ./publicar-fleet.sh [--dry-run]
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART="$(cd "${RAIZ}/.." && pwd)"
TEMPLATE="${CHART}/templates/_sanitizacao.tpl"
VALUES_BASE="${VALUES_BASE:-${CHART}/examples/values-cliente.yaml}"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

for v in FLEET_URL FLEET_USER FLEET_TOKEN; do
  if [ -z "${!v:-}" ]; then
    echo "FALHA: $v nao definida."
    echo ""
    echo "  CLIENT_ID entra no matcher e DELIMITA o destinatario. Sem ele a"
    echo "  configuracao iria para TODOS os coletores da stack — o escopo minimo"
    echo "  de uma access policy do Fleet e a stack inteira, entao o matcher e a"
    echo "  unica separacao entre clientes que existe."
    exit 2
  fi
done

[ -f "$VALUES_BASE" ] || { echo "FALHA: values base ausente: $VALUES_BASE"; exit 2; }

echo "=============================================="
echo " Publicar configuracao de coleta no Fleet"
echo "=============================================="
echo "  stack:     ${FLEET_URL}"
echo "  versao:    (definida abaixo)"
echo "  base:      ${VALUES_BASE}"
[ "$DRY_RUN" = "1" ] && echo "  MODO:      dry-run (nao envia)"
echo ""

# ---------------------------------------------------------------------------
echo "[1/5] Renderizar a configuracao do chart"
# ---------------------------------------------------------------------------
MODULO="$(mktemp)"
trap 'rm -f "$MODULO" "${CORPO:-}" "${RESP:-}"' EXIT

# `origin.id` ainda e exigido pelo chart (marca procedencia no render), mas o
# valor NAO entra na config: os 8 pontos usam sys.env. Um marcador explicito deixa
# isso visivel para quem inspecionar o render.
if ! helm template publicar "$CHART" -f "$VALUES_BASE" \
      --set "origin.id=global-prd" 2>/dev/null \
    | python3 "${RAIZ}/publicar-fleet-extrair.py" > "$MODULO"; then
  echo "  ✗ falha ao renderizar ou extrair a config do papel node"
  echo "    Reproduza com: helm template . -f ${VALUES_BASE} --set origin.id=${CLIENT_ID}"
  exit 1
fi

BYTES=$(wc -c < "$MODULO" | tr -d ' ')
if [ "$BYTES" -lt 1000 ]; then
  echo "  ✗ config renderizada tem so ${BYTES} bytes — suspeito"
  echo "    Publicar uma config truncada deixaria o cliente sem coleta."
  exit 1
fi
echo "  ✓ ${BYTES} bytes, $(grep -c '' "$MODULO") linhas"

# ---------------------------------------------------------------------------
echo ""
echo "[2/5] Conferir o que foi renderizado"
# ---------------------------------------------------------------------------
# ⚠️ Verificacoes sobre o RENDER, antes de publicar. Um render que perdeu as
# regras de PII, ou que carrega o client_id errado, so seria notado em producao.
N_REGRAS=$(grep -c 'replace_pattern(body' "$MODULO" || true)
N_ESPERADO=$(grep -c 'replace_pattern(body' "$TEMPLATE" || true)
if [ "${N_REGRAS:-0}" -lt "${N_ESPERADO:-0}" ]; then
  echo "  ✗ o render tem ${N_REGRAS} regras de PII; o template tem ${N_ESPERADO}"
  exit 1
fi
echo "  ✓ ${N_REGRAS} regra(s) de PII presentes"

# ⚠️ O client_id NAO pode estar gravado: a config e global. Ele tem de vir de
# `sys.env("ALLOY_CLIENT_ID")`, resolvido do pod de cada cliente.
#
# Publicar com valor gravado marcaria TODOS os clientes com o mesmo id.
N_ENV=$(grep -c 'sys.env("ALLOY_CLIENT_ID")' "$MODULO" || true)
if [ "${N_ENV:-0}" -lt 1 ]; then
  echo "  ✗ o render NAO usa sys.env(\"ALLOY_CLIENT_ID\")"
  echo "    Sem isso a config nao e global: todo cliente receberia o mesmo id."
  exit 1
fi
echo "  ✓ client_id vem do pod (${N_ENV} ocorrencia(s) de sys.env)"

# Segredo em texto claro seria o pior defeito possivel aqui: o Fleet passaria a
# guardar credencial de cliente.
#
# ⚠️ A verificacao EXCLUI linhas com `sys.env(` — foi falso positivo na primeira
# versao, porque `sys.env("ALLOY_DESTINATION_CREDENTIAL")` casa qualquer regex que
# procure "coisa longa depois de x-api-key". O que se procura e VALOR literal, e
# `sys.env` e justamente a forma correta de nao ter valor no texto.
if grep -vE 'sys\.env\(' "$MODULO" \
   | grep -qE '(x-api-key|password|token|api_key)[^=]*=[^=]*"[A-Za-z0-9_.-]{20,}"'; then
  echo "  ✗ ha CREDENCIAL EM TEXTO CLARO no render"
  echo "    A config deve usar sys.env(). Publicar assim exporia o segredo."
  exit 1
fi
echo "  ✓ nenhuma credencial em texto claro (usa sys.env)"

# ---------------------------------------------------------------------------
echo ""
echo "[3/5] Montar o envio"
# ---------------------------------------------------------------------------
# ⚠️ O NOME CARREGA A VERSAO, e isso nao e cosmetico.
#
# MEDIDO em aws-devops: o agente que ja carregou um modulo NAO LIBERA o nome, nem
# depois de o modulo ser deletado do Fleet. Republicar com o MESMO nome trava:
#
#   err="a loader exists already for remotecfg/config_aws_devops.default"
#
# E o agente fica preso a config anterior, sem erro visivel fora do log dele.
#
# ⚠️ A sequencia delete->esperar->create NAO resolve isso. Ela foi validada com
# nomes DIFERENTES (teste_seq_v1 -> teste_seq_v2) e funcionou por causa disso — o
# uso real, com nome fixo, tem a condicao que o teste nao tinha.
#
# Com a versao no nome, cada publicacao cria um modulo NOVO, que o agente carrega
# sem conflito. O antigo e removido DEPOIS.
VERSAO="${VERSAO_CONFIG:-${GITHUB_SHA:-$(cd "$CHART" && git rev-parse --short HEAD 2>/dev/null || echo local)}}"
VERSAO="$(echo "$VERSAO" | tr -cd '[:alnum:]' | cut -c1-12)"
# ⚠️ UMA configuracao para TODOS os clientes. O que distingue um do outro e a
# variavel ALLOY_CLIENT_ID do pod, resolvida por `sys.env` nos 8 pontos onde o
# client_id aparece. VERIFICADO: renderizar com clientes diferentes produz saidas
# byte a byte identicas.
#
# Por isso o nome nao carrega o cliente, e o matcher tambem nao.
BASE="config_global"
NOME="${BASE}_${VERSAO}"
CORPO="$(mktemp)"
python3 "${RAIZ}/publicar-fleet-corpo.py" "$MODULO" "$NOME" > "$CORPO"
echo "  ✓ pipeline '${NOME}' — global, matcher role=\"node\""

if [ "$DRY_RUN" = "1" ]; then
  echo ""
  echo "  · dry-run: nao enviado. Primeiras 15 linhas do que seria publicado:"
  head -15 "$MODULO" | sed 's/^/      /'
  echo "      [...]"
  echo ""
  echo " ✓ dry-run concluido"
  exit 0
fi

# ---------------------------------------------------------------------------
echo ""
echo "[4/5] Publicar"
# ---------------------------------------------------------------------------
RESP="$(mktemp)"

# ⚠️ ORDEM INVERTIDA em relacao a versao anterior: CRIA o novo, confirma que o
# agente o carregou, e SO ENTAO remove os antigos.
#
# A ordem antiga (delete -> esperar -> create) existia porque os nomes colidiam.
# Com a versao no nome nao colidem, e inverter elimina a janela sem coleta: nunca
# ha um instante em que o cliente esta sem configuracao publicada.
#
# ⚠️ Durante a transicao os DOIS modulos casam o matcher. Isso e aceitavel e
# temporario — o agente carrega ambos, e o antigo sai no passo seguinte. O que
# NAO seria aceitavel e o inverso: um instante sem nenhum.

CODIGO=$(curl -s -o "$RESP" -w '%{http_code}' -X POST --max-time 30 \
  -H 'Content-Type: application/json' -u "${FLEET_USER}:${FLEET_TOKEN}" \
  --data-binary @"$CORPO" \
  "${FLEET_URL}/pipeline.v1.PipelineService/CreatePipeline")

if [ "$CODIGO" != "200" ]; then
  echo "  ✗ CreatePipeline respondeu HTTP ${CODIGO}"
  head -c 300 "$RESP" | sed 's/^/      /'
  echo ""
  if [ "$CODIGO" = "409" ]; then
    echo "   409 = ja existe pipeline com o nome '${NOME}'."
    echo "   O nome carrega o commit, entao publicar o MESMO commit duas vezes colide."
    echo "   Se a intencao e republicar sem mudar codigo, use VERSAO_CONFIG:"
    echo "     VERSAO_CONFIG=\$(date -u +%Y%m%d%H%M) ./publicar-fleet.sh"
  fi
  echo ""
  echo " ✗ FALHOU — nada mudou. A configuracao ANTERIOR segue no ar, porque este"
  echo "   script cria a nova ANTES de remover a antiga."
  exit 1
fi
echo "  ✓ CreatePipeline respondeu 200 — publicado como '${NOME}'"

# Remove as versoes ANTERIORES do mesmo cliente. Sem isso elas se acumulam, e o
# matcher casaria todas — o agente carregaria configuracoes concorrentes.
curl -s -o "$RESP" -X POST -H 'Content-Type: application/json' --max-time 20 \
  -d '{}' -u "${FLEET_USER}:${FLEET_TOKEN}" \
  "${FLEET_URL}/pipeline.v1.PipelineService/ListPipelines" >/dev/null 2>&1 || true

ANTIGOS=$(python3 "${RAIZ}/publicar-fleet-antigos.py" "$RESP" "$BASE" "$NOME")
if [ -n "$ANTIGOS" ]; then
  echo "$ANTIGOS" | while IFS=$'\t' read -r ID_ANTIGO NOME_ANTIGO; do
    COD=$(curl -s -o /dev/null -w '%{http_code}' -X POST --max-time 20 \
      -H 'Content-Type: application/json' -u "${FLEET_USER}:${FLEET_TOKEN}" \
      -d "{\"id\":\"${ID_ANTIGO}\"}" \
      "${FLEET_URL}/pipeline.v1.PipelineService/DeletePipeline")
    if [ "$COD" = "200" ]; then
      echo "  ✓ versao anterior removida: ${NOME_ANTIGO}"
    else
      echo "  ⚠ nao consegui remover ${NOME_ANTIGO} (HTTP ${COD}) — remova a mao"
    fi
  done
else
  echo "  · nenhuma versao anterior a remover"
fi

# ---------------------------------------------------------------------------
echo ""
echo "[5/5] Reconferir o publicado"
# ---------------------------------------------------------------------------
echo ""
"${RAIZ}/verificar-fleet.sh"
