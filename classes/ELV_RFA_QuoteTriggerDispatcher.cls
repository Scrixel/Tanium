public with sharing class ELV_RFA_QuoteTriggerDispatcher {
    public static void afterSave(List<Quote> rows) {
        if (!ELV_RFA_Config.isActive() || rows == null || rows.isEmpty()) return;
        Set<Id> quoteIds = new Map<Id, Quote>(rows).keySet();
        try {
            ELV_RFA_ValidationService.evaluateAndPersist(quoteIds);
        } catch (Exception e) {
            // Save must remain non-blocking. Submit re-evaluates and fails closed.
            System.debug(LoggingLevel.ERROR, 'ELV_RFA Quote after-save evaluation failed: ' + e.getMessage());
        }
    }
}