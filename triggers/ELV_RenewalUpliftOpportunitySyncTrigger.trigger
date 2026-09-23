trigger ELV_RenewalUpliftOpportunitySyncTrigger on Opportunity (after update) {
    ELV_RenewalUpliftOpportunitySync.synchronize(Trigger.new, Trigger.oldMap);
}