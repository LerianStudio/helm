#!/usr/bin/env bash
# Compara as regras de sanitizacao PUBLICADAS no Fleet Management com as do
# repositorio. Existe porque, quando `sanitizacao.local.enabled: false`, as regras
# que rodam em producao vem de fora do repositorio — e a partir dai a porta de
# entrega, que compara arcabouco vs template, deixa de cobrir o que roda.
#
# ⚠️ error_mode em producao e "ignore": regra malformada NAO gera erro, so saida
# que aparenta estar mascarada. Divergencia silenciosa entre o testado e o
# publicado e exatamente o modo de falha que este verificador fecha.
#
# NAO substitui a porta de entrega. A porta prova que as regras FUNCIONAM (54
# casos contra o agente real); este script prova que as regras publicadas SAO as
# mesmas que foram provadas.
#
# Uso:
#   FLEET_URL=https://fleet-management-prod-015.grafana.net \
#   FLEET_USER=1563949 \
#   FLEET_TOKEN=... \
#     ./verificar-fleet.sh
#
# Em CI, obter o token do gestor de segredos — nunca embutir no repositorio nem
# passar por linha de comando (fica no `ps` e no historico do shell).
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${RAIZ}/../templates/_sanitizacao.tpl"
FALHAS=0

ok()   { echo "  ✓ $1"; }
erro() { echo "  ✗ $1"; FALHAS=$((FALHAS + 1)); }

# Mesmo extrator da porta de entrega, pela mesma razao: comparar a REGRA, nao o
# comentario nem a indentacao ao redor.
extrai() { grep -oE 'replace_pattern\(body, "[^"]+", "[^"]*"\)' "$1"; }

for v in FLEET_URL FLEET_USER FLEET_TOKEN; do
  if [ -z "${!v:-}" ]; then
    echo "FALHA: $v nao definida."
    echo "  Este verificador nao tem valor padrao de proposito: apontar para a stack"
    echo "  errada compararia contra pipelines de outro ambiente e passaria."
    exit 2
  fi
done

echo "=============================================="
echo " Regras publicadas no Fleet == repositorio?"
echo "=============================================="
echo "  stack: ${FLEET_URL}"
echo ""

# ---------------------------------------------------------------------------
echo "[1/4] Pipelines publicadas sao alcancaveis"
# ---------------------------------------------------------------------------
RESP="$(mktemp)"; trap 'rm -f "$RESP"' EXIT
# ⚠️ `Content-Type: application/json` e OBRIGATORIO. A API e Connect RPC e
# responde 415 sem o header — o `curl -d` sozinho envia
# application/x-www-form-urlencoded. MEDIDO: 415 antes, 200 depois.
CODIGO=$(curl -s -o "$RESP" -w '%{http_code}' -X POST --max-time 20 \
  -H 'Content-Type: application/json' \
  -d '{}' -u "${FLEET_USER}:${FLEET_TOKEN}" \
  "${FLEET_URL}/pipeline.v1.PipelineService/ListPipelines" || echo "000")

case "$CODIGO" in
  200) ok "ListPipelines respondeu 200" ;;
  401|403)
    erro "credencial recusada (HTTP $CODIGO) — token expirado ou de outra stack"
    echo ""; echo " ✗ BLOQUEADO"; exit 1 ;;
  000)
    erro "sem resposta — rede, DNS ou URL incorreta"
    echo ""; echo " ✗ BLOQUEADO"; exit 1 ;;
  *)
    erro "HTTP $CODIGO inesperado"
    head -c 300 "$RESP" | sed 's/^/      /'
    echo ""; echo " ✗ BLOQUEADO"; exit 1 ;;
esac

# ---------------------------------------------------------------------------
echo ""
echo "[2/4] Toda pipeline habilitada com regra de PII confere com o repositorio"
# ---------------------------------------------------------------------------
# ⚠️ Só as HABILITADAS. Uma pipeline desabilitada nao processa dado, e bloquear
# por causa dela transformaria rascunho em impedimento de entrega. Mas ela e
# LISTADA abaixo: rascunho divergente que alguem habilite depois vira o defeito
# que este script existe para pegar.
ESPERADO="$(mktemp)"; PUBLICADO="$(mktemp)"
trap 'rm -f "$RESP" "$ESPERADO" "$PUBLICADO"' EXIT
extrai "$TEMPLATE" > "$ESPERADO"
N_ESPERADO=$(wc -l < "$ESPERADO" | tr -d ' ')

