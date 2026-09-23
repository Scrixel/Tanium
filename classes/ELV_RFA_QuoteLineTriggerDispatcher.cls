public with sharing class ELV_RFA_QuoteLineTriggerDispatcher {
    public static void afterSave(List<QuoteLineItem> rows) {
        if (!ELV_RFA_Config.isActive() || rows == null || rows.isEmpty()) return;
        Set<Id> quoteIds = new Set<Id>();
        for (QuoteLineItem row : rows) if (row.QuoteId != null) quoteIds.add(row.QuoteId);
        if (quoteIds.isEmpty()) return;
        try {
            ELV_RFA_ValidationService.evaluateAndPersist(quoteIds);
        } catch (Exception e) {
            // Save must remain non-blocking. Submit re-evaluates and fails closed.
            System.debug(LoggingLevel.ERROR, 'ELV_RFA QuoteLine after-save evaluation failed: ' + e.getMessage());
        }
    }
}