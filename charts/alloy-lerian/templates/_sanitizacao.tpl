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
otelcol.processor.transform "sanitizacao" {
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
      `replace_pattern(body, "(\\+[0-9]{2}[0-9]{2})[0-9]{8,9}", "$1********")`,

      // National form with separators.
      `replace_pattern(body, "(\\([0-9]{2}\\) )[0-9]{4,5}-[0-9]{4}", "$1*****-****")`,

      // --- FISCAL DOCUMENT ---
      // Punctuated form first: the plain-digit rule would not match it, and
      // this rule would not match what that one already masked.
      `replace_pattern(body, "([0-9]{3})\\.[0-9]{3}\\.[0-9]{3}-[0-9]{2}", "$1.***.***-**")`,

      // Eleven consecutive digits. Preserves the first three for correlation.
      `replace_pattern(body, "([0-9]{3})[0-9]{8}", "$1********")`,

      // --- PERSON NAME ---
      // Anchored on capitalisation: name terms start uppercase and the
      // surrounding log text is lowercase, which delimits the value without a
      // lookbehind. This is a PREMISE about how applications log, not a
      // guarantee — an application logging names in a different case would not
      // match, and the alternative-form test case for this class is what would
      // surface it.
      //
      // Two rules are needed. Three-or-more terms first: the two-term rule
      // would otherwise match the first two and leave the rest exposed.
      `replace_pattern(body, "((?:customer|sender|recipient|receiver|client|holder)Name=)([A-Z]\\w*)(?: [A-Z]\\w*)+ ([A-Z]\\w*)", "$1$2 ********** $3")`,

      // Exactly two terms: no middle to mask, but the surname is still
      // personal data. The three-plus rule cannot match this case.
      `replace_pattern(body, "((?:customer|sender|recipient|receiver|client|holder)Name=)([A-Z]\\w*) ([A-Z]\\w*)", "$1$2 ********** $3")`,

      // --- EMAIL ADDRESS ---
      // Preserves two characters of the local part and the WHOLE domain. The
      // domain identifies the provider or corporate client, not the person,
      // and is genuinely useful in diagnosis.
      `replace_pattern(body, "([A-Za-z0-9]{2})[A-Za-z0-9._%+-]*(@[A-Za-z0-9.-]+\\.[A-Za-z]{2,})", "$1****$2")`,

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
      `replace_pattern(body, "((?:address|street|logradouro|endereco)[=:] ?)[A-Z][^=]*?(?: [a-z]+=|$)", "$1**********")`,

      // --- OPAQUE RESOURCE IDENTIFIER ---
      // Preserves the semantic prefix and four characters: enough to correlate
      // records for the same resource, not enough to reconstruct the value.
      `replace_pattern(body, "((?:acc|txn|cus|ord)_[0-9a-zA-Z]{4})[0-9a-zA-Z]{4,}", "$1******")`,
    ]
  }

  output {
    logs = [otelcol.processor.batch.agrupamento.input]
  }
}
{{- end -}}
