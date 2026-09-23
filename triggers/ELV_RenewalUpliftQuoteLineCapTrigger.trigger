/** TNCI-135 / ELV-CPQ-068. Additive pre-pricing cap stamp; existing handlers are unchanged. */
trigger ELV_RenewalUpliftQuoteLineCapTrigger on QuoteLineItem (before insert, before update) {
    ELV_RenewalUpliftCapPropagation.stampQuoteLines(Trigger.new);
}