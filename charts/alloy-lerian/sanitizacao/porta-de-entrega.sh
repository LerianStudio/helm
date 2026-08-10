#!/usr/bin/env bash
# PORTA DE ENTREGA — sanitizacao de dado regulado.
#
# Bloqueia a entrega quando qualquer regra de sanitizacao falha, ou quando
# alguma regra nao tem cobertura de teste completa.
#
# Por que e bloqueante e nao advertencia: em producao as regras rodam com
# error_mode "ignore". Regra malformada NAO gera erro — produz saida que
# aparenta estar mascarada (verificado: a notacao $$1 emite "$1***" literal,
# sem qualquer aviso). Uma advertencia aqui seria ignorada e o dado vazaria.
#
# Uso:  ./porta-de-entrega.sh
# Saida: 0 = liberado. Diferente de 0 = BLOQUEADO.
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLOQUEIOS=0

erro() { echo "  ✗ $*"; BLOQUEIOS=$((BLOQUEIOS+1)); }
ok()   { echo "  ✓ $*"; }

# Extrai apenas as LINHAS DE CODIGO das regras, descartando comentarios.
# Necessario porque os comentarios documentam justamente as construcoes
# proibidas (ex: "NUNCA $$1", "falha com (?!") — inspecionar o arquivo cru
# produziria falso positivo em toda execucao.
codigo_das_regras() {
  grep -vE '^[[:space:]]*//' "${RAIZ}/regras.alloy"
}

echo "=============================================="
echo " PORTA DE ENTREGA — sanitizacao"
echo "=============================================="

# ---------------------------------------------------------------------------
echo ""
echo "[1/6] Regras usam a notacao de retrovinculacao verificada"
# ---------------------------------------------------------------------------
# A notacao correta e $1. A incorreta ($$1) emite texto literal SEM erro.
if codigo_das_regras | grep -q '\$\$[0-9]'; then
  erro "encontrada notacao \$\$N — a correta e \$N (ver EVIDENCIA-retrovinculacao.md)"
  codigo_das_regras | grep -n '\$\$[0-9]' | sed 's/^/      /'
else
  ok "nenhuma ocorrencia de \$\$N"
fi

# ---------------------------------------------------------------------------
echo ""
echo "[2/6] Nenhuma funcao editora aninhada em set()"
# ---------------------------------------------------------------------------
# replace_pattern e funcao EDITORA: aninhar em set() falha na CARGA.
if codigo_das_regras | grep -qE 'set\([^)]*\b(replace_pattern|replace_all_patterns|delete_key)\('; then
  erro "funcao editora aninhada em set() — falha na carga do agente"
  codigo_das_regras | grep -nE 'set\([^)]*\b(replace_pattern|replace_all_patterns|delete_key)\(' | sed 's/^/      /'
else
  ok "nenhum aninhamento indevido"
fi

# ---------------------------------------------------------------------------
echo ""
echo "[3/6] Nenhuma construcao de regex nao suportada"
# ---------------------------------------------------------------------------
# O motor desta versao nao suporta lookahead nem lookbehind (falha na CARGA).
if codigo_das_regras | grep -qE '\(\?[=!<]'; then
  erro "lookahead/lookbehind encontrado — nao suportado pelo motor de regex"
  codigo_das_regras | grep -nE '\(\?[=!<]' | sed 's/^/      /'
else
  ok "nenhuma construcao nao suportada"
fi

# ---------------------------------------------------------------------------
echo ""
echo "[4/6] Cobertura: cada classe tem as 4 categorias obrigatorias"
# ---------------------------------------------------------------------------
# A lista de classes e DERIVADA dos arquivos de caso, nao fixada aqui.
#
# Por que: com a lista fixa, uma classe nova entrava sem nenhuma exigencia de
# cobertura — a porta liberava porque nao sabia que a classe existia. Medido:
# a classe 'credencial' passou com 4 categorias por acaso, e teria passado
# igualmente com uma so. Uma porta que so verifica o que ja conhece nao protege
# contra o proximo acrescimo, que e justamente quando o erro acontece.
#
# 'interacao-*' e 'risco-*' sao casos transversais, nao classes: nomeiam
# cenarios entre classes e nao seguem o eixo de 4 categorias.
CATEGORIAS=(canonico forma-alternativa ausente preservacao-fragmento)
mapfile -t CLASSES < <(
  find "${RAIZ}/casos" -name '*.json' ! -name '*.esperado.json' -printf '%f\n' \
    | sed 's/\.json$//' \
    | grep -vE '^(interacao|risco)-' \
    | sed -E "s/-($(IFS='|'; echo "${CATEGORIAS[*]}"))$//" \
    | sort -u
)