# Nomes das pipelines que carregam regra de sanitizacao, e se estao habilitadas.
mapfile -t COM_REGRA < <(python3 - "$RESP" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
for p in d.get("pipelines", []):
    conteudo = p.get("contents", "") or ""
    if "replace_pattern(body" not in conteudo:
        continue
    # `enabled` ausente conta como habilitada: a API omite o campo quando true.
    hab = p.get("enabled", True)
    print(f"{p.get('name','(sem nome)')}\t{'sim' if hab else 'nao'}")
PY
)

if [ "${#COM_REGRA[@]}" -eq 0 ]; then
  ok "nenhuma pipeline publicada carrega regra de PII"
  echo "      (esperado enquanto sanitizacao.local.enabled for true em todos)"
else
  for linha in "${COM_REGRA[@]}"; do
    NOME="${linha%%$'\t'*}"; HAB="${linha##*$'\t'}"
    python3 - "$RESP" "$NOME" > "$PUBLICADO" <<'PY'
import json, re, sys
d = json.load(open(sys.argv[1]))
for p in d.get("pipelines", []):
    if p.get("name") == sys.argv[2]:
        for m in re.finditer(r'replace_pattern\(body, "[^"]+", "[^"]*"\)', p.get("contents","")):
            print(m.group(0))
PY
    N_PUB=$(wc -l < "$PUBLICADO" | tr -d ' ')
    # SEM `sort`: a ordem e contrato. Medido na porta de entrega que inverter
    # telefone e documento produz "+551********21", perdendo o codigo de area.
    if diff -q "$ESPERADO" "$PUBLICADO" >/dev/null 2>&1; then
      ok "[$NOME] habilitada=$HAB — $N_PUB regra(s) identicas, na mesma ordem"
    elif [ "$HAB" = "nao" ]; then
      echo "  ⚠ [$NOME] DESABILITADA e divergente ($N_PUB vs $N_ESPERADO) — nao bloqueia,"
      echo "      mas habilitar assim colocaria em producao regra nao verificada"
      # `|| true`: sob `set -e` o diff que ACHA diferenca retorna 1 e mataria o
      # script aqui — transformando o aviso em bloqueio silencioso. Medido: o caso
      # desabilitado-divergente saia com exit 1 sem chamar `erro`.
      diff "$ESPERADO" "$PUBLICADO" | head -4 | sed 's/^/        /' || true
    else
      erro "[$NOME] HABILITADA e DIVERGENTE ($N_PUB publicadas vs $N_ESPERADO no repo)"
      diff "$ESPERADO" "$PUBLICADO" | head -6 | sed 's/^/        /' || true
    fi
  done
fi

# ---------------------------------------------------------------------------
echo ""
echo "[3/4] Nenhuma pipeline exporta telemetria por fora"
# ---------------------------------------------------------------------------
# ⚠️ O risco que o values.yaml registra: como config local e remota tem
# controladores separados, uma pipeline remota com exportador proprio tem caminho
# de saida PARALELO, que nunca passa pela nossa sanitizacao. Nao e hipotese —
# medido nesta frente: 82 series de kube_replicaset_owner (que a allowlist CORTA)
# chegaram na Grafana Cloud por um pipeline de teste com exportador proprio.
mapfile -t EXPORTADORES < <(python3 - "$RESP" <<'PY'
import json, re, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
for p in d.get("pipelines", []):
    c = p.get("contents","") or ""
    achados = set(re.findall(
        r'(prometheus\.remote_write|loki\.write|otelcol\.exporter\.\w+)', c))
    if achados:
        hab = p.get("enabled", True)
        print(f"{p.get('name','(sem nome)')}\t{'sim' if hab else 'nao'}\t{','.join(sorted(achados))}")
PY
)

