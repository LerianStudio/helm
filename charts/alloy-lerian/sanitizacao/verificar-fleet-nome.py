#!/usr/bin/env python3
"""Acha o nome da pipeline de configuração publicada, pelo prefixo.

Uso: verificar-fleet-nome.py <listpipelines.json> <prefixo>

Saída: o nome da pipeline mais recente que começa com `<prefixo>_`, ou nada.

⚠️ POR QUE EXISTE

O nome da configuração carrega a versão (`config_global_a1b2c3`), porque o agente
NÃO LIBERA o nome de um módulo que já carregou — republicar com o mesmo nome trava
com `a loader exists already`. Ver publicar-fleet-antigos.py.

A consequência é que o verificador não pode derivar o nome de um valor fixo: ele
tem de descobrir qual está publicado. A versão anterior derivava
`config_<client_id>`, de quando havia uma config por cliente com nome fixo, e
passou a procurar uma pipeline que nunca existe.

⚠️ "MAIS RECENTE" É POR ORDEM DE CRIAÇÃO, NÃO POR NOME

Durante a janela entre publicar a nova e remover a antiga, as duas casam o
prefixo. A que o agente vai carregar no próximo poll é a mais nova, então é ela
que deve ser comparada — comparar a antiga daria uma divergência falsa.

O campo de data varia conforme a versão da API, então tentamos os nomes
conhecidos e, na ausência de todos, caímos na ORDEM DA LISTA, que a API devolve
por criação. Não é garantia documentada; é o melhor sinal disponível, e o pior
caso é comparar a pipeline errada durante a janela de transição — que se resolve
no próximo `verificar`.
"""
import json
import sys

CAMPOS_DE_DATA = ("createdAt", "created_at", "updatedAt", "updated_at")


def main() -> int:
    if len(sys.argv) < 3:
        return 1

    arquivo, prefixo = sys.argv[1], sys.argv[2]

    try:
        dados = json.load(open(arquivo, encoding="utf-8"))
    except Exception:
        return 1

    candidatas = [
        p for p in dados.get("pipelines", [])
        if str(p.get("name", "")).startswith(prefixo + "_")
    ]
    if not candidatas:
        return 0

    # Preserva a ordem da lista como desempate final: `enumerate` entra na chave,
    # então sem campo de data a última da lista ganha.
    for i, p in enumerate(candidatas):
        p["_ordem"] = i

    def chave(p):
        for campo in CAMPOS_DE_DATA:
            if p.get(campo):
                return (1, str(p[campo]), p["_ordem"])
        return (0, "", p["_ordem"])

    print(max(candidatas, key=chave)["name"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