if [ ${#CLASSES[@]} -eq 0 ]; then
  erro "nenhuma classe encontrada em casos/ — a derivacao falhou"
fi

for classe in "${CLASSES[@]}"; do
  faltando=()
  for cat in "${CATEGORIAS[@]}"; do
    if [ ! -f "${RAIZ}/casos/${classe}-${cat}.json" ] || \
       [ ! -f "${RAIZ}/casos/${classe}-${cat}.esperado.json" ]; then
      faltando+=("$cat")
    fi
  done
  if [ ${#faltando[@]} -gt 0 ]; then
    erro "classe '${classe}' sem as categorias: ${faltando[*]}"
  else
    ok "classe '${classe}': 4/4 categorias"
  fi
done

# A categoria de preservacao de fragmento e a UNICA que detecta notacao errada.
# Verifica que o esperado dessas categorias NAO contem notacao literal.
for f in "${RAIZ}"/casos/*-preservacao-fragmento.esperado.json; do
  [ -e "$f" ] || continue
  # Le APENAS o campo body — o campo descricao menciona a notacao de proposito.
  if jq -r '.body' "$f" | grep -qE '\$[0-9]'; then
    erro "$(basename "$f"): o campo body contem notacao \$N — deve conter o FRAGMENTO, nao a notacao"
  fi
done

# ---------------------------------------------------------------------------
echo ""
echo "[5/6] Todos os casos passam contra o agente real"
# ---------------------------------------------------------------------------
if [ ! -x "${RAIZ}/verificar.sh" ]; then
  erro "verificar.sh ausente ou nao executavel"
else
  saida_verif="$("${RAIZ}/verificar.sh" 2>&1)" && resultado=0 || resultado=$?
  linha_final="$(printf '%s' "$saida_verif" | tail -1)"
  if [ "$resultado" -eq 0 ]; then
    ok "${linha_final}"
  else
    erro "verificacao falhou: ${linha_final}"
    printf '%s' "$saida_verif" | grep -A3 '^FALHA' | sed 's/^/      /'
  fi
fi

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
echo ""
echo "[6/6] Regras do arcabouco identicas as do template do chart"
# ---------------------------------------------------------------------------
# Sem isto o arcabouco poderia validar um conjunto de regras enquanto producao
# usa outro: o teste passaria e o dado vazaria.
TEMPLATE="${RAIZ}/../templates/_sanitizacao.tpl"
extrai() { grep -oE 'replace_pattern\(body, "[^"]+", "[^"]*"\)' "$1" | sort; }
if [ ! -f "$TEMPLATE" ]; then
  ok "template ausente (execucao fora do chart) - verificacao ignorada"
elif diff -q <(extrai "$TEMPLATE") <(extrai "${RAIZ}/regras.alloy") >/dev/null 2>&1; then
  ok "$(extrai "$TEMPLATE" | wc -l | tr -d ' ') regra(s) identicas ao template"
else
  erro "as regras do arcabouco DIVERGEM do template do chart"
  diff <(extrai "$TEMPLATE") <(extrai "${RAIZ}/regras.alloy") | head -6 | sed 's/^/      /'
fi


echo ""
echo "=============================================="
if [ "$BLOQUEIOS" -eq 0 ]; then
  echo " ✓ LIBERADO — sanitizacao verificada"
  echo "=============================================="
  exit 0
else
  echo " ✗ BLOQUEADO — ${BLOQUEIOS} verificacao(oes) falharam"
  echo ""
  echo " A entrega NAO pode prosseguir. Regra de sanitizacao"
  echo " malformada nao gera erro em producao — produz saida"
  echo " que aparenta estar mascarada."
  echo "=============================================="
  exit 1
fi
