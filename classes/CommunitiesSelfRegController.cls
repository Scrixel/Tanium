/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: A controller that supports self registration of users in communities that allow self registration
 * @Date: 2017-12-04
 * @Authors: Cumulus Vision, Tanium Dev Team
 * RequestId  ModifiedDate   Description
 * TAN-456    2017-12-04     Added a method to detect if registration email is a personal email or corporate email
 * TAN-1002   2020-11-03     Added validations
 * SS-7070    2024-01-20     Added redirect validation
 * SS-7294    2024-03-05     Implement best practices
 * SS-7781    2024-03-26     Added method setCaptchaKeyValue
 * SS-10251   2025-02-27     Remove Constellant Dev references and replace it with Tanium Developer Users
 * SS-10404   2025-03-11     Assign Partner Case Access Permision Set
 * SS-12991   2026-04-03     Bugfixing: avoid singleton SOQL exceptions; reduced unnecessary logging
 * SS-13500   2026-07-24     Remove deprecated fields for project kondo group 2 contact
 */
public class CommunitiesSelfRegController {
	@TestVisible
	private static final Id TANIUM_COMMUNITY_LOGIN_AUTH_PROFILEID = Utility.getProfileId(
		'Tanium Community Login Authenticated'
	);
	@TestVisible
	private static final Id TANIUM_COMMUNITY_LOGIN_AUTH_CASE_PROFILEID = Utility.getProfileId(
		'Tanium Community Login Authenticated Case'
	);
	public static final List<String> ACCOUNTID_FOR_COMMUNITY_SELFREG = System.Label.Customer_Community_AccountIds.split(
		','
	);
	public String firstName { get; set; }
	public String lastName { get; set; }
	public String email { get; set; }
	public Boolean verified { get; set; }
	public String captchaKeyValue { get; set; }
	public String password {
		get;
		set {
			password = value == null ? value : value.trim();
		}
	}
	public String confirmPassword {
		get;
		set {
			confirmPassword = value == null ? value : value.trim();
		}
	}
	public String communityNickname {
		get;
		set {
			communityNickname = value == null ? value : value.trim();
		}
	}
	public List<String> userCreateErrors { get; private set; }

	public CommunitiesSelfRegController() {
		this.verified = false;
		userCreateErrors = new List<String>();
		setCaptchaKeyValue();
	}

	public void safeRecaptchaCallback() {
		verified = true;
	}

	public void setCaptchaKeyValue() {
		Boolean isSandbox = Utility.isSandbox();
		String instance = Utility.getInstance(Url.getOrgDomainURL());
		String captchaKeyValue;

		for (Instance_Setting__mdt instanceSetting : Instance_Setting__mdt.getAll().values()) {
			if (
				instanceSetting.IsActive__c &&
				instanceSetting.Instance__c == instance &&
				instanceSetting.Type__c == 'CommunitiesSelfRegCaptchaKey' &&
				instanceSetting.IsSandbox__c == isSandbox
			) {
				this.captchaKeyValue = instanceSetting.Value__c;
			}
		}
	}

	public PageReference registerUser() {
		if (!Test.isRunningTest()) {
			if (!verified) {
				return null;
			}
		}

		userCreateErrors = checkInputErrors(firstName, lastName, email, communityNickname);
		if (!userCreateErrors.isEmpty()) {
			return null;
		}

		Id profileId = getProfileId(email);
		String userId;
		String accountId = '';
		String userName = email;

		User u = new User(
			Username = userName,
			Email = email,
			FirstName = firstName,
			LastName = lastName,
			CommunityNickname = communityNickname,
			ProfileId = profileId
		);

		try {
			if (!isEmailDomainBlacklisted(Email)) {
				Contact contactRecord = checkContactIsExist(email);
				if (contactRecord != null) {
					User existingUser = checkUserisExist(contactRecord);
					if (existingUser != null) {
						userCreateErrors.add(
							'Uniqueness - Email: Email is already taken. Log in to your account or register with a different email address.'
						);
					} else {
						if (isEmailNotInUse(email)) {
							u.ContactId = contactRecord.Id;
							accountId = contactRecord.AccountId;
							userId = Site.createExternalUser(u, accountId, password);
							updateRelatedContact(contactRecord);
							setPermissionSet(userId, Constants.ZOOMIN_COMMUNITY_CLOUD_PERM_SET);
							setPermissionSet(userId, Constants.CONSTELLANT_DEV_PERM_SET);
							setPartnerCaseAccessPermissionSet(userId);
						} else {
							userCreateErrors.add(
								'Uniqueness - Email: Email is already taken. Log in to your account or register with a different email address.'
							);
						}
					}
				} else {
					if (isEmailNotInUse(email)) {
						userId = Site.createExternalUser(u, accountId, password);
						updateRelatedContact(userId);
						setPermissionSet(userId, Constants.CONSTELLANT_DEV_PERM_SET);
						setPermissionSet(userId, Constants.ZOOMIN_COMMUNITY_CLOUD_PERM_SET);
						setPartnerCaseAccessPermissionSet(userId);
					} else {
						userCreateErrors.add(
							'Uniqueness - Email: Email is already taken. Log in to your account or register with a different email address.'
						);
					}
				}
			} else {
				userCreateErrors.add(
					'Thank you for your registration interest, please note that registration must be with a corporate email address. This is a security measure; your email address will be kept confidential and will not be used for marketing purposes.'
				);
			}
		} catch (Site.ExternalUserCreateException ex) {
			List<String> errors = ex.getDisplayMessages();
			for (String error : errors) {
				userCreateErrors.add(error);
			}
		} catch (Exception ex) {
			Logger.error('CommunitiesSelfRegController.registerUser ERRORS', ex);
			Logger.saveLog();
		}

		if (userId != null) {
			if (password != null && password.length() > 1) {
				String redirectURL = Utility.isValidRedirectUrl(
						ApexPages.currentPage().getParameters().get('startURL')
					)
					? ApexPages.currentPage().getParameters().get('startURL')
					: '/';
				return Site.login(userName, password, redirectURL);
			} else {
				PageReference page = System.Page.CommunitiesSelfRegConfirm;
				page.setRedirect(true);
				return page;
			}
		}
		return null;
	}

