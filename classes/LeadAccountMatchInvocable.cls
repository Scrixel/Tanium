/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Invocable job for the Account and Contact matching process of Lead
 * @Date: 2018-10-12
 * @Author: Cumulus Vision
 * RequestId  ModifiedDate  Description
 * TAN-682    2018-10-27    Initial Development
 * TAN-791    2019-08-07    Added Lead Owner assignment functionality
 * TAN-799    2019-08-21    Updated Owner assignment logic slightly, State can be blank if Country is not "United States" or "Canada"
 * TAN-803    2019-09-06    Updated code to prioritize Queue over SDR User if Country is US and State is blank.
 * TAN-789    2019-09-24    Updated code to use Lead.Country and Lead.State instead of Lead.Countries__c and Lead.HQ_State__c, and to identify 'US' and 'USA' as 'United States'.
 * TAN-828    2019-11-11    Added vertical in lead assignment matching logic
 * TAN-879    2020-05-22    Removed logic related to setting owner (SDR)
 * TAN-890    2020-06-24    Updated logic of Account__c field update based on the Domain matching.
 * TAN-1175   2021-03-05    Don't match on accounts that are Partners / Vendors record types for Opp Reg Process.
 * SS-13499   2026-07-08    Removed Matched_Contact__c matching logic
 */
public with sharing class LeadAccountMatchInvocable {
	@InvocableMethod(label='Lead Account Matching' description='Lead Account Matching')
	public static void buildLeadToMatchingAccountMap(List<Lead> listLead) {
		Set<String> setCompany = new Set<String>();
		Set<String> setDomain = new Set<String>();
		Map<String, List<Account>> mapDomainToAccounts = new Map<String, List<Account>>();
		Map<String, Account> mapNameToAccount = new Map<String, Account>();
		Set<String> setExcludedDomain = Domain_Blacklist__c.getall().keySet();

		Id recordTypeIdPartner = Utility.getRecordTypeIdByAPIName('Account', 'Partner');
		Id recordTypeIdVendor = Utility.getRecordTypeIdByAPIName('Account', 'Vendor');
		Id recordTypeIdOppReg = Utility.getRecordTypeIdByAPIName('Lead', 'Opportunity_Registration');
		Set<Id> excludedAccountRecordTypeIds = new Set<Id>{ recordTypeIdPartner, recordTypeIdVendor };
		for (Lead lead : listLead) {
			setCompany.add(lead.Company);

			String emailDomain = extractEmailDomain(lead.Email);

			if (String.isNotBlank(emailDomain) && isValidDomain(emailDomain, setExcludedDomain)) {
				setDomain.add(emailDomain);
			}
		}

		setCompany.remove(null);
		setDomain.remove(null);

		for (Account account : [
			SELECT Id, Name, OwnerId, Domain__c, RecordTypeId
			FROM Account
			WHERE Domain__c LIKE :buildWrapElementsList('%', setDomain) OR Name IN :setCompany
		]) {
			mapNameToAccount.put(account.Name, account);

			if (String.isBlank(account.Domain__c)) {
				continue;
			}

			for (String domain : account.Domain__c.split(',')) {
				domain = domain.trim();

				if (setDomain.contains(domain)) {
					if (!mapDomainToAccounts.containsKey(domain)) {
						mapDomainToAccounts.put(domain, new List<Account>());
					}
					mapDomainToAccounts.get(domain).add(account);
				}
			}
		}

		List<Lead> updateLead = new List<Lead>();
		Map<Id, Lead> leadMap = new Map<Id, Lead>();
		Lead leadToUpdate;
		for (Lead lead : listLead) {
			if (!lead.IsConverted) {
				String emailDomain = extractEmailDomain(lead.Email);
				String company = lead.Company;
				Account theAccount;

				if (mapDomainToAccounts.containsKey(emailDomain)) {
					if (mapDomainToAccounts.get(emailDomain).size() == 1) {
						theAccount = mapDomainToAccounts.get(emailDomain)[0];
					}
				} else if (mapNameToAccount.containsKey(company)) {
					theAccount = mapNameToAccount.get(company);
				}
				if (
					lead.RecordTypeId == recordTypeIdOppReg &&
					excludedAccountRecordTypeIds.contains(theAccount.RecordTypeId)
				)
					continue;

				if (theAccount != null) {
					if (leadMap.get(lead.Id) != null) {
						leadToUpdate = leadMap.get(lead.Id);
					} else {
						leadToUpdate = new Lead(Id = lead.Id, Account__c = theAccount.Id);
					}

					leadMap.put(lead.Id, leadToUpdate);
				}
			}
		}

		if (!leadMap.isEmpty()) {
			List<Database.SaveResult> saveResults = Database.update(leadMap.values(), false);
			Logger.logDatabaseErrors(
					LoggingLevel.ERROR,
					'LeadAccountMatchInvocable.buildLeadToMatchingAccountMap ERRORS',
					saveResults
				)
				.addTag('apex');
			Logger.saveLog();
		}
	}

	private static String extractEmailDomain(String email) {
		String emailDomain;

		if (String.isNotBlank(email)) {
			String[] emailParts = email.split('@');

			if (emailParts.size() == 2) {
				emailDomain = emailParts[1];
			}
		}

		return emailDomain;
	}

	private static Boolean isValidDomain(String domain, Set<String> setExcludedDomain) {
		if (String.isNotBlank(domain)) {
			String shortDomain = domain.substring(domain.lastIndexOf('.'));
			if (!setExcludedDomain.contains(domain) && !setExcludedDomain.contains(shortDomain)) {
				return true;
			}
		}
		return false;
	}

	private static List<String> buildWrapElementsList(String wrapKey, Set<String> setElement) {
		List<String> listNewElement = new List<String>();

		for (String elm : setElement) {
			String wrapElement = wrapKey + elm + wrapKey;
			listNewElement.add(wrapElement);
		}

		return listNewElement;
	}
}