/*
 * @BUSINESS: Batch class for updating unassigned licenced user fields
 * @DATE: 2025-02-06
 * @AUTHOR: Tanium Dev Team
 * @REQUEST:
 * RequestId  ModifiedDate  Comment
 * SS-7422    2025-02-06    Created
 */
global class UserLicensesUnAssignAsync implements Database.Batchable<sObject>, Schedulable {
	public static final String PACKAGE_KIMBLE_ONE = 'KimbleOne';
	public static final String PACKAGE_APTTUS = 'Apttus';
	public static final Set<String> PACKAGE_LICENSES = new Set<String>{ 'Apttus', 'KimbleOne' };

	global UserLicensesUnAssignAsync() {
	}

	global Database.QueryLocator start(Database.BatchableContext bc) {
		return Database.getQueryLocator(
			[
				SELECT Id, Name, Licensed_Conga_User__c, Licensed_KimbleOne_User__c
				FROM User
				WHERE
					Id NOT IN (
						SELECT Userid
						FROM UserPackageLicense
						WHERE PackageLicense.Namespaceprefix IN :PACKAGE_LICENSES
					)
					AND (Licensed_Conga_User__c = TRUE
					OR Licensed_KimbleOne_User__c = TRUE)
			]
		);
	}

	global void execute(Database.BatchableContext bc, List<User> users) {
		Set<Id> congaUserIds = new Set<Id>();
		Set<Id> kimbleUserIds = new Set<Id>();

		for (UserPackageLicense userPackageLicenses : [
			SELECT userid, PackageLicense.NamespacePrefix
			FROM UserPackageLicense
			WHERE PackageLicense.Namespaceprefix IN :PACKAGE_LICENSES
		]) {
			if (userPackageLicenses.PackageLicense.Namespaceprefix == PACKAGE_APTTUS) {
				congaUserIds.add(userPackageLicenses.userid);
			}
			if (userPackageLicenses.PackageLicense.Namespaceprefix == PACKAGE_KIMBLE_ONE) {
				kimbleUserIds.add(userPackageLicenses.userid);
			}
		}

		for (User user : users) {
			if (
				user.Licensed_Conga_User__c &&
				user.Licensed_KimbleOne_User__c &&
				!congaUserIds.contains(user.Id) &&
				!kimbleUserIds.contains(user.Id)
			) {
				user.Licensed_Conga_User__c = false;
				user.Licensed_KimbleOne_User__c = false;
			} else if (user.Licensed_Conga_User__c && !congaUserIds.contains(user.Id)) {
				user.Licensed_Conga_User__c = false;
			} else if (user.Licensed_KimbleOne_User__c && !kimbleUserIds.contains(user.Id)) {
				user.Licensed_KimbleOne_User__c = false;
			}
		}

		Database.SaveResult[] saveResultsUpdate = Database.update(users, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'UserLicensesUnAssignAsync.execute ERRORS',
				saveResultsUpdate
			)
			.addTag('apex')
			.addTag('batch');
		Logger.saveLog();
	}

	global void finish(Database.BatchableContext bc) {
		Utility.logBatchErrors(bc, 'UserLicensesUnAssignAsync');
	}

	global void execute(SchedulableContext sc) {
		UserLicensesUnAssignAsync batch = new UserLicensesUnAssignAsync();
		Database.executebatch(batch, 200);
	}
}