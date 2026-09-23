/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: AccountNextStep Trigger Handling
 * @Date: 3/2/2016
 * @Author: Cumulus Vision, Tanium Dev Team
 * @Request: ??
 * Modified   ModifiedDate   Description
 * SS-13497   2026-07-07     Remove deprecated fields for project kondo group 2
 */
public class AccountNextStepTriggerHandler extends TriggerHandler {
	public List<Account_Next_Step__c> newAccountNextStepList { get; set; }
	public static final Id ACCOUNT_NEXT_STEP_TAM_RECORDTYPE_ID = Utility.getRecordTypeIdByAPIName(
		'Account_Next_Step__c',
		'TAM_Next_Step'
	);
	public static final Id TAM_NEXT_STEP_TAM_RECORDTYPE_ID = Utility.getRecordTypeIdByAPIName(
		'TAM_Next_Steps__c',
		'TAM_Next_Step'
	);

	public AccountNextStepTriggerHandler() {
		super('AccountNextStepTriggerHandler');
		this.newAccountNextStepList = (List<Account_Next_Step__c>) Trigger.new;
	}

	public override void afterInsert() {
		Map<Id, Account> accountUpdateMap = generateAccountUpdateMap(newAccountNextStepList);
		if (!accountUpdateMap.isEmpty()) {
			List<TAM_Next_Steps__c> newTAMNextStepsList = generateTAMNextStepInsertList(
				newAccountNextStepList,
				accountUpdateMap.keySet()
			);

			if (!newTAMNextStepsList.isEmpty()) {
				insert newTAMNextStepsList;
			}
			update accountUpdateMap.values();
		}
	}

	@TestVisible
	private static Map<Id, Account> generateAccountUpdateMap(
		List<Account_Next_Step__c> accountNextStepList
	) {
		Map<Id, Account> accountUpdateMap = new Map<Id, Account>();

		for (Account_Next_Step__c accountNextStep : accountNextStepList) {
			if (accountNextStep.RecordTypeId == ACCOUNT_NEXT_STEP_TAM_RECORDTYPE_ID) {
				accountUpdateMap.put(
					accountNextStep.Account__c,
					new Account(Id = accountNextStep.Account__c)
				);
			}
		}
		return accountUpdateMap;
	}

	@TestVisible
	private static List<TAM_Next_Steps__c> generateTAMNextStepInsertList(
		List<Account_Next_Step__c> accountNextStepList,
		Set<Id> accountIdSet
	) {
		List<TAM_Next_Steps__c> newTAMNextStepsList = new List<TAM_Next_Steps__c>();
		Map<Id, Id> accountIdOpportunityIdMap = new Map<Id, Id>();

		for (Opportunity opportunity : [
			SELECT Id, AccountId
			FROM Opportunity
			WHERE AccountId IN :accountIdSet AND StageName = :Utility.UNCOMMITTED_RENEWAL
		]) {
			accountIdOpportunityIdMap.put(opportunity.AccountId, opportunity.Id);
		}

		for (Account_Next_Step__c accountNextStep : accountNextStepList) {
			if (accountIdOpportunityIdMap.containsKey(accountNextStep.Account__c)) {
				newTAMNextStepsList.add(
					new TAM_Next_Steps__c(
						RecordTypeId = TAM_NEXT_STEP_TAM_RECORDTYPE_ID,
						TAM_Owner__c = accountNextStep.TAM_Owner__c,
						TAM_Next_Steps__c = accountNextStep.TAM_Next_Steps__c,
						Opportunity__c = accountIdOpportunityIdMap.get(accountNextStep.Account__c)
					)
				);
			}
		}

		return newTAMNextStepsList;
	}
}