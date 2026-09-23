/**
 * @Business: UserManagePermissionSetBatch - Constellant Dev Permission Set Assignment
 * @Date: 03/26/2024
 * @Authors: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-7884    2024-04-26    Grant Permission Set to Partners with Tier
 * SS-9732    2024-12-10    Remove "Tanium Community Login Unknown" profile
 * SS-10251   2025-02-27    Remove Constellant Dev references and replace it with Tanium Developer Users
 * SS-10546   2025-03-25    Adjust assignment of permission set Partner_Case_Access
 */
public class UserManagePermissionSetBatch implements Database.Batchable<SObject>, Database.Stateful {
	private String defaultQuery =
		'SELECT Id,' +
		' Contact.Account.Tech_Partner_Program_Tier__c,' +
		' Contact.Account.RecordType.DeveloperName' +
		' FROM User' +
		' WHERE IsActive = true' +
		' AND Contact.Account.RecordType.DeveloperName = \'Partner\'' +
		' AND Profile.Name IN (' +
		' \'Tanium Community Login Authenticated Case\',' +
		' \'Tanium Community Login Super User\',' +
		' \'Tanium Community Login Authenticated\')';

	private String finalQuery = '';
	private String originalTransactionId;

	public UserManagePermissionSetBatch() {
		finalQuery = defaultQuery;
	}

	public UserManagePermissionSetBatch(String customQuery) {
		if (String.isNotBlank(customQuery)) {
			finalQuery = customQuery;
		} else {
			finalQuery = defaultQuery;
		}
	}

	public Database.QueryLocator start(Database.BatchableContext BC) {
		this.originalTransactionId = Logger.getTransactionId();

		Logger.info('Started UserManagePermissionSetBatch');
		Logger.saveLog();
		return Database.getQueryLocator(finalQuery);
	}

	public void execute(Database.BatchableContext BC, List<User> users) {
		Logger.setParentLogTransactionId(this.originalTransactionId);

		Map<Id, PermissionSetAssignment> userIdConstellantPermSetMap = new Map<Id, PermissionSetAssignment>();
		Map<Id, PermissionSetAssignment> userIdPartnerCaseAccessPermSetMap = new Map<Id, PermissionSetAssignment>();
		Map<Id, User> usersToGrant = new Map<Id, User>();
		Map<Id, User> usersToRevoke = new Map<Id, User>();
		Set<Id> allUserIds = new Set<Id>();
		List<PermissionSetAssignment> assignmentToInsert = new List<PermissionSetAssignment>();
		List<PermissionSetAssignment> assignmentToDelete = new List<PermissionSetAssignment>();
		Id taniumDevUserPermSetId = [
			SELECT Id
			FROM PermissionSet
			WHERE Name = :Constants.CONSTELLANT_DEV_PERM_SET
		]
		.Id;
		Id partnerCaseAccessPermSetId = [
			SELECT Id
			FROM PermissionSet
			WHERE Name = :Constants.PARTNER_CASE_ACCESS
		]
		.Id;
		for (User user : users) {
			allUserIds.add(user.Id);
			if (user.Contact.Account.Tech_Partner_Program_Tier__c != null) {
				usersToGrant.put(user.Id, user);
			}
		}

		for (PermissionSetAssignment psa : [
			SELECT Id, AssigneeId, PermissionSetId
			FROM PermissionSetAssignment
			WHERE PermissionSet.Name = :Constants.CONSTELLANT_DEV_PERM_SET AND AssigneeId IN :allUserIds
		]) {
			userIdConstellantPermSetMap.put(psa.AssigneeId, psa);
		}

		for (PermissionSetAssignment psa : [
			SELECT Id, AssigneeId, PermissionSetId
			FROM PermissionSetAssignment
			WHERE PermissionSet.Name = :Constants.PARTNER_CASE_ACCESS AND AssigneeId IN :allUserIds
		]) {
			userIdPartnerCaseAccessPermSetMap.put(psa.AssigneeId, psa);
		}

		for (Id userId : usersToGrant.keySet()) {
			User user = usersToGrant.get(userId);

			if (!userIdConstellantPermSetMap.containsKey(userId)) {
				PermissionSetAssignment assignment = new PermissionSetAssignment();
				assignment.AssigneeId = user.Id;
				assignment.PermissionSetId = taniumDevUserPermSetId;
				assignmentToInsert.add(assignment);
			}
			if (!userIdPartnerCaseAccessPermSetMap.containsKey(userId)) {
				PermissionSetAssignment partnerCaseAssignment = new PermissionSetAssignment();
				partnerCaseAssignment.AssigneeId = user.Id;
				partnerCaseAssignment.PermissionSetId = partnerCaseAccessPermSetId;
				assignmentToInsert.add(partnerCaseAssignment);
			}
		}

		List<Database.SaveResult> saveResult = Database.insert(assignmentToInsert, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'Insert failed for these records. Check the Database Results tab for more details.',
				saveResult
			)
			.addTag('apex')
			.addTag('batch');

		Logger.saveLog();
	}

	public void finish(Database.BatchableContext BC) {
		Logger.setParentLogTransactionId(this.originalTransactionId);
		Logger.info('Finished UserManagePermissionSetBatch');
		Logger.saveLog();
	}
}