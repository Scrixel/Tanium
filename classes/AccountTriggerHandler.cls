/**
 * Copyright (c) 2025 Tanium
 *
 * @DATE: 2015-01-18
 * @AUTHOR: Cumulus Vision, Tanium Dev Team
 * @BUSINESS: Account Trigger Handler class, part of Trigger framework
 * RequestId  ModifiedDate  Description
 * SS-7259    2024-02-01    Account segment mapping was updated to handle zero and blank values for Account.Sales_Ops_Derived_EP__c
 * SS-7764    2024-05-22    Added Nebula logger functionality plus class cleanup
 * SS-7935    2024-06-26    Add publishAccount in afterInsert
 * SS-9000    2024-09-23    Opp Reg to Deal Reg Migration
 * SS-10474   2025-05-14    Removed method updateBDRField
 * SS-10897   2025-06-04    Added calls to methods assignTerritoryInformation, insertTerritoryAssociation
 * SS-10016   2025-07-22    Added method to auto set the support model on account before insert
 * SS-11202   2025-10-31    Remove CSHealthMetric object dependencies for deprecation
 * SS-12027   2025-12-02    Add call to method populateAccountSDR
 * SS-12514   2026-02-24    Updated class to follow our trigger framework
 * SS-13234   2026-06-04    Add call to method setContactLeadSDROwner
 * SS-12811   2026-06-17    Add call to method setOwnerFromSalesTerritory and setOpportunityOwnerFromAccount
 */
public class AccountTriggerHandler extends TriggerHandler {
	private List<Account> accounts;
	private Map<Id, Account> oldMap;

	public AccountTriggerHandler() {
		super('AccountTriggerHandler');
		accounts = (List<Account>) Trigger.new;
		oldMap = (Map<Id, Account>) Trigger.oldMap;
	}

	public override void beforeInsert() {
		AccountTriggerUtility.setOwnerFromSalesTerritory(accounts, null);
		AccountTriggerUtilityWithoutSharing.setSegment(accounts);
		AccountTriggerUtilityWithoutSharing.setSupportModel(accounts);
		AccountTriggerUtility.setSDR(accounts, null);
		AccountTriggerUtility.assignTerritoryInformation(accounts);
	}

	public override void afterInsert() {
		AccountTriggerUtilityWithoutSharing.partnerInfluencePickListProcess(accounts);
		AccountTriggerUtility.insertTerritoryAssociation(accounts);
		AccountTriggerUtility.publishAccounts(accounts, null);
		AccountTriggerUtilityWithoutSharing.setContactLeadSDROwner(accounts, null);
	}

	public override void beforeUpdate() {
		AccountTriggerUtility.setOwnerFromSalesTerritory(accounts, oldMap);
		AccountTriggerUtilityWithoutSharing.setSegment(accounts);
		AccountTriggerUtility.setSDR(accounts, oldMap);
	}

	public override void afterUpdate() {
		AccountTriggerUtilityWithoutSharing.partnerInfluencePickListProcess(accounts, oldMap);
		AccountTriggerUtilityWithoutSharing.setDealRegistrationAccountSegment(accounts, oldMap);
		AccountTriggerUtilityWithoutSharing.setContactOwnerFromAccount(accounts, oldMap);
		AccountTriggerUtilityWithoutSharing.setOpportunityOwnerFromAccount(accounts, oldMap);
		AccountTriggerUtilityWithoutSharing.setOpportunityTSEOwner(accounts, oldMap);
		AccountTriggerUtilityWithoutSharing.setOpportunityCsmAccountOwner(accounts, oldMap);
		AccountTriggerUtility.syncInternalSupportRequests(accounts, oldMap);
		AccountTriggerUtility.publishAccounts(accounts, oldMap);
		AccountTriggerUtilityWithoutSharing.setContactLeadSDROwner(accounts, oldMap);
	}
}