global class BatchAccountContactSynchronize implements Database.Batchable<sObject> {
	String query =
		'select id, AccountId, Last_Account_Update__c from Contact' +
		' where ((Account.lastmodifieddate > yesterday) or (Last_Account_Update__c = null))' +
		(Test.isRunningTest() ? ' LIMIT 10000' : '');

	global BatchAccountContactSynchronize() {
	}

	global Database.QueryLocator start(Database.BatchableContext BC) {
		return Database.getQueryLocator(query);
	}

	global void execute(Database.BatchableContext BC, List<Contact> scope) {
		set<id> account_set = new Set<id>();

		for (Contact x : scope) {
			account_set.add(x.AccountId);
		}

		Map<id, datetime> last_mod_Map = new Map<id, datetime>();
		List<Account> alookup = [SELECT id, LastModifiedDate FROM Account WHERE id IN :account_set];
		for (Account x : alookup) {
			last_mod_Map.put(x.id, x.LastModifiedDate);
		}

		for (Contact x : scope) {
			system.debug(last_mod_Map.get(x.AccountId));
			x.Last_Account_Update__c = last_mod_Map.get(x.AccountId);
		}

		update scope;
	}

	global void finish(Database.BatchableContext BC) {
	}
}