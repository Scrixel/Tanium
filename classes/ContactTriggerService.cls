/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Service class for ContactTriggerHandler
 * @Date: 2022-15-12
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-9000    2024-09-23    Opp Reg to Deal Reg Migration
 * SS-12496   2026-02-24    Updated method checkDeletePermission
 * SS-13075   2026-04-21    Changed FCRM__FCR_Admin_Originating_Contact__c to Primary_Opportunity_Contact__c field
 * SS-13500   2026-07-27    Remove deprecated fields for project kondo group 2 contact
 */
public with sharing class ContactTriggerService extends Singleton {
	public static final ContactTriggerService instance = (ContactTriggerService) Singleton.getSingleton(
		ContactTriggerService.class
	);
	public static final String CUSTOM_DELETE_RESTRICTION = 'Contact_Delete_Restriction';

	public void captureDomainContactToAccount(List<Contact> newContactListontact) {
		Map<Id, String> mapAcc = new Map<Id, String>();
		Set<String> exclude_domain = new Set<String>();
		for (Domain_Blacklist__c bl : Domain_Blacklist__c.getall().values()) {
			if (bl.name.startsWith('*'))
				exclude_domain.add(bl.name.replace('*', ''));
			else
				exclude_domain.add(bl.name);
		}

		for (Contact con : newContactListontact) {
			if (!String.isBlank(con.Email)) {
				String[] domain = con.Email.split('@');
				if (
					!exclude_domain.contains(domain[1]) &&
					!exclude_domain.contains(domain[1].subString(domain[1].lastIndexOf('.')))
				) {
					mapAcc.put(con.AccountId, domain[1]);
				}
			}
		}

		List<Account> lstAccount = new List<Account>();
		for (Account acc : [
			SELECT Id, Domain__c, Name
			FROM Account
			WHERE Id IN :mapAcc.keySet() AND Name != 'Customer Community External Members Account'
		]) {
			if (acc.Domain__c == null) {
				acc.Domain__c = mapAcc.get(acc.Id);
				lstAccount.add(acc);
			}
		}
		if (!lstAccount.isEmpty()) {
			update lstAccount;
		}
	}

	public void checkDeletePermission(Map<Id, Contact> oldContactMap) {
		for (Contact con : oldContactMap.values()) {
			if (!FeatureManagement.checkPermission(Constants.DELETE_LEADS_AND_CONTACTS_PERMISSION)) {
				con.addError(System.Label.Contact_Deletion_Restricted_All_Records);
			}
		}

		if (FeatureManagement.checkPermission(CUSTOM_DELETE_RESTRICTION)) {
			String partnerRecordTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Partner');

			for (Contact partnerContact : [
				SELECT Id
				FROM Contact
				WHERE Id IN :oldContactMap.keySet() AND Account.RecordTypeId = :partnerRecordTypeId
			]) {
				oldContactMap.get(partnerContact.Id).addError(System.Label.Contact_Deletion_Restricted);
			}

			for (User communityUser : [
				SELECT ContactId
				FROM User
				WHERE ContactId IN :oldContactMap.keySet()
			]) {
				oldContactMap.get(communityUser.ContactId)
					.addError(System.Label.Contact_Deletion_Restricted);
			}

			for (Deal_Registration__c deal : [
				SELECT wi_Partner_Contact__c
				FROM Deal_Registration__c
				WHERE wi_Partner_Contact__c IN :oldContactMap.keySet()
			]) {
				oldContactMap.get(deal.wi_Partner_Contact__c)
					.addError(System.Label.Contact_Deletion_Restricted);
			}
		}
	}
}