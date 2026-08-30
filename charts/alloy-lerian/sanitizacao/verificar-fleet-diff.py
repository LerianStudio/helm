#!/usr/bin/env python3
"""Compara a configuração publicada no Fleet com o render do chart.

Uso: verificar-fleet-diff.py <listpipelines.json> <nome> <config-renderizada>

⚠️ POR QUE COMPARAR A CONFIG INTEIRA, e não só as regras de PII.

Com a configuração completa vindo do Fleet, as regras corretas não garantem o
resto: allowlist, perímetro, filtro de ruído e destino também vêm de lá. Uma
allowlist editada na console não é vazamento — é **cobrança imediata** na Grafana
Cloud, e o passo que só olha PII não a veria.

⚠️ E há um segundo motivo, menos óbvio: a config publicada é o gêmeo do ConfigMap
local, que é o artefato de DR. Se divergirem, o DR restaura uma versão
desatualizada — exatamente o problema que o Fleet existe para resolver.

Saída: nada se idênticas; o diff resumido se diferem. Código 0 / 1.
"""
import difflib
import json
import re
import sys

# Linhas que mudam legitimamente entre render e publicado, e não devem contar como
# divergência: o cabeçalho de proveniência carrega o commit de origem.
RUIDO = re.compile(r"^\s*//\s*(origem|regras|GERADO|Managed by):", re.I)


def normalizar(texto: str) -> list[str]:
    """Reduz a linha ao que importa comparar.

    ⚠️ A INDENTAÇÃO É NORMALIZADA, e não por preguiça: MEDIDO que o Fleet converte
    espaços em TABS ao armazenar a configuração. Comparar byte a byte acusaria
    divergência em toda linha indentada — falso positivo em 595 de 595 linhas.

    O que sobra é o conteúdo semântico: se uma regra, um endpoint ou uma allowlist
    mudou, a diferença aparece. Se só o recuo mudou, não.
    """
    saida = []
    for linha in texto.splitlines():
        if not linha.strip():
            continue
        if RUIDO.match(linha):
            continue
        # colapsa qualquer sequência de espaço/tab em um único espaço
        saida.append(re.sub(r"\s+", " ", linha).strip())
    return saida


def main() -> int:
    if len(sys.argv) < 4:
        print("uso: verificar-fleet-diff.py <resp.json> <nome> <render>", file=sys.stderr)
        return 2

    resp, nome, arquivo_render = sys.argv[1:4]

    try:
        dados = json.load(open(resp, encoding="utf-8"))
    except Exception as e:
        print(f"nao foi possivel ler a resposta do Fleet: {e}", file=sys.stderr)
        return 2

    publicado = None
    for pipeline in dados.get("pipelines", []):
        if pipeline.get("name") == nome:
            publicado = pipeline.get("contents", "") or ""
            break

    if publicado is None:
        print(f"pipeline '{nome}' nao existe no Fleet")
        return 1

    render = open(arquivo_render, encoding="utf-8").read()

    a, b = normalizar(render), normalizar(publicado)
    if a == b:
        return 0

    # Resumo, não o diff inteiro: 655 linhas de saída esconderiam o que importa.
    print(f"divergencia: render tem {len(a)} linhas, publicado tem {len(b)}")
    n = 0
    for linha in difflib.unified_diff(a, b, "render", "publicado", lineterm="", n=1):
        if linha.startswith(("+++", "---", "@@")):
            continue
        if linha.startswith(("+", "-")):
            print(f"  {linha[:150]}")
            n += 1
            if n >= 12:
                print("  [...]")
                break
    return 1


if __name__ == "__main__":
    sys.exit(main())