	private static List<String> checkInputErrors(
		String firstName,
		String lastName,
		String email,
		String communityNickname
	) {
		List<String> inputErrors = new List<String>();

		if (String.isBlank(firstName)) {
			inputErrors.add('Missing Value: "First Name" is required.');
		} else if (firstName.length() > 40) {
			inputErrors.add('MaxLength: "First Name" must be less than 40 characters.');
		}

		if (String.isBlank(lastName)) {
			inputErrors.add('Missing Value: "Last Name" is required.');
		} else if (lastName.length() > 80) {
			inputErrors.add('MaxLength: "Last Name" must be less than 80 characters.');
		}

		if (String.isBlank(email)) {
			inputErrors.add('Missing Value: "Email" is required.');
		} else if (!email.contains('@')) {
			inputErrors.add('Format - Email: Invalid format.');
		}

		if (String.isBlank(communityNickname)) {
			inputErrors.add('Missing Value: "Nickname" is required.');
		} else if (communityNickname.length() > 40) {
			inputErrors.add('MaxLength: "Nickname" must be less than 40 characters.');
		}

		return inputErrors;
	}

	private static Boolean isEmailDomainBlacklisted(String email) {
		String[] emailParts = email.trim().split('@');
		String emailDomain = '';

		if (emailParts.size() == 2) {
			emailDomain = emailParts[1];
		}

		for (String blackListedDomain : Site_User_Blacklisted_Domains__c.getAll().keySet()) {
			if (emailDomain.toLowerCase() == blackListedDomain.toLowerCase()) {
				return true;
			}
		}

		return false;
	}

	public static Boolean isEmailNotInUse(String email) {
		List<User> existingUsers = [
			SELECT Id
			FROM User
			WHERE isActive = TRUE AND (Email = :email OR Username = :email)
		];
		return existingUsers.isEmpty();
	}

	public static User checkUserIsExist(Contact contactRecord) {
		User user;
		try {
			user = [SELECT Id FROM User WHERE ContactId = :contactRecord.Id AND isActive = TRUE];
		} catch (Exception e) {
			user = null;
		}
		return user;
	}

	public static Contact checkContactIsExist(String email) {
		Contact contact;
		try {
			contact = [SELECT Id, AccountId, Email FROM Contact WHERE Email = :email];
		} catch (Exception e) {
			contact = null;
		}
		return contact;
	}

	public static Id getAccountId(String email) {
		Id accountId = null;

		try {
			List<String> emailSplit = email.split('@');

			List<Rosco_domain__c> domain = [
				SELECT Account__c
				FROM Rosco_domain__c
				WHERE
					Name = :emailSplit[1]
					AND (user_automation__c = 'Account Only'
					OR user_automation__c = 'Support KB'
					OR user_automation__c = 'Support Case')
				LIMIT 1
			];

			if (!domain.isEmpty()) {
				accountId = domain[0].Account__c;
			}
		} catch (Exception e) {
			Logger.error('CommunitiesSelfRegController.getAccountId ERRORS', e);
			Logger.saveLog();
		}

		return accountId;
	}

	public static Id getProfileId(String email) {
		Id profileId = null;

		try {
			String existingContactAccount = '';

			List<Contact> contacts = [SELECT AccountId FROM Contact WHERE Email = :email];
			if (!contacts.isEmpty()) {
				existingContactAccount = contacts[0].AccountId;
			}

			List<String> emailSplit = email.split('@');

			for (Rosco_domain__c domain : [
				SELECT user_automation__c, Account__c
				FROM Rosco_domain__c
				WHERE
					Name = :emailSplit[1]
					AND (user_automation__c = 'Support KB'
					OR user_automation__c = 'Support Case')
				LIMIT 1
			]) {
				if (existingContactAccount == '' || domain.Account__c == existingContactAccount) {
					if (domain.user_automation__c == 'Support KB') {
						profileId = TANIUM_COMMUNITY_LOGIN_AUTH_PROFILEID;
					} else if (domain.user_automation__c == 'Support Case') {
						profileId = TANIUM_COMMUNITY_LOGIN_AUTH_CASE_PROFILEID;
					}
				}
			}
		} catch (Exception e) {
			Logger.error('CommunitiesSelfRegController.getProfileId ERRORS', e);
			Logger.saveLog();
		}

		return profileId;
	}

