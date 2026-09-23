trigger ELV_OriginalRenewalUpliftTrigger on QuoteLineItem (before insert, before update) {
    ELV_OriginalRenewalUpliftService.stamp(Trigger.new);
}