#!/usr/bin/env python3
"""Monta o corpo JSON do CreatePipeline a partir da config renderizada.

Uso: publicar-fleet-corpo.py <arquivo-config> <nome-pipeline>

⚠️ A CONFIGURACAO E GLOBAL, e o matcher reflete isso: `role="node"` alcanca todos
os coletores daquele papel, em todos os clientes.

O que distingue um cliente do outro NAO e o matcher — e a variavel
ALLOY_CLIENT_ID do pod, resolvida por `sys.env` nos 8 pontos onde o client_id
aparece na config. VERIFICADO: renderizar com clientes diferentes produz saidas
byte a byte identicas.
"""
import json
import sys

if len(sys.argv) < 3:
    print("uso: publicar-fleet-corpo.py <config> <nome>", file=sys.stderr)
    sys.exit(2)

arquivo, nome = sys.argv[1:3]
conteudo = open(arquivo, encoding="utf-8").read()

print(json.dumps({
    "pipeline": {
        "name": nome,
        "contents": conteudo,
        # role="node" porque o singleton tem config e ciclo proprios.
        # SEM client_id: a config e global.
        "matchers": [
            'collector.os="linux"',
            'role="node"',
        ],
        "enabled": True,
    }
}))
