trigger OpportunityTrigger on Opportunity(
	after update,
	before update,
	before insert,
	after insert
) {
	new OpportunityTriggerHandler().run();
}