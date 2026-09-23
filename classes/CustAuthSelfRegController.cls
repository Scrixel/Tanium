/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: A controller that supports self registration of users in cust-auth digital experience
 * @Date: 2026-08-11
 * @Authors: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-13683   2026-08-11    Created the controller class
 */
public without sharing class CustAuthSelfRegController {
	@TestVisible
	private static final Id TANIUM_COMMUNITY_LOGIN_AUTH_PROFILE_ID = Utility.getProfileId(
		'Tanium Community Login Authenticated'
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

	public String communityNickname {
		get;
		set {
			communityNickname = value == null ? value : value.trim();
		}
	}
	public List<String> userRegistrationErrors { get; private set; }

	public CustAuthSelfRegController() {
		this.verified = false;
		userRegistrationErrors = new List<String>();
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
		if (!Test.isRunningTest() && !verified) {
			return null;
		}

		userRegistrationErrors = getInputErrors(firstName, lastName, email, communityNickname);

		if (!userRegistrationErrors.isEmpty()) {
			return null;
		}

		if (isBlockedEmailDomain(email)) {
			userRegistrationErrors.add(System.Label.CustAuth_Blocked_Email_Domain);
		}

		Contact existingContact = getContact(email);

		if (
			(existingContact == null && userWithEmailExists(email)) ||
			(existingContact != null && userWithContactIdExists(existingContact.Id))
		) {
			userRegistrationErrors.add(System.Label.CustAuth_User_Exists);
		} else {
			if (existingContact != null) {
				userRegistrationErrors.add(System.Label.CustAuth_Contact_Exists);
			}
		}

		if (!userRegistrationErrors.isEmpty()) {
			return null;
		}

		Id profileId = TANIUM_COMMUNITY_LOGIN_AUTH_PROFILE_ID;
		Id userId;
		Id accountId = existingContact != null ? existingContact.AccountId : getAccountId(email);
		String userName = email;

		User user = new User(
			Username = userName,
			Email = email,
			FirstName = firstName,
			LastName = lastName,
			CommunityNickname = communityNickname,
			ProfileId = profileId
		);

		if (existingContact != null) {
			user.ContactId = existingContact.Id;
		}

		try {
			userId = Site.createExternalUser(user, String.valueOf(accountId), password);
		} catch (Site.ExternalUserCreateException e) {
			userRegistrationErrors.add(e.getMessage());
			Logger.Error('CustAuthSelfRegController.Site.createExternalUser ERRORS', e);
			Logger.saveLog();
		}

		if (existingContact == null && userId != null) {
			setAccountIdOnNewlyCreatedContact(userId);
		}

		if (userId == null && !Test.isRunningTest()) {
			userRegistrationErrors.add(System.Label.CustAuth_Error_Creating_User);
			return null;
		}

		if (password != null && password.length() > 1) {
			String redirectURL = Utility.isValidRedirectUrl(
					ApexPages.currentPage().getParameters().get('startURL')
				)
				? ApexPages.currentPage().getParameters().get('startURL')
				: '/';
			return Site.login(userName, password, redirectURL);
		} else {
			PageReference page = System.Page.CustAuthSelfRegConfirm;
			page.setRedirect(true);
			return page;
		}
	}

	private static List<String> getInputErrors(
		String firstName,
		String lastName,
		String email,
		String communityNickname
	) {
		List<String> inputErrors = new List<String>();

		if (String.isBlank(firstName)) {
			inputErrors.add(System.Label.CustAuth_FirstName_Required);
		} else if (firstName.length() > 40) {
			inputErrors.add(System.Label.CustAuth_FirstName_MaxLength);
		}

		if (String.isBlank(lastName)) {
			inputErrors.add(System.Label.CustAuth_LastName_Required);
		} else if (lastName.length() > 80) {
			inputErrors.add(System.Label.CustAuth_LastName_MaxLength);
		}

		if (String.isBlank(email)) {
			inputErrors.add(System.Label.CustAuth_Email_Required);
		} else if (!email.contains('@') || !email.contains('.')) {
			inputErrors.add(System.Label.CustAuth_Invalid_Email);
		}

		if (String.isBlank(communityNickname)) {
			inputErrors.add(System.Label.CustAuth_NickName_Required);
		} else if (communityNickname.length() > 40) {
			inputErrors.add(System.Label.CustAuth_NickName_MaxLength);
		}

		return inputErrors;
	}

	private static Boolean isBlockedEmailDomain(String email) {
		String emailDomain = email.substringAfter('@');
		Boolean isBlocklisted = false;

		for (String blockListedDomain : Domain_Blacklist__c.getAll().keySet()) {
			if (emailDomain.toLowerCase() == blockListedDomain.toLowerCase()) {
				isBlocklisted = true;
			}
		}
		return isBlocklisted;
	}

	public static Boolean userWithEmailExists(String email) {
		List<User> users = [
			SELECT Id
			FROM User
			WHERE IsActive = TRUE AND (Email = :email OR Username = :email)
		];
		return !users.isEmpty();
	}

	public static Boolean userWithContactIdExists(Id contactId) {
		List<User> users = [
			SELECT Id
			FROM User
			WHERE IsActive = TRUE AND ContactId = :contactId
		];
		return !users.isEmpty();
	}

	public static Contact getContact(String email) {
		List<Contact> contacts = [
			SELECT Id, AccountId, Email
			FROM Contact
			WHERE Email = :email
			ORDER BY CreatedDate DESC
		];
		return contacts.isEmpty() ? null : contacts[0];
	}

	public static Id getAccountId(String email) {
		Id accountId = null;
		String domain = email.substringAfter('@');

		List<Account> accounts = [SELECT Id FROM Account WHERE Domain__c = :domain];
		return accounts.isEmpty() ? ACCOUNTID_FOR_COMMUNITY_SELFREG[0] : accounts[0].Id;
	}

	public static void setAccountIdOnNewlyCreatedContact(Id userId) {
		User user = [SELECT Id, ContactId, Email, Contact.AccountId FROM User WHERE Id = :userId];
		Contact contact = new Contact(Id = user.ContactId);
		if (ACCOUNTID_FOR_COMMUNITY_SELFREG.contains(user.Contact.AccountId)) {
			Id accountId = getAccountId(user.Email);
			if (accountId != null) {
				contact.AccountId = accountId;
			}
		}

		List<Database.SaveResult> saveResults = Database.update(new List<Contact>{ contact }, false);
		Logger.logDatabaseErrors(
				LoggingLevel.ERROR,
				'CustAuthSelfRegController.setAccountIdOnNewlyCreatedContact ERRORS',
				saveResults
			)
			.addTag('apex');
		Logger.saveLog();
	}
}