if [ "${#EXPORTADORES[@]}" -eq 0 ]; then
  ok "nenhuma pipeline declara exportador"
else
  for linha in "${EXPORTADORES[@]}"; do
    IFS=$'\t' read -r NOME HAB COMPS <<< "$linha"
    if [ "$HAB" = "sim" ]; then
      erro "[$NOME] HABILITADA com exportador proprio: $COMPS"
      echo "        caminho de saida paralelo — nao passa pela sanitizacao local"
    else
      echo "  ⚠ [$NOME] desabilitada, com exportador: $COMPS"
    fi
  done
fi

# ---------------------------------------------------------------------------
echo ""
echo "[4/4] Filtro de metrica publicado — inventario, nao veredito"
# ---------------------------------------------------------------------------
# ⚠️ POR QUE ESTE PASSO NAO BLOQUEIA, ao contrario do passo 2.
#
# A allowlist de metricas PODE, por decisao do usuario (2026-08-30), ser gerida
# pelo Fleet: "se quiser ligar uma metrica, alterar metrica, ou qualquer outra
# coisa conseguimos alterar pelo Fleet, sem deploy em cliente — a ideia do Fleet
# e exatamente essa". Medido viavel: a ponte funciona tambem para metricas.
#
# Logo divergir do chart aqui e o COMPORTAMENTO ESPERADO, nao um defeito. Bloquear
# transformaria o recurso em impedimento.
#
# Mas a divergencia nao pode ser INVISIVEL: allowlist de metrica falha por
# EXCESSO — serie a mais e cobranca imediata na Grafana Cloud. E o perfil de risco
# oposto ao da regra de PII, que falha por omissao e em silencio.
#
# Entao este passo LISTA o que esta publicado, para que a revisao seja possivel.
# Quem publica assume o custo; o script garante que ele seja visivel.
mapfile -t FILTROS < <(python3 - "$RESP" <<'PY'
import json, re, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
for p in d.get("pipelines", []):
    c = p.get("contents","") or ""
    # componentes que decidem o que passa: relabel do caminho prometheus e
    # filter/transform do caminho OTLP aplicados a metrica
    if not re.search(r'prometheus\.relabel|otelcol\.processor\.filter', c):
        continue
    if 'replace_pattern(body' in c:   # ja coberto pelo passo 2
        continue
    hab = p.get("enabled", True)
    acoes = re.findall(r'action\s*=\s*"(\w+)"', c)
    regexes = re.findall(r'regex\s*=\s*"([^"]{0,60})', c)
    resumo = f"{len(acoes)} regra(s)"
    if regexes:
        resumo += f" | 1a: {regexes[0][:50]}..."
    print(f"{p.get('name','(sem nome)')}\t{'sim' if hab else 'nao'}\t{resumo}")
PY
)

if [ "${#FILTROS[@]}" -eq 0 ]; then
  ok "nenhum filtro de metrica publicado — a allowlist vem so do chart"
else
  for linha in "${FILTROS[@]}"; do
    IFS=$'\t' read -r NOME HAB RESUMO <<< "$linha"
    if [ "$HAB" = "sim" ]; then
      echo "  ⚠ [$NOME] ATIVO, filtrando metrica: $RESUMO"
      echo "      revise: metrica a mais e cobranca; metrica a menos e painel cego"
    else
      echo "  · [$NOME] publicado e desabilitado: $RESUMO"
    fi
  done
  echo "      (inventario — nao bloqueia, por decisao registrada)"
fi

echo ""
echo "=============================================="
if [ "$FALHAS" -eq 0 ]; then
  echo " ✓ LIBERADO — publicado confere com o repositorio"
  echo "=============================================="
  exit 0
else
  echo " ✗ BLOQUEADO — ${FALHAS} divergencia(s)"
  echo ""
  echo " Regra publicada que divergiu do repositorio nao foi"
  echo " verificada pela porta de entrega. Em producao"
  echo " error_mode e \"ignore\": regra malformada nao gera"
  echo " erro, so saida que aparenta estar mascarada."
  echo "=============================================="
  exit 1
fi
