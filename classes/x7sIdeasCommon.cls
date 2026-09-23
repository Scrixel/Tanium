/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public without sharing class x7sIdeasCommon {
	// Set the down voting flag in Custom Settings
	// Enabled by default
	@AuraEnabled
	public Boolean lexMode { get; set; }

	@AuraEnabled
	public Boolean debugMode { get; private set; }

	@AuraEnabled
	public String sitePath { get; set; }

	@AuraEnabled
	public Boolean nicknameEnabled { get; set; }

	@AuraEnabled
	public Boolean isAuthenticated { get; set; }

	@AuraEnabled
	public Boolean canCreateNew { get; set; }

	@AuraEnabled
	public String zoneId { get; set; }

	@AuraEnabled
	public String emailIdeaStatusTemplate, emailIdeaCommentTemplate, orgWideFromEmailAddress;

	@AuraEnabled
	public String chatterProfiles, chatterPermissions, accountFilterPermissions;

	// Voting
	@AuraEnabled
	public Boolean allowDownVoting { get; private set; }
	@AuraEnabled
	public Boolean ignoreVoteLimits { get; private set; }
	@AuraEnabled
	public Boolean showAlternateCTA { get; private set; }
	@AuraEnabled
	public String voteDisableStatus { get; private set; }

	@AuraEnabled
	public Boolean disableReadOnlyUsers { get; private set; }

	public final static String IDEAS_SETTINGS = 'X7S_Ideas_Setting__mdt';
	//private final String  SETTINGS_FIELD_SET = 'X7S_Idea_Field_Set__mdt';
	//private final String  SETTINGS_FIELD     = 'X7S_Idea_Custom_Field__mdt';
	private final Integer MAX_CUSTOM_FIELDS = 10;

	public final static String IDEAS_DEVELOPER_NAME = 'Default';
	private final static String IDEAS_UNIT_TEST_NAME = 'x7sIdeasTestSettings';

	public static List<String> commonSettingsFields = new List<String>{
		'id', 'developername',
		'allow_down_voting__c', 'debug_mode__c', 'default_test_profile__c',
		'status_change_email_template__c', 'new_comment_email_template__c', 'orgwide_email_sender__c',
		'Account_limit_message__c', 'Account_Votes_per_Idea__c', 'ignore_vote_limit_field__c',
		'user_custom_fieldvalues__c', 'chatter_profile_list__c', 'vote_disable_status__c', 'chatter_permission_list__c',
		'auto_subscribe_idea_creators__c', 'auto_subscribe_idea_requestors__c',
		'idea_submission_email_template__c', 'enable_idea_extension_functionality__c',
		'account_filter_permission_set__c',
		'vote_show_alternate_message__c',
		'Disable_Read_Only_Users__c '
	};

	public x7sIdeasCommon(String setName) {
		nicknameEnabled = false;
		isAuthenticated = false;
		disableReadOnlyUsers = false;
		zoneId = '';
		voteDisableStatus = '';
		emailIdeaStatusTemplate = '';
		chatterProfiles = '';
		getCustomSettings(setName, false);
	}

	public x7sIdeasCommon(String setName, Boolean loadCustomFields) {
		this(setName);
		getCustomSettings(setName, loadCustomFields);
	}

	private void getCustomSettings(String name, Boolean loadCustomFields) {
		//String developerName = String.isNotBlank(name) ? name : System.Test.isRunningTest() ? IDEAS_UNIT_TEST_NAME : IDEAS_DEVELOPER_NAME;
		String developerName = String.isNotBlank(name) ? String.escapeSingleQuotes(name) : IDEAS_DEVELOPER_NAME;

		//String settingsQuery = x7sIdeasUtility.buildQuery(IDEAS_SETTINGS, '');

		String settingsQuery = 'SELECT ' + String.join(commonSettingsFields, ', ')
			+ ' FROM ' + IDEAS_SETTINGS
			+ ' WHERE DeveloperName = \'' + developerName + '\''
			+ ' LIMIT 1';
		//System.debug('Settings Query: ' + settingsQuery);

		//PMD : False positive, All variables are checked
		X7S_Ideas_Setting__mdt settings = (X7S_Ideas_Setting__mdt) Database.query(settingsQuery); //NOPMD

		if (settings != null) {
			this.debugMode = settings.Debug_Mode__c;
			this.allowDownVoting = settings.Allow_Down_Voting__c;
			this.orgWideFromEmailAddress = settings.OrgWide_Email_Sender__c;
			this.emailIdeaStatusTemplate = settings.Status_Change_Email_Template__c;
			this.emailIdeaCommentTemplate = settings.New_Comment_Email_Template__c;
			this.chatterProfiles = settings.Chatter_Profile_List__c;
			this.chatterPermissions = settings.Chatter_Permission_List__c;
			this.accountFilterPermissions = settings.Account_Filter_Permission_Set__c;
			this.showAlternateCTA = settings.Vote_Show_Alternate_Message__c;
			this.voteDisableStatus = settings.Vote_Disable_Status__c;
			this.disableReadOnlyUsers = settings.Disable_Read_Only_Users__c;
			this.ignoreVoteLimits = settings.Ignore_Vote_Limit_Field__c;

			this.sitePath = System.Site.getPathPrefix();
			this.lexMode = System.Network.getNetworkId() == null;
			this.canCreateNew = x7sIdeasUtility.isIdeaObjectCreateable();
			this.isAuthenticated = !Auth.CommunitiesUtil.isGuestUser();
			this.nicknameEnabled = x7sIdeasUtility.isNicknameDisplayEnabled();

			//dumpSettings(developerName, this);
		}
	}

	public static void dumpSettings(String title, x7sIdeasCommon settings) {
		System.debug('Dump Ideas settings : ' + title);
		System.debug('  debug            : ' + settings.debugMode);
		System.debug('  down voting      : ' + settings.allowDownVoting);
		System.debug('  sender email     : ' + settings.orgWideFromEmailAddress);
		System.debug('  status template  : ' + settings.emailIdeaStatusTemplate);
		System.debug('  comment template : ' + settings.emailIdeaCommentTemplate);
		System.debug('  account perm     : ' + settings.accountFilterPermissions);
		System.debug('  chatter perm     : ' + settings.chatterPermissions);
		System.debug('  chatter profiles : ' + settings.chatterProfiles);
		System.debug('  disable readonly : ' + settings.disableReadOnlyUsers);		
	}
}