	@future
	public static void setPermissionSet(String userId, String permSetName) {
		if (String.isBlank(permSetName) || String.isBlank(userId)) {
			return;
		}

		try {
			if (permSetName == Constants.CONSTELLANT_DEV_PERM_SET) {
				User userRecord = [SELECT Profile.Name FROM User WHERE Id = :userId];
				if (userRecord.Profile.Name == Constants.TANIUM_COMMUNITY_UNKNOWN_PROFILE) {
					return;
				}
			}

			List<PermissionSetAssignment> assignments = [
				SELECT Id
				FROM PermissionSetAssignment
				WHERE PermissionSet.Name = :permSetName AND AssigneeId = :userId
			];

			if (assignments.isEmpty()) {
				Id permSetId = [SELECT Id FROM PermissionSet WHERE Name = :permSetName].Id;
				PermissionSetAssignment psa = new PermissionSetAssignment(
					PermissionSetId = permSetId,
					AssigneeId = userId
				);
				insert psa;
			}
		} catch (DmlException e) {
			Logger.error('CommunitiesSelfRegController.setPermissionSet ERRORS', e);
			Logger.saveLog();
		}
	}

	public static void updateRelatedContact(String userId) {
		try {
			User userRecord = [
				SELECT Id, ContactId, Email, Contact.AccountId
				FROM User
				WHERE Id = :userId
			];

			Contact contactRecord = new Contact(Id = userRecord.ContactId);
			if (ACCOUNTID_FOR_COMMUNITY_SELFREG.contains(userRecord.Contact.AccountId)) {
				Id accountId = getAccountId(userRecord.Email);
				if (accountId != null) {
					contactRecord.AccountId = accountId;
				}
			}
			update contactRecord;
		} catch (Exception e) {
			Logger.error('CommunitiesSelfRegController.updateRelatedContact ERRORS', e);
			Logger.saveLog();
		}
	}

	@future
	public static void setPartnerCaseAccessPermissionSet(String userId) {
		if (String.isBlank(userId)) {
			return;
		}

		Id partnerCaseAccessPermSetId = [
			SELECT Id
			FROM PermissionSet
			WHERE Name = :Constants.PARTNER_CASE_ACCESS
		]
		.Id;

		User userRecord = [
			SELECT
				Email,
				ContactId,
				Contact.AccountId,
				Contact.Account.Tech_Partner_Program_Tier__c,
				Profile.Name
			FROM User
			WHERE Id = :userId
		];

		List<String> email = userRecord.Email.split('@');
		String domain = email[1];
		Rosco_domain__c roscoDomain;

		try {
			roscoDomain = [
				SELECT Account__c
				FROM Rosco_domain__c
				WHERE Name = :domain AND Auto_register_developer_tanium_com__c = TRUE
				LIMIT 1
			];
		} catch (Exception e) {
			roscoDomain = null;
		}

		if (
			userRecord.Profile.Name == Constants.TANIUM_COMMUNITY_UNKNOWN_PROFILE ||
			roscoDomain == null
		) {
			return;
		}

		if (userRecord.Contact.Account.Tech_Partner_Program_Tier__c != null) {
			List<PermissionSetAssignment> assignments = [
				SELECT Id
				FROM PermissionSetAssignment
				WHERE PermissionSetId = :partnerCaseAccessPermSetId AND AssigneeId = :userId
			];

			if (assignments.isEmpty()) {
				PermissionSetAssignment psa = new PermissionSetAssignment(
					PermissionSetId = partnerCaseAccessPermSetId,
					AssigneeId = userId
				);

				Database.SaveResult saveResult = Database.insert(psa);
				Logger.logDatabaseErrors(
						LoggingLevel.ERROR,
						'CommunitiesSelfRegController.setPartnerCaseAccessPermissionSet Errors',
						new List<Database.SaveResult>{ saveResult }
					)
					.addTag('apex');
				Logger.saveLog();
			}
		}
	}

	public static void updateRelatedContact(Contact contactRecord) {
		try {
			if (ACCOUNTID_FOR_COMMUNITY_SELFREG.contains(contactRecord.AccountId)) {
				Id accountId = getAccountId(contactRecord.Email);
				if (accountId != null) {
					contactRecord.AccountId = accountId;
					update contactRecord;
				}
			}
		} catch (Exception e) {
			Logger.error('CommunitiesSelfRegController.updateRelatedContact ERRORS', e);
			Logger.saveLog();
		}
	}
}