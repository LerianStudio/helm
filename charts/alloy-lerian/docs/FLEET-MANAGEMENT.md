# Fleet Management — gestão remota de configuração

O chart já nasce com suporte completo, **desligado por padrão**. Ligar é mudar uma
flag e informar três valores — nenhuma edição de configuração no cluster do
cliente.

## Como ligar

```yaml
fleetManagement:
  enabled: true
  url: "https://fleet-management-<stack>.grafana.net"   # copiar VERBATIM da interface
  username: "1563949"                                    # id numérico da stack
  attributes:
    plataforma: kubernetes
```

E o Secret do token, antes do install:

```bash
kubectl -n monitoring create secret generic alloy-fleet-token \
  --from-literal=token='<token com escopo de leitura de config remota>'
```

O chart valida: com `enabled: true` e `url` ou `username` vazios, o render falha
com mensagem explicando o que falta.

## Não exige o operator

`remotecfg` é bloco de configuração do runtime do agente, não recurso de um
operator. O chart standalone é caminho suportado, e assim o `bind`/`escalate` que
o operator pediria no RBAC **fica fora do cluster**.

Ver `COMPONENTES-EXCLUIDOS.md` para o detalhe do privilégio que evitamos.

## Transporte

**Pull, HTTPS 443 de saída.** O agente pergunta ao serviço se há configuração
nova, no intervalo configurado. **Nada disca para dentro do cluster do cliente** —
é o que torna isso aceitável em rede de terceiro, sem VPN nem link privado.

Versão mínima do agente: v1.7.2. Usamos 1.18.1.

## Sanitização não pode ser desligada remotamente

Configuração local e remota têm **controladores de componente separados**. Da
documentação:

> "Local and remote configurations each have their own component controller, which
> means components loaded by one configuration are isolated from the other."
>
> "Local and remote configurations **cannot be in conflict**."

As regras de sanitização vivem na configuração **local**. Não há caminho pelo qual
uma configuração remota as desative, substitua ou remova. O isolamento é
arquitetural, não convenção.

Corolário: erro na configuração remota **não afeta** a local. Se nunca houver
configuração remota válida, o agente segue operando só com a local.

## ⚠️ O risco real é o oposto do óbvio

Do **mesmo** isolamento decorre o inverso: uma configuração remota também **não
consegue encaminhar para** a nossa sanitização local. Os controladores não se
referenciam.

Consequência: uma pipeline remota que declare o **próprio exportador** teria um
caminho de saída paralelo que **nunca passa pelo mascaramento**.

O perigo não é *"a remota desliga minha regra"*. É *"a remota cria um caminho que
ignora minha regra"*.

**Mitigação é de política, não de configuração:**

| Usar Fleet Management para | Não usar para |
|---|---|
| Coleta e descoberta | Declarar exportadores |
| Ajuste de perímetro e de intervalo | Qualquer caminho de saída próprio |
| Habilitar e desabilitar receptores | Pipeline que envie telemetria direto |

Toda pipeline remota que exporte telemetria deve passar por revisão explícita. A
exportação deve permanecer local.

## Identidade do collector

O identificador é composto da marca de procedência mais o nome do pod, injetado
da metadata do objeto:

```
<origem>-<nome-do-pod>
```

**Por que não o padrão.** Se `id` é omitido, o agente gera um UUID e o persiste no
seu diretório de armazenamento. Em pod efêmero sem volume, isso é perdido a cada
reinício — produzindo identidade nova toda vez e churn no registro da frota.

`constants.hostname` também não serve: num DaemonSet resolveria para o nó, não
para o pod.

## ⚠️ Atributos: use os remotos para segmentação com significado de segurança

Existem três categorias:

| Categoria | Quem define | Pode ser falsificado |
|---|---|---|
| Reservados (`collector.os`, `collector.version`, `collector.ID`) | O serviço injeta | **Não** — a documentação afirma que não podem ser sobrescritos |
| Locais | O agente declara | **Sim** — auto-declarados, sem validação de conteúdo documentada |
| Remotos | Definidos na interface | Não, e **têm precedência** sobre os locais |

**Consequência para modelo multi-cliente:** se a segmentação de pipeline depender
de atributo **local**, um agente mal configurado poderia declarar o atributo de
outro cliente e receber configuração alheia. Para qualquer matching com
significado de segurança, use atributos **remotos**.

## ⚠️ Isolamento entre clientes é por STACK, não por pipeline

O controle de acesso do Fleet Management tem duas papéis, ambas com escopo da
aplicação inteira dentro da stack:

- **Reader** — vê collectors, atributos e pipelines
- **Admin** — escopo irrestrito no app

**Não há escopo por pipeline nem por collector.** Com N clientes na mesma stack,
quem tem leitura vê a configuração de **todos**.

Particionamento dentro de uma stack **não está documentado**, e a evidência aponta
para inexistente. Se o isolamento entre clientes importar, o caminho arquitetural
é **uma stack por cliente** — não controle de acesso dentro de uma.

Decidir isso **antes** de habilitar em ambiente de cliente.

## O que fica obrigatoriamente local

Configuração remota é **módulo**, não configuração de topo. Estes blocos
permanecem locais:

- `logging`, `tracing`
- `remotecfg` (o próprio bloco)
- parâmetros do servidor HTTP

Somado à política de exportação local, isso define a fronteira do que a gestão
remota alcança.

## Verificação executada

Validado contra o binário v1.18.1, não apenas renderizado:

| Cenário | Resultado |
|---|---|
| Desligado | zero blocos `remotecfg`; config idêntica à anterior |
| Ligado, token falso | `unauthenticated: invalid token` — **o bloco foi parseado e executado** |
| Ligado, endpoint inexistente | falha de DNS, não de parse — confirma que a sintaxe é válida |
| `enabled: true` sem `url` | render falha com mensagem explicando |
| `enabled: true` sem `username` | render falha com mensagem explicando |

O erro de autenticação é a prova positiva: o agente chegou a tentar autenticar,
o que só ocorre se o bloco for sintaticamente válido.
