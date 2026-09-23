/**
 * Custom Submit for Approval action for standard Quote.
 * Order is deliberate: lock, Nue update/recalc, server evaluation and message
 * persistence, blocking-message query, then Approvals Pro submit.
 */
public with sharing class ELV_RFA_ApprovalSubmitController {
    public class BlockingMessage {
        @AuraEnabled public String level;
        @AuraEnabled public String field;
        @AuraEnabled public String message;
        @AuraEnabled public String lineId;
        public BlockingMessage(String level, String field, String message, Id lineId) {
            this.level = level; this.field = field; this.message = message; this.lineId = lineId == null ? null : String.valueOf(lineId);
        }
    }
    public class SubmitResult {
        @AuraEnabled public Boolean submitted = false;
        @AuraEnabled public List<BlockingMessage> blockingMessages = new List<BlockingMessage>();
        @AuraEnabled public String error;
    }

    @AuraEnabled
    public static SubmitResult submitForApproval(Id quoteId) {
        SubmitResult out = new SubmitResult();
        if (quoteId == null) { out.error = 'A Quote Id is required.'; return out; }
        try {
            List<Quote> locked = [SELECT Id FROM Quote WHERE Id = :quoteId FOR UPDATE];
            if (locked.isEmpty()) { out.error = 'Quote not found or not accessible.'; return out; }

            ELV_RFA_RefreshService.RefreshResult refreshed = ELV_RFA_RefreshService.refresh(quoteId);
            if (!refreshed.success) { out.error = refreshed.error; return out; }

            ELV_RFA_ValidationService.EvaluationResult evaluated = ELV_RFA_ValidationService.evaluateForSubmit(quoteId);
            if (evaluated.error != null) { out.error = evaluated.error; return out; }
            for (ELV_RFA_ValidationService.Outcome item : evaluated.blocking) out.blockingMessages.add(new BlockingMessage(item.level, item.field, item.message, item.lineId));
            if (!out.blockingMessages.isEmpty()) return out;

            appro.InvocableSubmitForApproval.FlowRequest request = new appro.InvocableSubmitForApproval.FlowRequest();
            request.recordId = String.valueOf(quoteId);
            List<appro.InvocableSubmitForApproval.FlowResponse> responses =
                appro.InvocableSubmitForApproval.submitForApproval(
                    new List<appro.InvocableSubmitForApproval.FlowRequest>{ request }
                );
            if (responses == null || responses.isEmpty()) {
                out.error = 'Approvals Pro returned no response to the submission.';
                return out;
            }
            appro.InvocableSubmitForApproval.FlowResponse response = responses[0];
            if (response.isSuccess != true) {
                out.error = String.isBlank(response.errorMessage)
                    ? 'Approvals Pro rejected the submission.'
                    : response.errorMessage;
                return out;
            }
            out.submitted = true;
            return out;
        } catch (Exception e) {
            out.error = 'Required for Approval submit failed closed: ' + e.getMessage();
            return out;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<BlockingMessage> previewBlockingMessages(Id quoteId) {
        List<BlockingMessage> out = new List<BlockingMessage>();
        if (quoteId == null) return out;
        for (Ruby__Message__c m : [SELECT Ruby__Level__c, Ruby__Field__c, Ruby__QuoteLineItem__c, Ruby__Message__c FROM Ruby__Message__c WHERE Ruby__Quote__c = :quoteId AND Ruby__Level__c IN ('Error','Warning') ORDER BY Ruby__Level__c, Ruby__Field__c LIMIT 200]) out.add(new BlockingMessage(m.Ruby__Level__c, m.Ruby__Field__c, m.Ruby__Message__c, m.Ruby__QuoteLineItem__c));
        return out;
    }
}