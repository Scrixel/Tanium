/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Update Account Seats Purchased, Active Subscriptions, Active Packages, Active Operatores (Screen Share) and Subscription Max End Date
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-7608    2024-11-12    Account Type Updates and Nebula Logger
 * SS-10969   2025-05-29    Updated method execute
 * SS-12483   2026-02-05    Updated method execute to use custom labels
 * SS-12650   2026-02-23    Updated batch logic for former customer accounts
 */
public without sharing class BatchAccountStatusUpdate implements Database.Batchable<sObject>, Schedulable, Database.Stateful {
	private Integer maxSubscriptionEndDateThreshold;
	private Id prospectRecordTypeId = Utility.getRecordTypeIdByAPIName('Account', 'Prospect');
	private Set<String> applicableTypesCustomer = new Set<String>{ 'Customer', 'Prospect' };
	private Set<String> applicablePartnerExclude = new Set<String>{
		'Inactive',
		'Terminated',
		'Archived'
	};
	private Set<String> applicablePartnerInclude = new Set<String>{
		'Active',
		'New',
		'Pending',
		'Prospect'
	};
	private Set<String> applicableTypesPartner = new Set<String>{
		'Alliance partner',
		'Consulting partner',
		'Distributor',
		'Integrator',
		'MSP partner',
		'OEM partner',
		'Partner',
		'Reseller',
		'Reseller (channel partner, VAR, LAR, etc)',
		'System Integrator'
	};
	private String accountQuery =
		'SELECT Id, ' +
		'Name, ' +
		'Type, ' +
		'Partner_Maturity__c, ' +
		'Max_Subscription_End_Date__c, ' +
		'Max_MSP_Managed_Subscription_End_Date__c, ' +
		'RecordTypeId, ' +
		'Number_of_UnCommitted_Renewals__c, ' +
		'Active_Account__c ' +
		'FROM Account ' +
		'WHERE Type != NULL';

	public BatchAccountStatusUpdate() {
		try {
			this.maxSubscriptionEndDateThreshold = Integer.valueOf(
				System.Label.Max_Subscription_End_Date_Threshold
			);
		} catch (Exception e) {
			this.maxSubscriptionEndDateThreshold = -7;
		}
	}

	public Database.QueryLocator start(Database.BatchableContext bc) {
		return Database.getQueryLocator(accountQuery);
	}

	public void execute(Database.BatchableContext bc, List<Account> accounts) {
		List<Account> accountsToUpdate = new List<Account>();
		for (Account acc : accounts) {
			Boolean isAccountUpdated = false;
			if (
				acc.Type == 'Customer' &&
				acc.Max_Subscription_End_Date__c <=
				System.today().addDays(maxSubscriptionEndDateThreshold) &&
				acc.Number_of_UnCommitted_Renewals__c == 0
			) {
				acc.Type = 'Former Customer';
				acc.RecordTypeId = prospectRecordTypeId;
				isAccountUpdated = true;
			} else if (
				acc.Type == 'MSP End User' &&
				acc.Max_MSP_Managed_Subscription_End_Date__c <=
				System.today().addDays(maxSubscriptionEndDateThreshold) &&
				acc.Number_of_UnCommitted_Renewals__c == 0
			) {
				acc.Type = 'Prospect';
				acc.RecordTypeId = prospectRecordTypeId;
				isAccountUpdated = true;
			}

			if (applicableTypesCustomer.contains(acc.Type) && !acc.Active_Account__c) {
				acc.Active_Account__c = true;
				isAccountUpdated = true;
			} else if (
				applicableTypesPartner.contains(acc.Type) &&
				acc.Partner_Maturity__c != null &&
				applicablePartnerInclude.contains(acc.Partner_Maturity__c) &&
				!acc.Active_Account__c
			) {
				acc.Active_Account__c = true;
				isAccountUpdated = true;
			} else if (
				applicableTypesPartner.contains(acc.Type) &&
				acc.Partner_Maturity__c != null &&
				applicablePartnerExclude.contains(acc.Partner_Maturity__c) &&
				acc.Active_Account__c
			) {
				acc.Active_Account__c = false;
				isAccountUpdated = true;
			}

			if (isAccountUpdated) {
				accountsToUpdate.add(acc);
			}
		}

		List<Database.SaveResult> results = Database.update(accountsToUpdate, false);
		Logger.logDatabaseErrors(LoggingLevel.ERROR, 'BatchAccountStatusUpdate ERRORS', results)
			.addTag('apex')
			.addTag('batch');
		Logger.saveLog();
	}

	public void finish(Database.BatchableContext bc) {
		Utility.logBatchErrors(bc, 'BatchAccountStatusUpdate');
	}

	public void execute(SchedulableContext ctx) {
		Database.executeBatch(new BatchAccountStatusUpdate());
	}
}