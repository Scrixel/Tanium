/*
 * @BUSINESS: Batch class for updating assigned licensed user fields
 * @DATE: 2025-02-06
 * @AUTHOR: Tanium Dev Team
 * @REQUEST:
 * RequestId  ModifiedDate  Comment
 * SS-7422    2025-02-06    Created
 */
global class UserLicensesAssignAsync implements Database.Batchable<sObject>, Schedulable {
	public static final String PACKAGE_KIMBLE_ONE = 'KimbleOne';
	public static final String PACKAGE_APTTUS = 'Apttus';

	global UserLicensesAssignAsync() {
	}

	global Database.QueryLocator start(Database.BatchableContext bc) {
		return Database.getQueryLocator(
			[
				SELECT
					Userid,
					User.Name,
					User.Licensed_KimbleOne_User__c,
					User.Licensed_Conga_User__c,
					User.Isactive,
					User.Profile.Name,
					User.Department,
					User.Division,
					PackageLicense.NamespacePrefix
				FROM UserPackageLicense
				WHERE
					(PackageLicense.Namespaceprefix = :PACKAGE_KIMBLE_ONE
					AND User.Licensed_KimbleOne_User__c = FALSE)
					OR (PackageLicense.Namespaceprefix = :PACKAGE_APTTUS
					AND User.Licensed_Conga_User__c = FALSE)
				ORDER BY PackageLicense.NamespacePrefix, User.Name
			]
		);
	}

	global void execute(Database.BatchableContext bc, List<UserPackageLicense> userPackageLicenses) {
		Map<Id, User> usersMap = new Map<Id, User>();

		for (UserPackageLicense userPackageLicense : userPackageLicenses) {
			User user;
			if (
				userPackageLicense.PackageLicense.Namespaceprefix == PACKAGE_APTTUS &&
				!userPackageLicense.user.Licensed_Conga_User__c
			) {
				if (usersMap.containsKey(userPackageLicense.userid)) {
					user = usersMap.get(userPackageLicense.userid);
					user.Licensed_Conga_User__c = true;
					usersMap.put(userPackageLicense.userid, user);
				} else {
					usersMap.put(
						userPackageLicense.userid,
						new User(Id = userPackageLicense.userid, Licensed_Conga_User__c = true)
					);
				}
			} else if (
				userPackageLicense.PackageLicense.Namespaceprefix == PACKAGE_KIMBLE_ONE &&
				!userPackageLicense.user.Licensed_KimbleOne_User__c
			) {
				if (usersMap.containsKey(userPackageLicense.userid)) {
					user = usersMap.get(userPackageLicense.userid);
					user.Licensed_KimbleOne_User__c = true;
					usersMap.put(userPackageLicense.userid, user);
				} else {
					usersMap.put(
						userPackageLicense.userid,
						new User(Id = userPackageLicense.userid, Licensed_KimbleOne_User__c = true)
					);
				}
			}
		}

		Database.SaveResult[] saveResultsUpdate = Database.update(usersMap.values(), false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'UpdateLicensedUsersAsync.execute ERRORS',
				saveResultsUpdate
			)
			.addTag('apex')
			.addTag('batch');
		Logger.saveLog();
	}

	global void finish(Database.BatchableContext bc) {
		Utility.logBatchErrors(bc, 'UserLicensesAssignAsync');
	}

	global void execute(SchedulableContext sc) {
		UserLicensesAssignAsync batch = new UserLicensesAssignAsync();
		Database.executebatch(batch, 200);
	}
}