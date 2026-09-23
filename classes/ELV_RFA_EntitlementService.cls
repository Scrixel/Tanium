/**
 * Resolves active customer entitlements without hard-coding a managed object
 * schema beyond the fields confirmed in the Tanium source baseline.
 * Account_Entitlements__c is discovered dynamically so an absent or renamed
 * binding produces a visible submit error instead of a false clean result.
 */
public with sharing class ELV_RFA_EntitlementService {
    public class Conflict {
        public Id lineId;
        public String reference;
        public String message;
        public Conflict(Id lineId, String reference, String message) {
            this.lineId = lineId;
            this.reference = reference;
            this.message = message;
        }
    }
    public class Result {
        public Map<Id, Conflict> conflicts = new Map<Id, Conflict>();
        public String bindingError;
    }

    public static Result evaluate(List<QuoteLineItem> lines, Map<Id, Quote> quotes) {
        Result out = new Result();
        if (lines == null || lines.isEmpty()) return out;

        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Account_Entitlements__c')) {
            out.bindingError = 'Account_Entitlements__c is not available in the target org.';
            return out;
        }
        Map<String, Schema.SObjectField> fields = gd.get('Account_Entitlements__c').getDescribe().fields.getMap();
        List<String> required = new List<String>{'Account__c', 'Module__c', 'Start_Date__c', 'End_Date__c'};
        for (String name : required) {
            if (!fields.containsKey(name)) {
                out.bindingError = 'Account_Entitlements__c is missing required field ' + name + '.';
                return out;
            }
        }

        Set<Id> accountIds = new Set<Id>();
        for (QuoteLineItem line : lines) {
            Quote q = quotes.get(line.QuoteId);
            if (q != null && q.AccountId != null) accountIds.add(q.AccountId);
        }
        if (accountIds.isEmpty()) return out;

        List<String> selectFields = new List<String>{'Id', 'Name', 'Account__c', 'Module__c', 'Start_Date__c', 'End_Date__c'};
        if (fields.containsKey('Source_Subscription__c')) selectFields.add('Source_Subscription__c');
        List<SObject> entitlements;
        try {
            entitlements = Database.query(
                'SELECT ' + String.join(selectFields, ',') +
                ' FROM Account_Entitlements__c WHERE Account__c IN :accountIds'
            );
        } catch (Exception e) {
            out.bindingError = 'Could not query Account_Entitlements__c: ' + e.getMessage();
            return out;
        }

        for (QuoteLineItem line : lines) {
            Quote q = quotes.get(line.QuoteId);
            if (q == null || q.AccountId == null) continue;
            Date startDate = asDate(line.get('Ruby__SubscriptionStartDate__c'));
            Date endDate = asDate(line.get('Ruby__SubscriptionEndDate__c'));
            String productCode = line.Product2 == null ? null : line.Product2.ProductCode;
            String productLine = asString(line.get('ELV_Product_Line__c'));
            for (SObject entitlement : entitlements) {
                if ((Id) entitlement.get('Account__c') != q.AccountId) continue;
                String module = asString(entitlement.get('Module__c'));
                if (!moduleMatches(module, productCode, productLine)) continue;
                Date entitlementStart = asDate(entitlement.get('Start_Date__c'));
                Date entitlementEnd = asDate(entitlement.get('End_Date__c'));
                if (!rangesOverlap(startDate, endDate, entitlementStart, entitlementEnd)) continue;
                String reference = asString(entitlement.get('Name'));
                if (fields.containsKey('Source_Subscription__c') && entitlement.get('Source_Subscription__c') != null) {
                    reference += ' / source subscription ' + String.valueOf(entitlement.get('Source_Subscription__c'));
                }
                out.conflicts.put(line.Id, new Conflict(
                    line.Id,
                    reference,
                    'This quote line overlaps active customer entitlement ' + reference + '.'
                ));
                break;
            }
        }
        return out;
    }

    @TestVisible private static Boolean moduleMatches(String module, String productCode, String productLine) {
        if (String.isBlank(module)) return false;
        String needle = module.trim().toLowerCase();
        return (!String.isBlank(productCode) && productCode.toLowerCase().contains(needle))
            || (!String.isBlank(productLine) && productLine.toLowerCase().contains(needle))
            || (!String.isBlank(productCode) && needle.contains(productCode.toLowerCase()))
            || (!String.isBlank(productLine) && needle.contains(productLine.toLowerCase()));
    }

    @TestVisible private static Boolean rangesOverlap(Date leftStart, Date leftEnd, Date rightStart, Date rightEnd) {
        if (leftStart == null || rightStart == null) return false;
        Date openEnd = Date.today().addYears(1000);
        Date normalizedLeftEnd = leftEnd == null ? openEnd : leftEnd;
        Date normalizedRightEnd = rightEnd == null ? openEnd : rightEnd;
        return leftStart <= normalizedRightEnd && rightStart <= normalizedLeftEnd;
    }

    private static Date asDate(Object value) {
        return value instanceof Date ? (Date) value : null;
    }
    private static String asString(Object value) {
        return value == null ? null : String.valueOf(value);
    }
}