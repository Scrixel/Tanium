/**
 * @DATE: 2021-02-10
 * @AUTHOR: Cumulus Vision
 * @BUSINESS: Handling an update from Account to Opportunities.
 *
 * Modified  ModifiedDate   Description
 * TAN-1089  2021-02-10     Update related open opportunities when TSE owner changes.
 * TAN-1111  2021-02-16     Update for Batch Job Scope Logic.
 */
global class BatchOpportunitySetTSEOwner implements Database.Batchable<Opportunity>, Database.Stateful, Database.AllowsCallouts {
	List<Account> changedAccounts = new List<Account>();
	Set<Id> setAccountId = new Set<Id>();

	public BatchOpportunitySetTSEOwner(List<Account> listAccount, Set<Id> setAccounts) {
		changedAccounts = listAccount;
		setAccountId = setAccounts;
	}

	public List<Opportunity> start(Database.BatchableContext bc) {
		List<Opportunity> listOpp = [
			SELECT TAM_Sales_SME_Owner__c, Account.TAM_Sales_SME__c
			FROM Opportunity
			WHERE
				ForecastCategoryName != 'Closed'
				AND StageName != :Utility.FAILED
				AND AccountId IN :setAccountId
		];
		return listOpp;
	}
	public void execute(Database.BatchableContext bc, List<Opportunity> scope) {
		List<Opportunity> oppUpdate = new List<Opportunity>();

		for (Opportunity opp : scope) {
			opp.TAM_Sales_SME_Owner__c = opp.Account.TAM_Sales_SME__c;
			oppUpdate.add(opp);
		}

		if (oppUpdate.size() > 0) {
			update oppUpdate;
		}
	}
	public void finish(Database.BatchableContext bc) {
		System.debug('SUCCESS BATCH');
	}
}