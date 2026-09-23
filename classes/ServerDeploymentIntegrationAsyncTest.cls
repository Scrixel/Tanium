/*
 * @BUSINESS: Test methods for class ServerDeploymentIntegrationAsync
 * @DATE: 2022-05-02
 * @AUTHOR: Tanium Dev Team
 * @REQUEST:
 * RequestId  ModifiedDate  Comment
 * SS-8357    2024-06-03    Updated test class
 */
@IsTest
private class ServerDeploymentIntegrationAsyncTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler', 'OpportunityTriggerHandler' });
		Id onPremRecordTypeId = Utility.getRecordTypeIdByAPIName('Server_Deployment__c', 'OnPrem');

		System.runAs(TestUserFactory.getAdminUser()) {
			Account account = TestFactory.buildAccount('Test Account');
			insert account;

			Country_For_Export__c country = new Country_For_Export__c(
				Name = 'United States',
				Country_Code__c = 'US'
			);
			insert country;

			List<Server_Deployment__c> serverDeployments = new List<Server_Deployment__c>();
			serverDeployments.add(
				new Server_Deployment__c(
					RecordTypeId = onPremRecordTypeId,
					Account__c = account.Id,
					Server_Device_Type__c = 'On-Prem',
					License_delivery_email_primary__c = 'first.last@email.com',
					Server_OS__c = 'Linux',
					Server_Version__c = '1',
					Tanium_Infrastructure__c = 'Tanium as a Service',
					Country__c = country.Id
				)
			);
			serverDeployments.add(
				new Server_Deployment__c(
					RecordTypeId = onPremRecordTypeId,
					Account__c = account.Id = account.Id,
					Server_Device_Type__c = 'On-Prem',
					License_delivery_email_primary__c = 'first.last@email.com',
					Server_OS__c = 'Linux',
					Server_Version__c = '1',
					Tanium_Infrastructure__c = 'Tanium as a Service',
					Country__c = country.Id
				)
			);
			insert serverDeployments;

			List<STG_Server_Deployment__c> stagingServerDeployments = new List<STG_Server_Deployment__c>();
			STG_Server_Deployment__c stagingServerDeployment;

			for (Integer i = 0; i < serverDeployments.size() + 2; i++) {
				stagingServerDeployment = new STG_Server_Deployment__c(
					Server_Deployment_ID__c = (i == 3)
						? '123456789'
						: (i == 2) ? serverDeployments[i - 1].Id : serverDeployments[i].Id // create 4 ssd records
				);
				stagingServerDeployment.Data_Set_Type__c = (i == 0) ? 'Seats Deployed' : 'User Analytics';
				stagingServerDeployment.Seats_Deployed__c = (i == 0) ? 100 : null;
				stagingServerDeployment.Weekly_Active_Users__c = (i == 0) ? null : 100;
				stagingServerDeployment.Data_as_of_Date__c = System.today();
				stagingServerDeployments.add(stagingServerDeployment);
			}
			insert stagingServerDeployments;
		}
	}

	@IsTest
	static void testUpdateServerDeployments_WhenProcessSeatsDeployedStagingRecords_UpdatedServerDeploymentRecords() {
		STG_Server_Deployment__c[] stagingServerDeployments = [
			SELECT
				Id,
				Data_Set_Type__c,
				Server_Deployment_ID__c,
				Seats_Deployed__c,
				First_Platform_Login__c,
				Last_Platform_Login__c,
				Last_Refresh_Date__c,
				Weekly_Active_Users__c,
				Monthly_Active_Users__c,
				Data_as_of_Date__c
			FROM STG_Server_Deployment__c
			WHERE Data_Set_Type__c = 'Seats Deployed'
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			ServerDeploymentIntegrationAsync async = new ServerDeploymentIntegrationAsync();
			async.updateServerDeployments(stagingServerDeployments);
			Test.stopTest();
		}

		Server_Deployment__c[] serverDeployments = [
			SELECT Id, Seats_Deployed__c, Weekly_Active_Users__c
			FROM Server_Deployment__c
		];
		Assert.isTrue(serverDeployments[0].Seats_Deployed__c == 100);
	}

	@IsTest
	static void testUpdateServerDeployments_WhenProcessUserAnalyticsStagingRecords_UpdatedServerDeploymentRecords() {
		STG_Server_Deployment__c[] stagingServerDeployments = [
			SELECT
				Id,
				Data_Set_Type__c,
				Server_Deployment_ID__c,
				Seats_Deployed__c,
				First_Platform_Login__c,
				Last_Platform_Login__c,
				Last_Refresh_Date__c,
				Weekly_Active_Users__c,
				Monthly_Active_Users__c,
				Data_as_of_Date__c
			FROM STG_Server_Deployment__c
			WHERE Data_Set_Type__c = 'User Analytics'
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			ServerDeploymentIntegrationAsync async = new ServerDeploymentIntegrationAsync();
			async.updateServerDeployments(stagingServerDeployments);
			Test.stopTest();
		}

		Server_Deployment__c[] serverDeployments = [
			SELECT Id, Seats_Deployed__c, Weekly_Active_Users__c
			FROM Server_Deployment__c
		];

		STG_Server_Deployment__c stagingServerDeployment = [
			SELECT Id, Fault_Message__c
			FROM STG_Server_Deployment__c
			WHERE Server_Deployment_ID__c = '123456789'
			LIMIT 1
		];
		Assert.isTrue(serverDeployments[1].Weekly_Active_Users__c == 100);
		Assert.isTrue(stagingServerDeployment.Fault_Message__c != 'Processed without error');
	}

	@IsTest
	static void testBatchExecute_WhenProcessStagingRecords_LastRefreshDateUpdatedServerDeploymentRecords() {
		STG_Server_Deployment__c[] stagingServerDeployments = [
			SELECT
				Id,
				Data_Set_Type__c,
				Server_Deployment_ID__c,
				Seats_Deployed__c,
				First_Platform_Login__c,
				Last_Platform_Login__c,
				Last_Refresh_Date__c,
				Weekly_Active_Users__c,
				Monthly_Active_Users__c,
				Data_as_of_Date__c
			FROM STG_Server_Deployment__c
		];
		String cronExpr = '0 1 * * * ?';
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			ServerDeploymentIntegrationAsync async = new ServerDeploymentIntegrationAsync();
			Id jobId = System.schedule('ServerDeploymentIntegrationAsyncTest', cronExpr, async);
			async.execute(null, stagingServerDeployments);
			Test.stopTest();
		}
		Server_Deployment__c[] serverDeployments = [
			SELECT Id
			FROM Server_Deployment__c
			WHERE Last_Refresh_Date__c = :System.today()
		];

		Assert.isFalse(serverDeployments.isEmpty());
	}
}