/** TNCI-135 / ELV-CPQ-068. Preserves a populated Order Item cap and rate, including zero. */
trigger ELV_RenewalUpliftOrderItemCapTrigger on OrderItem (before insert, before update) {
    Set<Id> lineIds = new Set<Id>();
    for (OrderItem item : Trigger.new) {
        if (item.QuoteLineItemId != null && (item.ELV_Contracted_Renewal_Uplift_Percent__c == null || item.ELV_RenewalUpliftPercent__c == null)) {
            lineIds.add(item.QuoteLineItemId);
        }
    }
    Map<Id, QuoteLineItem> lines = new Map<Id, QuoteLineItem>([SELECT Id, ELV_Contracted_Renewal_Uplift_Percent__c, ELV_RenewalUpliftPercent__c FROM QuoteLineItem WHERE Id IN :lineIds]);
    for (OrderItem item : Trigger.new) {
        QuoteLineItem sourceLine = lines.get(item.QuoteLineItemId);
        if (item.ELV_Contracted_Renewal_Uplift_Percent__c == null && sourceLine != null) {
            item.ELV_Contracted_Renewal_Uplift_Percent__c = sourceLine.ELV_Contracted_Renewal_Uplift_Percent__c;
        }
        if (item.ELV_RenewalUpliftPercent__c == null && sourceLine != null) {
            item.ELV_RenewalUpliftPercent__c = sourceLine.ELV_RenewalUpliftPercent__c;
        }
    }
}