/** TNCI-135 / ELV-CPQ-068. Additive order snapshot; existing ARR synchronization remains unchanged. */
trigger ELV_RenewalUpliftOrderItemCapTrigger on OrderItem (before insert, before update) {
    Set<Id> lineIds = new Set<Id>();
    for (OrderItem item : Trigger.new) if (item.ELV_Contracted_Renewal_Uplift_Percent__c == null && item.QuoteLineItemId != null) lineIds.add(item.QuoteLineItemId);
    Map<Id, QuoteLineItem> lines = new Map<Id, QuoteLineItem>([SELECT Id, ELV_Contracted_Renewal_Uplift_Percent__c FROM QuoteLineItem WHERE Id IN :lineIds]);
    for (OrderItem item : Trigger.new) if (item.ELV_Contracted_Renewal_Uplift_Percent__c == null && lines.containsKey(item.QuoteLineItemId)) item.ELV_Contracted_Renewal_Uplift_Percent__c = lines.get(item.QuoteLineItemId).ELV_Contracted_Renewal_Uplift_Percent__c;
}