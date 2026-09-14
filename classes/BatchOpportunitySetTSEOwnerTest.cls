/**
 * @DATE: 2021-02-16
 * @AUTHOR: Cumulus Vision
 * @BUSINESS: To test BatchOpportunitySetTSEOwner.
 *
 * Modified  ModifiedDate   Description
 * TAN-1089  2021-02-10     Update related open opportunities when TSE owner changes.
 * TAN-1111  2021-02-16     Initial development.
 */
@IsTest
private class BatchOpportunitySetTSEOwnerTest {
	@TestSetup
	static void makeData() {
		Id userId = UserInfo.getUserId();

		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = new Account(
				Name = 'TestAcc',
				TAM_Sales_SME__c = userId,
				Country_Exception_Approved__c = true,
				Country_Restrictions__c = 'Unrestricted'
			);
			insert acc;

			List<Opportunity> listOpp = new List<Opportunity>();
			for (Integer i = 0; i <= 5; i++) {
				Opportunity opp = new Opportunity(
					Name = 'TestOpp ' + i,
					AccountId = acc.Id,
					StageName = Utility.PROSPECTING,
					CloseDate = System.today().addDays(1)
				);
				listOpp.add(opp);
			}
			insert listOpp;
		}
	}

	@IsTest
	private static void testBatchOpportunitySetTSEOwner() {
		Account[] acounts = [SELECT Id, TAM_Sales_SME__c FROM Account];
		Map<Id, Account> accountsMap = new Map<Id, Account>(acounts);
		Opportunity[] oppsToProcess = [
			SELECT Id, TAM_Sales_SME_Owner__c, Account.TAM_Sales_SME__c
			FROM Opportunity
		];

		BatchOpportunitySetTSEOwner async = new BatchOpportunitySetTSEOwner(
			accountsMap.values(),
			accountsMap.keySet()
		);
		Test.startTest();
		async.execute(null, oppsToProcess);
		Id jobId = Database.executeBatch(async);
		Test.stopTest();

		Opportunity[] opps = [
			SELECT Id, TAM_Sales_SME_Owner__c, Account.TAM_Sales_SME__c
			FROM Opportunity
		];
		System.assertNotEquals(null, opps[0].TAM_Sales_SME_Owner__c);
		System.assertEquals(UserInfo.getUserId(), opps[0].TAM_Sales_SME_Owner__c);
		System.assertEquals(acounts[0].TAM_Sales_SME__c, opps[4].TAM_Sales_SME_Owner__c);
	}
}