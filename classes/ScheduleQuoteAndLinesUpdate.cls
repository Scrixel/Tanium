public class ScheduleQuoteAndLinesUpdate implements Schedulable {
	private Set<Id> opportunityIds = new Set<Id>();

	public ScheduleQuoteAndLinesUpdate(Set<Id> oppIds) {
		this.opportunityIds = oppIds;
	}

	public void execute(SchedulableContext sc) {
		OpportunityRenewalUtility.runQuoteAndLinesUpdates(opportunityIds);
	}
}