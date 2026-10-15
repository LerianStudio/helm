#!/usr/bin/env python3
"""Extrai a config do papel `node` do render do chart, para publicar no Fleet.

Le o YAML do `helm template` em stdin e escreve em stdout apenas o conteudo do
ConfigMap do papel node — que e a configuracao de coleta propriamente dita.

⚠️ SO O PAPEL NODE. O singleton (eventos de cluster) tem config propria e outro
ciclo de vida; publicar os dois juntos criaria dois agentes tentando as mesmas
portas. Se o singleton for para o Fleet, sera uma pipeline separada, com matcher
`role="singleton"`.
"""
import sys

import yaml


# ⚠️ BLOCOS DE SERVICO NAO SAO PERMITIDOS DENTRO DE UM MODULO, e o Fleet embrulha
# cada pipeline num `declare`. MEDIDO contra o agente v1.18.1:
#
#   logging       -> "logging block not allowed inside a module"
#   livedebugging -> idem
#   remotecfg     -> idem
#
# (Componentes normais, como `otelcol.exporter.debug`, sao permitidos.)
#
# Isso NAO e perda: os tres sao configuracao do PROCESSO, nao da coleta, e
# continuam vindo do ConfigMap local — que o chart renderiza de qualquer forma.
# O `remotecfg` em particular TEM de ficar local: e ele que busca esta config.
BLOCOS_DE_SERVICO = ("logging", "livedebugging", "remotecfg")


def remover_blocos_de_servico(conteudo: str) -> str:
    """Remove blocos de servico do topo, que o modulo do Fleet nao aceita."""
    saida = []
    profundidade = 0
    pulando = False
    for linha in conteudo.splitlines(keepends=True):
        if not pulando and profundidade == 0:
            primeiro = linha.strip().split(" ")[0].split("{")[0]
            if primeiro in BLOCOS_DE_SERVICO and "{" in linha:
                pulando = True
        if pulando:
            profundidade += linha.count("{") - linha.count("}")
            if profundidade <= 0:
                pulando = False
                profundidade = 0
            continue
        saida.append(linha)
    return "".join(saida)


def main() -> int:
    try:
        documentos = list(yaml.safe_load_all(sys.stdin))
    except yaml.YAMLError as e:
        print(f"erro ao ler o YAML do render: {e}", file=sys.stderr)
        return 1

    for doc in documentos:
        if not doc or doc.get("kind") != "ConfigMap":
            continue
        for chave, conteudo in (doc.get("data") or {}).items():
            if not isinstance(conteudo, str):
                continue
            # O papel node e o unico que recebe telemetria por OTLP e sanitiza.
            # O singleton nao tem receptor OTLP — ele coleta eventos da API do K8s.
            if "receiver.otlp" in conteudo and "sanitizacao" in conteudo:
                sys.stdout.write(remover_blocos_de_servico(conteudo))
                return 0

    print(
        "nenhum ConfigMap com a config do papel node encontrado no render",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
