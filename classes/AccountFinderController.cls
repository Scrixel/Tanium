public without sharing class AccountFinderController {
	@AuraEnabled(cacheable=true)
	public static List<AccountData> getSearchAcctResults(String acctName) {
		List<List<SObject>> acctSearchResults = new List<List<SObject>>();
		List<SObject> acctObjs = new List<SObject>();
		List<AccountData> acctLst = new List<AccountData>();
		acctName = '*' + acctName + '*';
		for (
			List<SObject> each : [FIND :acctName IN NAME FIELDS RETURNING Account(Id, Name ORDER BY Name)]
		) {
			acctObjs.addAll(each);
		}
		AccountData data;
		for (Account each : [
			SELECT
				Id,
				Name,
				Owner.Name,
				Parent.Name,
				RecordType.Name,
				Industry,
				Number_of_Open_Opportunities__c
			FROM Account
			WHERE ID IN :acctObjs
		]) {
			data = new AccountData();
			data.name = each.Name;
			data.ownerName = each.Owner.Name;
			data.parentName = (each.Parent.Name != null) ? each.Parent.Name : '';
			data.accountType = each.RecordType.Name;
			data.industry = each.Industry;
			data.numberOfOpenOpps = each.Number_of_Open_Opportunities__c;
			acctLst.add(data);
		}
		return acctLst;
	}

	public class AccountData {
		@AuraEnabled
		public String name { get; set; }

		@AuraEnabled
		public String ownerName { get; set; }

		@AuraEnabled
		public String parentName { get; set; }

		@AuraEnabled
		public String accountType { get; set; }

		@AuraEnabled
		public String industry { get; set; }

		@AuraEnabled
		public Decimal numberOfOpenOpps { get; set; }
	}
}