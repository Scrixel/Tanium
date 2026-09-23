/**
 * Optional standalone trigger for a clean org. In the Tanium Build org, prefer
 * integrating ELV_RFA_QuoteTriggerDispatcher.afterSave into the existing single
 * Quote trigger instead of activating a second trigger.
 */
trigger ELV_RFA_QuoteTrigger on Quote (after insert, after update) {
    ELV_RFA_QuoteTriggerDispatcher.afterSave(Trigger.new);
}