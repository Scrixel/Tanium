/** Optional standalone trigger; integrate into the existing QuoteLineItem trigger in Tanium Build. */
trigger ELV_RFA_QuoteLineTrigger on QuoteLineItem (after insert, after update) {
    ELV_RFA_QuoteLineTriggerDispatcher.afterSave(Trigger.new);
}