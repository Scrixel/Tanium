public with sharing class ELV_QuoteTermVersionUnlocking {
    @InvocableMethod(label='Unlock Custom Quote Terms' description='Unlocks Custom Quote Instance term versions for the supplied approval records.')
    public static void unlockForApprovals(List<Id> approvalIds) {
        Set<Id> quoteIds = quoteIds(approvalIds);
        if (quoteIds.isEmpty()) return;
        List<ELV_Quote_Term_Version__c> terms = [
            SELECT Id FROM ELV_Quote_Term_Version__c
            WHERE Instance_Quote__c IN :quoteIds
            AND Version_Type__c = 'Custom Quote Instance'
        ];
        for (Approval.UnlockResult result : Approval.unlock(terms, false)) {
            if (!result.isSuccess()) throw new AuraHandledException(result.getErrors()[0].getMessage());
        }
    }
    private static Set<Id> quoteIds(List<Id> approvalIds) {
        Set<Id> ids = new Set<Id>();
        if (approvalIds == null || approvalIds.isEmpty()) return ids;
        for (appro__Approval__c approval : [SELECT Quote__c FROM appro__Approval__c WHERE Id IN :approvalIds]) {
            if (approval.Quote__c != null) ids.add(approval.Quote__c);
        }
        return ids;
    }
}