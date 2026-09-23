/**
 * Server-side source of truth for Required for Approval.
 *
 * Save-time execution only refreshes messages and conflict flags; it never
 * blocks a Quote save. The custom submit controller invokes the same evaluator
 * synchronously and fails closed before invoking Approvals Pro.
 */
public with sharing class ELV_RFA_ValidationService {
    public static final String PREFIX = 'ELV_RFA_';
    public static final String ERROR = 'Error';
    public static final String WARNING = 'Warning';
    public static final String INFO = 'Info';
    @TestVisible private static Boolean running = false;

    public class Outcome {
        public Id quoteId;
        public Id lineId;
        public String level;
        public String field;
        public String message;
        public Outcome(Id quoteId, Id lineId, String level, String field, String message) {
            this.quoteId = quoteId;
            this.lineId = lineId;
            this.level = level;
            this.field = field != null && field.startsWith(PREFIX) ? field : PREFIX + field;
            this.message = message;
        }
    }
    public class EvaluationResult {
        public Boolean persisted = false;
        public List<Outcome> outcomes = new List<Outcome>();
        public List<Outcome> blocking = new List<Outcome>();
        public String error;
    }

    public static void evaluateAndPersist(Set<Id> quoteIds) {
        if (running || quoteIds == null || quoteIds.isEmpty()) return;
        running = true;
        try {
            EvaluationResult result = evaluate(quoteIds);
            if (result.error == null) persist(result, quoteIds);
        } finally {
            running = false;
        }
    }

    public static EvaluationResult evaluateForSubmit(Id quoteId) {
        EvaluationResult result = new EvaluationResult();
        if (quoteId == null) { result.error = 'A Quote Id is required.'; return result; }
        if (!ELV_RFA_Config.isActive()) {
            result.error = 'Required for Approval is inactive or the current user is outside the pilot gate.';
            return result;
        }
        result = evaluate(new Set<Id>{quoteId});
        if (result.error != null) return result;
        try {
            persist(result, new Set<Id>{quoteId});
            result.persisted = true;
            result.blocking = getBlockingOutcomes(quoteId);
        } catch (Exception e) {
            result.error = 'Required for Approval messages could not be persisted: ' + e.getMessage();
        }
        return result;
    }

    private static EvaluationResult evaluate(Set<Id> quoteIds) {
        EvaluationResult result = new EvaluationResult();
        List<Quote> quotes;
        try {
            quotes = [
                SELECT Id, AccountId, OpportunityId, Pricebook2Id, Pricebook2.IsActive,
                       ExpirationDate, ELV_Expiration_Date_Limit__c,
                       ELV_Deployment_Method__c, ELV_Deployment_Partner__c,
                       ELV_Partner_Accreditation__c, ELV_Deployment_Exception_Granted__c,
                       ELV_L1_L2_Support_Partner__c, ELV_L1_L2_Support_Partner_Accredited__c,
                       ELV_L1_L2_Support_Exception_Granted__c, ELV_Service_Provider__c,
                       ELV_Downstream_Reseller__c, ELV_Partner_Deal__c,
                       ELV_Training_Products__c, ELV_AreaVP__c, ELV_SalesRep__c,
                       ELV_Deal_Desk_Approver__c, ELV_Legal_Entity__c, BillingName,
                       ELV_Pricing_Discount_Justification__c, ELV_Pricing_Discount_Explanation__c,
                       ELV_Changes_from_Previous_Quote__c, ELV_ChangesfromPrevQuoteExpl__c,
                       ELV_PartnerProgramOverrideJustif__c, ELV_Billing_Schedule_Exist__c,
                       ELV_Billing_Schedule_Total_Amount__c, ELV_Net_Total_Billing__c,
                       ELV_ESO_Product_Count__c, ELV_HuntIQ_Product_Count__c,
                       ELV_Exclude_Partner_Transition_ISR__c,
                       ELV_Indirect_Partner_Override__c, Ruby__Approval_Status__c,
                       Opportunity.OwnerId
                FROM Quote WHERE Id IN :quoteIds
            ];
        } catch (Exception e) {
            result.error = 'Required for Approval field binding/query failed: ' + e.getMessage();
            return result;
        }
        if (quotes.isEmpty()) { result.error = 'Quote not found or not accessible.'; return result; }

        List<QuoteLineItem> lines;
        try {
            lines = [
                SELECT Id, QuoteId, Product2Id, Product2.ProductCode, Product2.Name,
                       ELV_Product_Line__c, ELV_Product_Type__c, ELV_ESR_Service_Type__c,
                       ELV_TrainingDeliveryType__c, ELV_Partner_Discount_Override__c,
                       Ruby__SubscriptionStartDate__c, Ruby__SubscriptionEndDate__c,
                       ELV_RFA_Entitlement_Conflict__c, ELV_RFA_Entitlement_Conflict_Reference__c
                FROM QuoteLineItem WHERE QuoteId IN :quoteIds ORDER BY CreatedDate
            ];
        } catch (Exception e) {
            result.error = 'Required for Approval QuoteLineItem binding/query failed: ' + e.getMessage();
            return result;
        }
        Map<Id, Quote> quoteById = new Map<Id, Quote>(quotes);
        Map<Id, List<QuoteLineItem>> linesByQuote = new Map<Id, List<QuoteLineItem>>();
        for (QuoteLineItem line : lines) {
            if (!linesByQuote.containsKey(line.QuoteId)) linesByQuote.put(line.QuoteId, new List<QuoteLineItem>());
            linesByQuote.get(line.QuoteId).add(line);
        }

        for (Quote q : quotes) {
            List<QuoteLineItem> qLines = linesByQuote.containsKey(q.Id) ? linesByQuote.get(q.Id) : new List<QuoteLineItem>();
            if (qLines.isEmpty()) add(result, q.Id, null, ERROR, 'QUOTE_LINES', 'Missing Quote Lines: add at least one product before submitting.');
            if (q.Pricebook2Id == null || q.Pricebook2.IsActive != true) add(result, q.Id, null, ERROR, 'PRICEBOOK', 'Inactive Pricebook: select an active Price Book.');
            if (q.Ruby__Approval_Status__c == 'Pending' || q.Ruby__Approval_Status__c == 'Approved') add(result, q.Id, null, ERROR, 'APPROVAL_STATUS', 'Quote Already Submitted: recall it or clone it before resubmitting.');
            if (q.ExpirationDate == null) add(result, q.Id, null, ERROR, 'EXPIRATION_DATE', 'Expires On is required.');
            else if (q.ExpirationDate < Date.today()) add(result, q.Id, null, ERROR, 'EXPIRATION_DATE', 'Expires On is in the past.');
            else if (q.ELV_Expiration_Date_Limit__c != null && q.ExpirationDate > q.ELV_Expiration_Date_Limit__c) add(result, q.Id, null, ERROR, 'EXPIRATION_DATE', 'Expires On is after Expiration Date Limit.');

            Boolean esoMode = q.ELV_Deployment_Method__c == 'Tanium ESO' || q.ELV_Deployment_Method__c == 'ESO';
            if (!esoMode && q.ELV_Deployment_Partner__c == null) add(result, q.Id, null, ERROR, 'DEPLOYMENT_PARTNER', 'Deployment Provider is required unless the provider is Tanium ESO.');
            if (!esoMode && q.ELV_Deployment_Partner__c != null && String.isBlank(q.ELV_Partner_Accreditation__c) && q.ELV_Deployment_Exception_Granted__c != true) add(result, q.Id, null, ERROR, 'DEPLOYMENT_PARTNER', 'Deployment Provider accreditation is not confirmed.');
            Boolean supportNamed = q.ELV_L1_L2_Support_Partner__c != null || q.ELV_Service_Provider__c != null;
            if (!supportNamed) add(result, q.Id, null, ERROR, 'SUPPORT_PARTNER', 'L1/L2 Support Provider is required.');
            else if (q.ELV_L1_L2_Support_Partner__c != null && q.ELV_L1_L2_Support_Partner_Accredited__c != true && q.ELV_L1_L2_Support_Exception_Granted__c != true) add(result, q.Id, null, ERROR, 'SUPPORT_PARTNER', 'Support Provider accreditation is not confirmed.');
            if (q.ELV_Partner_Deal__c == true && q.ELV_Downstream_Reseller__c == null) add(result, q.Id, null, ERROR, 'DOWNSTREAM_PARTNER', 'Distributor quote requires a Downstream Partner.');
            if (q.ELV_AreaVP__c == null) add(result, q.Id, null, ERROR, 'AREA_VP', 'Area VP is required.');
            if (q.ELV_SalesRep__c == null || q.Opportunity == null || q.ELV_SalesRep__c != q.Opportunity.OwnerId) add(result, q.Id, null, ERROR, 'SALES_REP', 'Sales Rep must match the Opportunity Owner.');
            if (q.ELV_Deal_Desk_Approver__c == null) add(result, q.Id, null, ERROR, 'DEAL_DESK_APPROVER', 'Deal Desk Approver is required.');
            if (q.ELV_Legal_Entity__c == null) add(result, q.Id, null, ERROR, 'LEGAL_ENTITY', 'Tanium Legal Entity is required.');
            if (String.isBlank(q.BillingName)) add(result, q.Id, null, ERROR, 'BILL_TO', 'Bill To Name is required.');
            if (String.isBlank(q.ELV_Pricing_Discount_Justification__c) || String.isBlank(q.ELV_Pricing_Discount_Explanation__c)) add(result, q.Id, null, ERROR, 'PRICING_DISCOUNT_JUSTIFICATION', 'Pricing/Discount Justification and Explanation are required.');
            if (String.isBlank(q.ELV_Changes_from_Previous_Quote__c) || String.isBlank(q.ELV_ChangesfromPrevQuoteExpl__c)) add(result, q.Id, null, ERROR, 'CHANGES_FROM_PREVIOUS_QUOTE', 'Changes from Previous Quote and Explanation are required.');
            Boolean overrideExists = false;
            for (QuoteLineItem line : qLines) if (line.ELV_Partner_Discount_Override__c == true) { overrideExists = true; break; }
            if (overrideExists && String.isBlank(q.ELV_PartnerProgramOverrideJustif__c)) add(result, q.Id, null, ERROR, 'PARTNER_OVERRIDE_JUSTIFICATION', 'Partner Program Override Justification is required when programmatic discount is overridden.');
            if (q.ELV_Billing_Schedule_Exist__c == null || q.ELV_Billing_Schedule_Exist__c <= 0 || q.ELV_Billing_Schedule_Total_Amount__c == null || q.ELV_Net_Total_Billing__c == null || Math.abs(q.ELV_Billing_Schedule_Total_Amount__c - q.ELV_Net_Total_Billing__c) > 0.01) add(result, q.Id, null, ERROR, 'BILLING_SCHEDULE', 'Missing / Outdated Billing Schedules: create or update billings, then refresh.');
        }

        ELV_RFA_Config.Settings settings = ELV_RFA_Config.get();
        if (settings.entitlementCheckActive) {
            ELV_RFA_EntitlementService.Result ent = ELV_RFA_EntitlementService.evaluate(lines, quoteById);
            if (ent.bindingError != null) result.error = ent.bindingError;
            for (ELV_RFA_EntitlementService.Conflict conflict : ent.conflicts.values()) add(result, quoteById.get(conflict.lineId).Id, conflict.lineId, WARNING, 'ENTITLEMENT_CONFLICT', conflict.message);
            syncLineConflictFlags(lines, ent.conflicts);
        }
        if (settings.isrCheckActive) evaluateIsrRequirements(result, quotes, settings);
        result.blocking = new List<Outcome>();
        for (Outcome o : result.outcomes) if (o.level == ERROR || o.level == WARNING) result.blocking.add(o);
        return result;
    }

    private static void evaluateIsrRequirements(EvaluationResult result, List<Quote> quotes, ELV_RFA_Config.Settings settings) {
        Map<Id, Set<String>> approvedTypesByOpp = new Map<Id, Set<String>>();
        Set<Id> oppIds = new Set<Id>();
        for (Quote q : quotes) if (q.OpportunityId != null) oppIds.add(q.OpportunityId);
        if (oppIds.isEmpty()) return;
        if (!Schema.getGlobalDescribe().containsKey('Account_Support_Request__c')) { result.error = 'Account_Support_Request__c is not available for ISR validation.'; return; }
        try {
            for (SObject row : Database.query('SELECT Id, Opportunity__c, Status__c, RecordType.DeveloperName FROM Account_Support_Request__c WHERE Opportunity__c IN :oppIds')) {
                if (String.valueOf(row.get('Status__c')) != 'ESO Approved' && String.valueOf(row.get('Status__c')) != 'Approved') continue;
                Id oppId = (Id) row.get('Opportunity__c');
                if (!approvedTypesByOpp.containsKey(oppId)) approvedTypesByOpp.put(oppId, new Set<String>());
                SObject rt = row.getSObject('RecordType');
                approvedTypesByOpp.get(oppId).add(rt == null ? '' : String.valueOf(rt.get('DeveloperName')));
            }
        } catch (Exception e) { result.error = 'Could not evaluate Account Support Requests: ' + e.getMessage(); return; }
        for (Quote q : quotes) {
            Set<String> types = approvedTypesByOpp.containsKey(q.OpportunityId) ? approvedTypesByOpp.get(q.OpportunityId) : new Set<String>();
            if (q.ELV_ESO_Product_Count__c != null && q.ELV_ESO_Product_Count__c > 0 && !types.contains(settings.esoRecordType)) add(result, q.Id, null, ERROR, 'ESO_ISR', 'Missing ESO ISR: an approved ESO Support Request is required.');
            if (q.ELV_HuntIQ_Product_Count__c != null && q.ELV_HuntIQ_Product_Count__c > 0 && !types.contains(settings.huntIqRecordType)) add(result, q.Id, null, ERROR, 'HUNTIQ_ISR', 'Missing HuntIQ ISR: an approved HuntIQ Threat Hunter Service Request is required.');
            if (q.ELV_Indirect_Partner_Override__c == true && q.ELV_Exclude_Partner_Transition_ISR__c != true && !types.contains(settings.transitionRecordType)) add(result, q.Id, null, ERROR, 'PARTNER_TRANSITION_ISR', 'Missing Indirect Transition ISR: an approved Partner Transition request is required.');
        }
    }

    private static void persist(EvaluationResult result, Set<Id> quoteIds) {
        List<Ruby__Message__c> existing = [SELECT Id FROM Ruby__Message__c WHERE Ruby__Quote__c IN :quoteIds AND Ruby__Field__c LIKE :PREFIX + '%'];
        if (!existing.isEmpty()) delete existing;
        Map<String, Ruby__Message__c> inserts = new Map<String, Ruby__Message__c>();
        for (Outcome o : result.outcomes) {
            String key = o.quoteId + '|' + o.level + '|' + o.field + '|' + String.valueOf(o.lineId);
            inserts.put(key, new Ruby__Message__c(
                Ruby__Quote__c = o.quoteId,
                Ruby__QuoteLineItem__c = o.lineId,
                Ruby__Level__c = o.level,
                Ruby__Field__c = o.field,
                Ruby__Message__c = o.message
            ));
        }
        if (!inserts.isEmpty()) insert inserts.values();
    }

    private static List<Outcome> getBlockingOutcomes(Id quoteId) {
        List<Outcome> out = new List<Outcome>();
        for (Ruby__Message__c m : [SELECT Ruby__Level__c, Ruby__Field__c, Ruby__QuoteLineItem__c, Ruby__Message__c FROM Ruby__Message__c WHERE Ruby__Quote__c = :quoteId AND Ruby__Level__c IN ('Error','Warning') ORDER BY Ruby__Level__c, Ruby__Field__c LIMIT 200]) out.add(new Outcome(quoteId, m.Ruby__QuoteLineItem__c, m.Ruby__Level__c, m.Ruby__Field__c, m.Ruby__Message__c));
        return out;
    }

    private static void syncLineConflictFlags(List<QuoteLineItem> lines, Map<Id, ELV_RFA_EntitlementService.Conflict> conflicts) {
        List<QuoteLineItem> updates = new List<QuoteLineItem>();
        for (QuoteLineItem line : lines) {
            ELV_RFA_EntitlementService.Conflict c = conflicts.get(line.Id);
            QuoteLineItem sparse = new QuoteLineItem(Id = line.Id);
            sparse.put('ELV_RFA_Entitlement_Conflict__c', c != null);
            sparse.put('ELV_RFA_Entitlement_Conflict_Reference__c', c == null ? null : c.reference);
            updates.add(sparse);
        }
        if (!updates.isEmpty()) update updates;
    }

    private static void add(EvaluationResult result, Id quoteId, Id lineId, String level, String field, String message) {
        result.outcomes.add(new Outcome(quoteId, lineId, level, field, message));
    }
}