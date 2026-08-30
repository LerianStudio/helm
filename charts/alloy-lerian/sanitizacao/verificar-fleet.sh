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
echo "[1/5] Pipelines publicadas sao alcancaveis"
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
echo "[2/5] Toda pipeline habilitada com regra de PII confere com o repositorio"
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
echo "[3/5] Nenhuma pipeline exporta telemetria por fora"
# ---------------------------------------------------------------------------
# ⚠️ O risco que o values.yaml registra: como config local e remota tem
# controladores separados, uma pipeline remota com exportador proprio tem caminho
# de saida PARALELO, que nunca passa pela nossa sanitizacao. Nao e hipotese —
# medido nesta frente: 82 series de kube_replicaset_owner (que a allowlist CORTA)
# chegaram na Grafana Cloud por um pipeline de teste com exportador proprio.
#
# ⚠️ MAS O CRITERIO NAO E "TER" EXPORTADOR — E PARA ONDE ELE APONTA. Corrigido em
# 2026-08-30, depois de esta verificacao bloquear a ponte funcionando corretamente.
#
# O modo ponte EXIGE um exportador: o modulo publicado recebe o log, mascara, e
# precisa DEVOLVER ao fluxo local. Sem exportador nao ha devolucao. A regra
# anterior tratava isso como fuga — contradicao minha, por ter escrito o passo 3
# antes de projetar a ponte e nao ter revisado.
#
# A distincao que importa:
#
#   localhost:<porta de retorno>  -> volta ao fluxo local, e passa por perimetro,
#                                    agrupamento e allowlist depois. LEGITIMO.
#   qualquer endereco externo     -> sai do pod e escapa de tudo. FUGA.
#   localhost:<outra porta>       -> nao ha receptor la. Erro ou desvio. BLOQUEIA.
#
# Mesmo componente, papeis opostos. A regra ficou MAIS PRECISA, nao mais frouxa:
# tudo que era bloqueado continua sendo, menos o caso em que o dado comprovadamente
# retorna para dentro do pipeline local.
#
# ⚠️ LIMITE CONHECIDO: se o modulo exportar para a porta de retorno mas o chart
# estiver com a ponte DESLIGADA, nao ha receptor la — o dado fica retido e nunca
# chega. Este passo aprova (o destino e legitimo) e nao detecta. Quem detecta e o
# alerta O11Y-LOG-001, por log ausente.
PORTA_RETORNO="${PORTA_RETORNO_PONTE:-4320}"

# ⚠️ O DESTINO ESPERADO vem do proprio chart, nao de um valor fixo aqui. Com a
# config completa no Fleet, a pipeline publicada EXPORTA para o nosso destino — e
# isso e o funcionamento normal. Fuga e apontar para OUTRO lugar.
#
# Extrair do values evita que este script e o chart discordem sobre qual e o
# destino legitimo.
DESTINO_ESPERADO="${DESTINO_ESPERADO:-$(python3 - "${RAIZ}/../examples/values-cliente.yaml" <<'PYX'
import sys, yaml
try:
    v = yaml.safe_load(open(sys.argv[1], encoding="utf-8")) or {}
    print((v.get("destination") or {}).get("endpoint", ""))
except Exception:
    print("")
PYX
)}"

mapfile -t EXPORTADORES < <(PORTA="$PORTA_RETORNO" DESTINO_ESPERADO="$DESTINO_ESPERADO" \
  python3 "${RAIZ}/verificar-fleet-saidas.py" "$RESP")

if [ "${#EXPORTADORES[@]}" -eq 0 ]; then
  ok "nenhuma pipeline declara exportador com saida"
else
  for linha in "${EXPORTADORES[@]}"; do
    IFS=$'\t' read -r NOME HAB PAPEL DETALHE <<< "$linha"
    if [ "$PAPEL" = "legitimo" ]; then
      ok "[$NOME] $DETALHE"
    elif [ "$HAB" = "sim" ]; then
      erro "[$NOME] HABILITADA com saida externa: $DETALHE"
      echo "        caminho paralelo — escapa da allowlist e do perimetro locais"
    else
      echo "  ⚠ [$NOME] desabilitada, com saida externa: $DETALHE"
    fi
  done
fi

# ---------------------------------------------------------------------------
echo ""
echo "[4/5] Filtro de metrica publicado — inventario, nao veredito"
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

# ---------------------------------------------------------------------------
echo ""
echo "[5/5] Configuracao publicada identica ao render do chart"
# ---------------------------------------------------------------------------
# ⚠️ O passo 2 confere as REGRAS DE PII. Este confere a CONFIG INTEIRA, e a
# diferenca importa: com a configuracao completa vindo do Fleet, regras corretas
# nao garantem o resto — allowlist, perimetro, filtro de ruido e destino tambem
# vem de la.
#
# Allowlist editada na console nao e vazamento; e COBRANCA IMEDIATA na Grafana
# Cloud. O passo 2 nao a veria.
#
# ⚠️ E ha um segundo motivo: a config publicada e o gemeo do ConfigMap local, que
# e o artefato de DR (`fleetManagement.enabled: false`). Divergindo, o DR
# restauraria uma versao desatualizada — o problema que o Fleet existe para
# resolver.
#
# So roda se CLIENT_ID estiver definido: sem ele nao ha como saber qual pipeline
# comparar nem com que `origin.id` renderizar.
if [ -z "${CLIENT_ID:-}" ]; then
  echo "  · CLIENT_ID nao definido — comparacao da config completa ignorada"
  echo "    Defina CLIENT_ID para conferir a config inteira, nao so as regras."
else
  NOME_CFG="config_$(echo "$CLIENT_ID" | tr '[:upper:]-' '[:lower:]_')"
  RENDER="$(mktemp)"
  VALUES_BASE="${VALUES_BASE:-${RAIZ}/../examples/values-cliente.yaml}"
  if helm template verificar "${RAIZ}/.." -f "$VALUES_BASE" \
        --set "origin.id=${CLIENT_ID}" 2>/dev/null \
      | python3 "${RAIZ}/publicar-fleet-extrair.py" > "$RENDER" 2>/dev/null; then
    if SAIDA=$(python3 "${RAIZ}/verificar-fleet-diff.py" "$RESP" "$NOME_CFG" "$RENDER"); then
      ok "[$NOME_CFG] config publicada identica ao render"
    else
      erro "[$NOME_CFG] config publicada DIVERGE do render do chart"
      echo "$SAIDA" | sed 's/^/      /'
      echo "      Republique com sanitizacao/publicar-fleet.sh — editar pela"
      echo "      console contorna a porta de entrega."
    fi
  else
    echo "  ⚠ nao foi possivel renderizar o chart para comparar"
  fi
  rm -f "$RENDER"
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
