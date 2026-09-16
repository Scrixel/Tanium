/** TNCI-135 / ELV-CPQ-068. Preserves a populated Subscription cap and rate, including zero. */
trigger ELV_RenewalUpliftSubscriptionCapTrigger on Ruby__Subscription__c (before insert, before update) {
    Set<Id> orderItemIds = new Set<Id>();
    for (Ruby__Subscription__c sub : Trigger.new) {
        if (sub.Ruby__OrderProduct__c != null && (sub.ELV_Contracted_Renewal_Uplift_Percent__c == null || sub.ELV_RenewalUpliftPercent__c == null)) {
            orderItemIds.add(sub.Ruby__OrderProduct__c);
        }
    }
    Map<Id, OrderItem> items = new Map<Id, OrderItem>([SELECT Id, ELV_Contracted_Renewal_Uplift_Percent__c, ELV_RenewalUpliftPercent__c FROM OrderItem WHERE Id IN :orderItemIds]);
    for (Ruby__Subscription__c sub : Trigger.new) {
        OrderItem sourceOrderItem = items.get(sub.Ruby__OrderProduct__c);
        if (sub.ELV_Contracted_Renewal_Uplift_Percent__c == null && sourceOrderItem != null) {
            sub.ELV_Contracted_Renewal_Uplift_Percent__c = sourceOrderItem.ELV_Contracted_Renewal_Uplift_Percent__c;
        }
        if (sub.ELV_RenewalUpliftPercent__c == null && sourceOrderItem != null) {
            sub.ELV_RenewalUpliftPercent__c = sourceOrderItem.ELV_RenewalUpliftPercent__c;
        }
    }
}