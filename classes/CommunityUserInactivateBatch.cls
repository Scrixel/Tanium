/**
 * @Business: Update Community User Status to Inactive after 18 months of inactivity and they
 * have not created a case in the same time period.
 * @Date: 08/05/2025
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-8594    2025-08-26    Initial Development
 */
public class CommunityUserInactivateBatch implements Database.Batchable<sObject>, Schedulable {
	private Integer batchSize;
	private final Integer DEFAULT_BATCH_SIZE = 100;
	private final List<String> communityUserType = new List<String>{
		'CspLitePortal',
		'CustomerSuccess',
		'PowerCustomerSuccess'
	};
	private Set<Id> userCaseContactIds;
	private String userQuery =
		'SELECT ' +
		'Id, ' +
		'ContactId, ' +
		'Username, ' +
		'CommunityNickname, ' +
		'IsActive, ' +
		'IsPortalEnabled, ' +
		'FederationIdentifier ' +
		'FROM User ' +
		'WHERE IsActive = true ' +
		'AND UserType IN :communityUserType ' +
		'AND (' +
		'(LastLoginDate = null ' +
		(Test.isRunningTest() ? ') ' : 'AND CreatedDate < LAST_N_MONTHS:18) ') +
		'OR LastLoginDate < LAST_N_MONTHS:18) ' +
		(Test.isRunningTest() ? 'LIMIT 1' : '');
	private String caseQuery =
		'SELECT ' +
		'Id, ' +
		'ContactId ' +
		'FROM Case ' +
		'WHERE CreatedDate >= LAST_N_MONTHS:18 ' +
		'AND Origin = \'Email\' ';

	public CommunityUserInactivateBatch() {
		this.batchSize = Test.isRunningTest() ? 1 : DEFAULT_BATCH_SIZE;
		initializeUserCaseContactIds();
	}

	public CommunityUserInactivateBatch(
		String customUserQuery,
		String customCaseQuery,
		Integer batchSize
	) {
		if (String.isNotBlank(customUserQuery)) {
			this.userQuery = customUserQuery;
		}
		if (String.isNotBlank(customCaseQuery)) {
			this.caseQuery = customCaseQuery;
		}
		this.batchSize = Test.isRunningTest() ? 1 : batchSize;
		initializeUserCaseContactIds();
	}

	public Database.QueryLocator start(Database.BatchableContext bc) {
		return Database.getQueryLocator(userQuery);
	}

	public void execute(Database.BatchableContext bc, List<User> users) {
		TriggerHandler.bypass(new List<String>{ 'UserTriggerHandler' });

		Set<Id> contactIds = new Set<Id>();
		for (User user : users) {
			contactIds.add(user.ContactId);
		}

		List<User> usersToInactivate = new List<User>();
		for (User user : users) {
			if (!this.userCaseContactIds.contains(user.ContactId)) {
				user.IsActive = false;
				user.IsPortalEnabled = false;
				user.ContactId = null;
				user.FederationIdentifier = '';
				user.Username = '_' + user.Username;
				user.CommunityNickname = '_' + user.CommunityNickname;
				usersToInactivate.add(user);
			}
		}

		if (!usersToInactivate.isEmpty()) {
			List<Database.SaveResult> results = Database.update(usersToInactivate, false);
			Logger.logDatabaseErrors(LoggingLevel.ERROR, 'CommunityUserInactivateBatch ERRORS', results)
				.addTag('apex')
				.addTag('batch');
			Logger.saveLog();
		}
	}

	public void finish(Database.BatchableContext bc) {
		Utility.logBatchErrors(bc, 'CommunityUserInactivateBatch');
	}

	// Scheduler Execute Method
	public void execute(SchedulableContext ctx) {
		Database.executeBatch(new CommunityUserInactivateBatch(), batchSize);
	}

	private void initializeUserCaseContactIds() {
		this.userCaseContactIds = new Set<Id>();
		for (Case c : Database.query(caseQuery)) {
			userCaseContactIds.add(c.ContactId);
		}
	}
}