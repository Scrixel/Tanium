/*
 * @BUSINESS: Async class that populates ServerDeployment data based on StagingServerDeployment data
 * @DATE: 2022-05-02
 * @AUTHOR: Tanium Dev Team
 * @REQUEST:
 * RequestId  ModifiedDate  Comment
 * SS-8357    2024-06-03    Updated updateServerDeployments method, added Nebula Logger func.
 * SS-8551    2024-06-28    Updated Nebula Logger func., added filter on serverDeploymentId
 * SS-9202    2024-09-24    Updated updateServerDeployments method to get the correct fault message
 */
global class ServerDeploymentIntegrationAsync implements Database.Batchable<sObject>, Schedulable, Database.Stateful {
	private static final Integer BATCH_SIZE = !Test.isRunningTest() ? 1 : 50;
	private Id serverDeploymentId;

	public ServerDeploymentIntegrationAsync() {
		this(null);
	}

	public ServerDeploymentIntegrationAsync(Id serverDeploymentId) {
		this.serverDeploymentId = serverDeploymentId;
	}

	global Database.QueryLocator start(Database.BatchableContext bc) {
		String query = 'SELECT Id ';
		query += 'FROM STG_Server_Deployment__c ';
		query += 'WHERE Data_Set_Type__c != null AND Server_Deployment_ID__c != null AND Processed_DateTime__c = null ';
		if (serverDeploymentId != null) {
			query += 'AND Server_Deployment_ID__c =\'' + serverDeploymentId + '\' ';
		}
		query += 'ORDER BY CreatedDate ASC';
		return Database.getQueryLocator(query);
	}

	global void execute(Database.BatchableContext bc, STG_Server_Deployment__c[] scope) {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'ContactTriggerHandler',
				'OpportunityTriggerHandler',
				'QuoteCPQTriggerHandler'
			}
		);

		STG_Server_Deployment__c[] stagingServerDeployments = [
			SELECT
				Id,
				Data_Set_Type__c,
				Seats_Deployed__c,
				First_Platform_Login__c,
				Last_Platform_Login__c,
				Last_Refresh_Date__c,
				Weekly_Active_Users__c,
				Monthly_Active_Users__c,
				Server_Deployment_ID__c,
				Data_as_of_Date__c
			FROM STG_Server_Deployment__c
			WHERE Id IN :scope
			FOR UPDATE
		];

		List<STG_Server_Deployment__c> stagingServerDeploymentsSeatsDeployed = new List<STG_Server_Deployment__c>();
		List<STG_Server_Deployment__c> stagingServerDeploymentsSeatsAnalytics = new List<STG_Server_Deployment__c>();

		for (STG_Server_Deployment__c stagingServerDeployment : stagingServerDeployments) {
			if (stagingServerDeployment.Data_Set_Type__c == 'Seats Deployed') {
				stagingServerDeploymentsSeatsDeployed.add(stagingServerDeployment);
			}
			if (stagingServerDeployment.Data_Set_Type__c == 'User Analytics') {
				stagingServerDeploymentsSeatsAnalytics.add(stagingServerDeployment);
			}
		}

		// it will be common to have two staging records for each serverDeployment record, one per Data_Set_Type
		updateServerDeployments(stagingServerDeploymentsSeatsDeployed);
		updateServerDeployments(stagingServerDeploymentsSeatsAnalytics);
	}

	@TestVisible
	private void updateServerDeployments(STG_Server_Deployment__c[] stagingServerDeployments) {
		Map<Id, String> serverDeploymentIdsFaultsMap = new Map<Id, String>();
		Map<Id, Server_Deployment__c> serverDeploymentsMap = new Map<Id, Server_Deployment__c>();
		Server_Deployment__c serverDeployment;
		Id serverDeploymentId;

		List<STG_Server_Deployment__c> stagingServerDeploymentsToUpdate = new List<STG_Server_Deployment__c>();
		STG_Server_Deployment__c stagingServerDeploymentToUpdate;

		for (STG_Server_Deployment__c stagingServerDeployment : stagingServerDeployments) {
			try {
				serverDeploymentId = Id.valueOf(stagingServerDeployment.Server_Deployment_ID__c); // ensure valid Id
			} catch (Exception e) {
				continue;
			}
			if (serverDeploymentsMap.containsKey(serverDeploymentId)) {
				continue; // we don't want two serverDeployment records with same Id in the same update
			}
			serverDeployment = new Server_Deployment__c(
				Id = serverDeploymentId,
				Staging_Record__c = stagingServerDeployment.Id,
				Last_Refresh_Date__c = stagingServerDeployment.Data_as_of_Date__c
			);

			if (stagingServerDeployment.Data_Set_Type__c == 'Seats Deployed') {
				serverDeployment.Seats_Deployed__c = stagingServerDeployment.Seats_Deployed__c;
			}

			if (stagingServerDeployment.Data_Set_Type__c == 'User Analytics') {
				serverDeployment.First_Platform_Login__c = stagingServerDeployment.First_Platform_Login__c;
				serverDeployment.Last_Platform_Login__c = stagingServerDeployment.Last_Platform_Login__c;
				serverDeployment.Weekly_Active_Users__c = stagingServerDeployment.Weekly_Active_Users__c;
				serverDeployment.Monthly_Active_Users__c = stagingServerDeployment.Monthly_Active_Users__c;
			}
			serverDeploymentsMap.put(serverDeploymentId, serverDeployment);
		}

		Database.SaveResult[] saveResults = Database.update(serverDeploymentsMap.values(), false);

		for (Database.SaveResult saveResult : saveResults) {
			if (!saveResult.isSuccess()) {
				serverDeploymentIdsFaultsMap.put(
					saveResult.getId(),
					saveResult.getErrors()[0].getMessage()
				);
			}
		}

		for (Server_Deployment__c serverDeploymentRecord : serverDeploymentsMap.values()) {
			stagingServerDeploymentToUpdate = new STG_Server_Deployment__c(
				Id = serverDeploymentRecord.Staging_Record__c
			);
			if (serverDeploymentIdsFaultsMap.containsKey(serverDeploymentRecord.Id)) {
				stagingServerDeploymentToUpdate.Fault_Message__c = serverDeploymentIdsFaultsMap.get(
					serverDeploymentRecord.Id
				);
			} else {
				stagingServerDeploymentToUpdate.Fault_Message__c = 'Processed without error';
				stagingServerDeploymentToUpdate.Processed_DateTime__c = System.now();
			}
			stagingServerDeploymentsToUpdate.add(stagingServerDeploymentToUpdate);
		}

		try {
			update stagingServerDeploymentsToUpdate;
		} catch (Exception e) {
			Logger.error('ServerDeploymentIntegrationAsync.updateServerDeployments Errors', e)
				.addTag('apex')
				.addTag('batch');
			Logger.saveLog();
		}
	}

	global void finish(Database.BatchableContext bc) {
	}

	// Scheduler execute method
	global void execute(SchedulableContext ctx) {
		ServerDeploymentIntegrationAsync async = new ServerDeploymentIntegrationAsync();
		Database.executeBatch(async, BATCH_SIZE);
	}
}