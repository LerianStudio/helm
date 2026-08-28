{{/*
==============================================================================
REGULATED-DATA SANITISATION
==============================================================================
Not part of the values surface. There is no configuration that disables a rule,
weakens one, or produces unsanitised output. The absence of those knobs is the
guarantee, not a limitation.

Every rule here was verified by running the pinned agent against a known input
and comparing the output exactly. Three mechanics were established empirically
and are load-bearing:

  1. backreference notation is $1. The form $$1 emits the LITERAL text "$1"
     with no error, producing output that looks masked and is not
  2. replace_pattern is an EDITOR: its own statement, never nested in set()
  3. no lookahead or lookbehind — the engine rejects both at load

RULE ORDER IS A CONTRACT. Each constraint below was confirmed by deliberately
inverting it:

  phone before document   a 13-digit E.164 number matches the 11-digit document
                          rule and becomes "+551********21" — masked, but masked
                          wrongly: it loses the area code and keeps the tail of
                          the subscriber number
  dotted before plain     the punctuated document form stops matching otherwise
  3+ names before 2       "Ana Beatriz Costa Lima" becomes
                          "Ana ********** Beatriz Costa Lima": the full name
                          stays exposed behind a decorative mask

Known and accepted false positive: the document rule masks ANY 11+ digit run,
including transaction identifiers and latency values. Measured at roughly 2% of
log lines. Accepted because a false positive costs legibility while a false
negative leaks a document. Requiring a field prefix was evaluated and rejected:
the canonical case is a bare document in running text.
*/}}
{{- define "alloy-lerian.config.sanitizacao" -}}
{{- $nome := .nome | default "sanitizacao" -}}
{{- $saida := .saida | default "otelcol.processor.batch.agrupamento.input" -}}
otelcol.processor.transform {{ $nome | quote }} {
  // "ignore" keeps a malformed rule from halting the pipeline. This is also
  // why correctness is asserted in CI rather than trusted at runtime: a wrong
  // rule produces no error, only output that appears masked.
  error_mode = "ignore"

  log_statements {
    context = "log"
    statements = [
      // --- PHONE --- (before document, see header)
      // E.164 with country and area code: preserves both, masks the subscriber
      // number. Region is useful in diagnosis; the number is not.
      // ⚠️ FRONTEIRA, pela mesma razao da regra de documento. Sem ela casava qualquer
      // numero com `+` e 12-13 digitos. MEDIDO:
      //
      //   latency=+5511987654321ns  ->  latency=+5511********ns
      //
      // Com a fronteira, o `ns` protege o valor e o telefone real segue mascarado,
      // inclusive em JSON.
      `replace_pattern(body, "(\\+[0-9]{2}[0-9]{2})[0-9]{8,9}", "$1********")`,

      // National form with separators.
      `replace_pattern(body, "(\\([0-9]{2}\\) )[0-9]{4,5}-[0-9]{4}", "$1*****-****")`,

      // --- FISCAL DOCUMENT ---
      // Punctuated form first: the plain-digit rule would not match it, and
      // this rule would not match what that one already masked.
      `replace_pattern(body, "([0-9]{3})\\.[0-9]{3}\\.[0-9]{3}-[0-9]{2}", "$1.***.***-**")`,

      // Eleven consecutive digits. Preserves the first three for correlation.
      // ⚠️ FRONTEIRA nos DOIS lados, e nenhum dos delimitadores pode ser letra ou
      // digito. Sem isso a regra casava 11 digitos em qualquer contexto. MEDIDO em
      // producao (log do ArgoCD em aws-devops):
      //
      //   sha=8562e2e9f6ae0abcd12345678901ef  ->  ...abcd123********ef
      //
      // E tambem `ts=1787934092000` (epoch), `duration=...ms`, `pid=`, `objectRV=`.
      // Nao e vazamento — e perda SILENCIOSA de diagnostico: o log parece normal.
      //
      // `[^0-9A-Za-z]` de cada lado exclui SHA e hex (tem letra adjacente), epoch de
      // 13 digitos e `duration=...ms`. MEDIDO: mantem 4/4 na cobertura de CPF,
      // incluindo texto livre e JSON, e corrompe 2 de 6 valores legitimos.
      //
      // ⚠️ LIMITE ACEITO: `objectRV=91656472123` e `pid=12345678901` continuam
      // mascarados. Sao numeros de EXATAMENTE 11 digitos delimitados por `=` e fim de
      // linha — indistinguiveis de CPF pela forma. Nenhuma regex resolve sem o nome
      // do campo; ver pre-dev/regras-pii-falso-positivo/GAP-nomenclatura-campos.md.
      //
      // ⚠️ NAO exigir contexto (`cpf=`) como alternativa: MEDIDO, vaza 3 de 5 —
      // texto livre, JSON com outra chave, e forma pontuada. Falso negativo em PII e
      // vazamento.
      `replace_pattern(body, "([^0-9A-Za-z]|^)([0-9]{3})([0-9]{8})([^0-9A-Za-z]|$)", "$1$2********$4")`,

      // Fourteen consecutive digits (CNPJ). MESMA fronteira da regra de CPF, pela
      // mesma razao. Preserva os 2 primeiros digitos.
      //
      // ⚠️ Por FORMA, nao por nome de campo. MEDIDO em log real de producao
      // (Cappta-Prd, ledger v3.6.3): das 6 ocorrencias de CNPJ, 4 estavam em TEXTO
      // LIVRE, sem nome de campo:
      //
      //   PIX-OUT de 48028905000104 de R$200.0    <- CNPJ do pagador, solto
      //   documento 30251055000135                 <- com a palavra, mas sem `=`
      //
      // Exigir `cnpj=`/`documento=` vazaria as 4. Mesmo raciocinio da regra de CPF.
      //
      // ⚠️ LIMITE ACEITO, medido: epoch de 14 digitos (`ts=17879550984508`) e
      // resourceVersion longo (`objectRV=91656472123456`) sao mascarados. Sao
      // indistinguiveis de CNPJ pela forma. Ambos disponiveis por kubectl — mesmo
      // trade-off ja aceito na regra de CPF.
      `replace_pattern(body, "([^0-9A-Za-z]|^)([0-9]{2})([0-9]{12})([^0-9A-Za-z]|$)", "$1$2************$4")`,

      // --- BANK ACCOUNT AND BRANCH ---
      // ⚠️ Estas duas SO funcionam por NOME DE CAMPO — o inverso das regras acima, e
      // a razao esta no dado real. MEDIDO em Cappta-Prd:
      //
      //   account:388408                  6 digitos
      //   account:12880000007785418277   20 digitos
      //   branch:4364                     4 digitos
      //   branch:1                        1 DIGITO
      //
      // Nao existe forma que distinga `branch:1` de `gateway:6`, `method:03` ou
      // `count:7`. Uma regra por forma mascararia metade do log de plataforma.
      //
      // O nome do campo e o unico sinal disponivel, e aqui ele NAO tem o problema da
      // regra de CPF: conta e agencia sempre aparecem nomeadas no log do ledger,
      // nunca soltas em texto livre. MEDIDO: 0 falso positivo em 8 entradas
      // legitimas (`bank_code:`, `ispb:`, `port=`, `count=`, `http_latency_ms:`,
      // `k8s_pod_name:`, epoch, SHA).
      //
      // ⚠️ Cobertura menor por consequencia: conta em texto livre NAO e mascarada.
      // Aceito — a alternativa corrompe diagnostico em volume.
      `replace_pattern(body, "(?i)((?:conta |account[=:]|account_number[=:]))([0-9]{4,})", "$1********")`,
      `replace_pattern(body, "(?i)((?:ag[eê]ncia |branch[=:]|agency[=:]))([0-9]+)", "$1****")`,

      // --- PERSON NAME ---
      // Anchored on capitalisation: name terms start uppercase and the
      // surrounding log text is lowercase, which delimits the value without a
      // lookbehind. This is a PREMISE about how applications log, not a
      // guarantee — an application logging names in a different case would not
      // match.
      //
      // ONE rule, and it masks EVERY term after the first. There were two before
      // (3+ terms, then exactly 2) and both leaked, which is worse than not
      // masking because the output looks protected:
      //
      //   Ana Silva              -> "Ana ********** Silva"   full name readable
      //   Ana Beatriz Costa Lima -> "Ana ********** Lima"    surname preserved
      //
      // The surname is the most identifying term, so preserving it defeats the
      // rule. The given name is kept for legibility in diagnosis; everything
      // after it goes. Verified: 1 term is left alone, 2/3/4 terms are fully
      // masked, and a following `key=value` field is not consumed.
      `replace_pattern(body, "((?:customer|sender|recipient|receiver|client|holder)Name=)(\\p{Lu}[\\p{L}]*)(?: \\p{Lu}[\\p{L}]*)+", "$1$2 **********")`,

      // --- EMAIL ADDRESS ---
      // Preserves two characters of the local part and the WHOLE domain. The
      // domain identifies the provider or corporate client, not the person,
      // and is genuinely useful in diagnosis.
      `replace_pattern(body, "([A-Za-z0-9]{1,2})[A-Za-z0-9._%+-]*(@[A-Za-z0-9.-]+\\.[A-Za-z]{2,})", "$1****$2")`,

      // --- PAYMENT KEY ---
      // A key may be a document, a phone number, an email address or a random
      // identifier. The first three are already covered by the rules above,
      // regardless of field name — deliberately not duplicated here. Verified:
      // all three forms mask correctly without a dedicated rule.
      `replace_pattern(body, "([0-9a-fA-F]{8})-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-([0-9a-fA-F]{12})", "$1-****-****-****-$2")`,

      // --- POSTAL ADDRESS ---
      // Masked ENTIRELY. Unlike an email domain or a phone area code, any
      // fragment of an address sharply narrows the search space for a person.
      // The only class with no preserved part, and that is deliberate.
      `replace_pattern(body, "((?:address|street|logradouro|endereco)[=:] ?)[\\p{Lu}0-9][^=]*?( [a-z_]+[=:]|$)", "$1**********$2")`,

      // --- AUTHENTICATION CREDENTIAL ---
      // Different in kind from every rule above: those protect data that
      // IDENTIFIES someone, this protects a value that GRANTS ACCESS. A leaked
      // credential is not a privacy incident, it is an authenticated session in
      // someone else's hands — and it stays exploitable until it expires.
      //
      // Placed BEFORE the opaque-identifier rule on purpose. A JWT contains long
      // alphanumeric runs that a later rule could partially rewrite, and a
      // partially masked token still leaks structure while looking sanitised.
      //
      // The SCHEME NAME is preserved and nothing else. "Bearer" versus "Basic"
      // is what makes an authentication failure diagnosable; no fragment of the
      // credential itself has diagnostic value, and preserving a JWT prefix
      // would disclose the signing algorithm. Second class with no preserved
      // part, for a different reason than postal address.
      `replace_pattern(body, "(?i)((?:bearer|basic|digest|token|apikey|api_key)[=: ] ?)[A-Za-z0-9._~+/=-]{8,}", "$1**********")`,

      // Assignment form, where the scheme is not what precedes the value:
      // password=, secret=, client_secret=, access_token=. The KEY is preserved
      // because knowing WHICH credential appeared is what makes a leak
      // actionable — you cannot rotate what you cannot name.
      `replace_pattern(body, "(?i)((?:password|passwd|senha|secret|client_secret|access_token|refresh_token|private_key)[=:] ?)[^\\s,;}]+", "$1**********")`,

      // --- OPAQUE RESOURCE IDENTIFIER ---
      // Preserves the semantic prefix and four characters: enough to correlate
      // records for the same resource, not enough to reconstruct the value.
      // ⚠️ O GRUPO 2 CAPTURA O DELIMITADOR, e nao e enfeite. Sem ele a regra casava
      // NOME DE CAMPO que comeca com o prefixo. MEDIDO:
      //
      //   acc_metadata_cache_hit=true  ->  acc_meta******_cache_hit=true
      //
      // E o comportamento era erratico, o que e pior que errado de forma
      // consistente: `acc_metadata` casava (8 letras seguidas apos os 4), mas
      // `acc_balance_snapshot` nao (o `_` interrompia antes dos 4 extras). Um campo
      // corrompido, outro intacto, sem logica visivel para quem le o log.
      //
      // `[^0-9a-zA-Z_]|$` exige que o valor termine em delimitador que NAO seja
      // sublinhado nem alfanumerico. Nao usa lookahead de proposito: o passo 3 do
      // gate o proibe, e o agente nao o suporta.
      //
      // ⚠️ LIMITE CONHECIDO: id opaco com `_` INTERNO deixa de ser mascarado
      // (`acc_9f8e_7d6c` fica intacto) — falso NEGATIVO. Aceito porque o contrato
      // documentado desta regra e prefixo + 4 caracteres, e nenhum formato de id
      // com sublinhado interno foi observado. Se aparecer, esta e a regra a revisar.
      `replace_pattern(body, "((?:acc|txn|cus|ord)_[0-9a-zA-Z]{4})[0-9a-zA-Z]{4,}([^0-9a-zA-Z_]|$)", "$1******$2")`,
    ]
  }

  output {
    logs = [{{ $saida }}]
  }
}
{{- end -}}
