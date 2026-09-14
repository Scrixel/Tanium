/** TNCI-135 / ELV-CPQ-068. Preserves a populated Subscription cap, including zero. */
trigger ELV_RenewalUpliftSubscriptionCapTrigger on Ruby__Subscription__c (before insert, before update) {
    Set<Id> orderItemIds = new Set<Id>();
    for (Ruby__Subscription__c sub : Trigger.new) if (sub.ELV_Contracted_Renewal_Uplift_Percent__c == null && sub.Ruby__OrderProduct__c != null) orderItemIds.add(sub.Ruby__OrderProduct__c);
    Map<Id, OrderItem> items = new Map<Id, OrderItem>([SELECT Id, ELV_Contracted_Renewal_Uplift_Percent__c FROM OrderItem WHERE Id IN :orderItemIds]);
    for (Ruby__Subscription__c sub : Trigger.new) if (sub.ELV_Contracted_Renewal_Uplift_Percent__c == null && items.containsKey(sub.Ruby__OrderProduct__c)) sub.ELV_Contracted_Renewal_Uplift_Percent__c = items.get(sub.Ruby__OrderProduct__c).ELV_Contracted_Renewal_Uplift_Percent__c;
}