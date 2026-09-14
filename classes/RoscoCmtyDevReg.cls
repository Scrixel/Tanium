/*
 * Copyright (c) 2026 Tanium
 *
 * @Business: RoscoCmtyDevReg without sharing class - supports community app
 * @Date: 3/2/2016
 * @Authors: Jason Johnson, Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-9264    2024-09-27    Updated method createDevRegCase plus class cleanup
 * SS-9624    2024-12-12    Remove reference to ThreadId_caseSensitive__c and replace it with the Threading token
 * SS-7124    2025-02-04    Added label to test emails in sandboxes after successful dev registration
 * SS-10251   2025-02-27    Remove Constellant Dev references and replace it with Tanium Developer Users
 * SS-10404   2025-03-11    Assign Partner Case Access Permision Set
 * SS-11173   2025-07-10    Changed field from Severity__c to Severity_Community__c and resolve issues
 * SS-13085   2026-04-23    Fixed issue with senderList being empty on Sandbox, throwing an exception - emails are sent only on PROD.
 * SS-13118   2026-04-24    Updated methods getDevRegInit, processDevRegistration
 * SS-13294   2026-05-19    Update method createUserPostProcessing
 * SS-13591   2026-07-14    Add security measure for recaptcha validation to prevent bot vulnerabilities
 * SS-13630   2026-07-17    Moved verify CAPTCHA to check once, to fix UI issues without weakening security
 */
public without sharing class RoscoCmtyDevReg {
	private static final reCaptchaGoogle__c recaptchaConfig = reCaptchaGoogle__c.getOrgDefaults();

	public static String createContact(
		String firstName,
		String lastName,
		String email,
		String phone,
		String accountId
	) {
		String ret = 'Error creating contact';

		try {
			String soql = 'SELECT Id ' + 'FROM Contact ' + 'WHERE Email = \'' + email + '\' LIMIT 1';

			List<Contact> contacts = Database.query(soql);
			if (contacts.isEmpty()) {
				Contact newC = new Contact(
					FirstName = firstName,
					LastName = lastName,
					Email = email,
					Phone = phone,
					AccountId = accountId
				);
				insert newC;
				ret = String.valueOf(newC.Id);
			} else {
				ret = String.valueOf(contacts[0].Id);
			}
		} catch (Exception e) {
			Map<String, String> inVar = new Map<String, String>();
			inVar.put('firstName', firstName);
			inVar.put('lastName', lastName);
			inVar.put('email', email);
			inVar.put('phone', phone);
			inVar.put('accountId', accountId);
			RoscoLog.addEntry(
				UserInfo.getUserId(),
				'Exception',
				'RoscoCmtyDevReg:createContact()',
				1,
				'Error',
				'Processing resulted in ' + ret,
				String.valueOf(JSON.serializePretty(inVar, true)),
				e.getMessage(),
				e.getStackTraceString()
			);
		}

		return ret;
	}

	public static String createDevRegCase(
		String type,
		String firstName,
		String lastName,
		String nickName,
		String email,
		String phone,
		String companyName,
		String companyURL,
		String companyDescription,
		String companyAddress,
		String companyAddress2,
		String companyAddressCity,
		String companyAddressState,
		String companyAddressZip,
		String companyAddressCountry,
		String companyReason
	) {
		String ret = 'Unknown error';

		try {
			String caseDescriptionTxt = '';
			String caseDescriptionHtml = '';

			String caseSubject = 'Technical Partnership Registration: ' + email;
			caseDescriptionHtml = '<br><br><b>Subject:</b> ' + caseSubject;

			if (!nullOrEmpty(firstName)) {
				caseDescriptionTxt += '\n\nFirst Name: ' + firstName;
				caseDescriptionHtml += '<br><br><b>First Name:</b> ' + firstName;
			}

			if (!nullOrEmpty(lastName)) {
				caseDescriptionTxt += '\n\nLast Name: ' + lastName;
				caseDescriptionHtml += '<br><br><b>Last Name:</b> ' + lastName;
			}

			if (!nullOrEmpty(nickName)) {
				caseDescriptionTxt += '\n\nNick Name: ' + nickName;
				caseDescriptionHtml += '<br><br><b>Nick Name:</b> ' + nickName;
			}

			if (!nullOrEmpty(email)) {
				caseDescriptionTxt += '\n\nEmail: ' + email;
				caseDescriptionHtml += '<br><br><b>Email:</b> ' + email;
			}

			if (!nullOrEmpty(phone)) {
				caseDescriptionTxt += '\n\nPhone: ' + phone;
				caseDescriptionHtml += '<br><br><b>Phone:</b> ' + phone;
			}

			if (!nullOrEmpty(companyName)) {
				caseDescriptionTxt += '\n\nCompany Name: ' + companyName;
				caseDescriptionHtml += '<br><br><b>Company Name:</b> ' + companyName;
			}

			if (!nullOrEmpty(companyURL)) {
				caseDescriptionTxt += '\n\nCompany URL: ' + companyURL;
				caseDescriptionHtml += '<br><br><b>Company URL:</b> ' + companyURL;
			}

			if (!nullOrEmpty(companyDescription)) {
				caseDescriptionTxt += '\n\nCompany Description: ' + companyDescription;
				caseDescriptionHtml += '<br><br><b>Company Description:</b> ' + companyDescription;
			}

			if (!nullOrEmpty(companyAddress)) {
				caseDescriptionTxt += '\n\nCompany Address: ' + companyAddress;
				caseDescriptionHtml += '<br><br><b>Company Address:</b> ' + companyAddress;
			}
			if (!nullOrEmpty(companyAddress2)) {
				if (companyAddress2.length() > 0) {
					caseDescriptionTxt += '\n\nCompany Address2: ' + companyAddress2;
					caseDescriptionHtml += '<br><br><b>Company Address2:</b> ' + companyAddress2;
				}
			}
			if (!nullOrEmpty(companyAddressCity)) {
				caseDescriptionTxt += '\n\nCompany Address City: ' + companyAddressCity;
				caseDescriptionHtml += '<br><br><b>Company Address City:</b> ' + companyAddressCity;
			}
			if (!nullOrEmpty(companyAddressState)) {
				caseDescriptionTxt += '\n\nCompany Address State: ' + companyAddressState;
				caseDescriptionHtml += '<br><br><b>Company State:</b> ' + companyAddressState;
			}
			if (!nullOrEmpty(companyAddressZip)) {
				caseDescriptionTxt += '\n\nCompany Address Zip: ' + companyAddressZip;
				caseDescriptionHtml += '<br><br><b>Company Zip:</b> ' + companyAddressZip;
			}
			if (!nullOrEmpty(companyAddressCountry)) {
				caseDescriptionTxt += '\n\nCompany Address Country: ' + companyAddressCountry;
				caseDescriptionHtml += '<br><br><b>Company Country:</b> ' + companyAddressCountry;
			}

			if (!nullOrEmpty(companyReason)) {
				caseDescriptionTxt += '\n\nCompany Reason for Interest: ' + companyReason;
				caseDescriptionHtml += '<br><br><b>Company Reason for Interest:</b> ' + companyReason;
			}

			if (type == 'Registration-New Partner') {
				caseDescriptionTxt +=
					'\n\nUser agreed to terms and conditions at: ' + String.valueOf(datetime.now());
				caseDescriptionHtml +=
					'<br><br><b>User agreed to terms and conditions at:</b> ' +
					String.valueOf(datetime.now());
			}

			Id contactId = [SELECT Id FROM Contact WHERE Email = :email].Id;
			Id accountId = [SELECT Id FROM Account WHERE Name = 'Tanium Support Transitory'].Id;

			QueueSobject supportQ = [
				SELECT QueueId
				FROM QueueSobject
				WHERE Queue.Name = 'Technical Partnerships'
			];
			String ownerId = String.valueOf(supportQ.QueueId);

			RecordType techPartnerRecordType = [
				SELECT Id
				FROM RecordType
				WHERE SobjectType = 'Case' AND DeveloperName = 'Technical_Partnerships'
				LIMIT 1
			];

			Case newCaseObj = new Case(
				Component__c = 'Other',
				Description = caseDescriptionTxt,
				ContactId = contactId,
				Origin = 'TechPartner',
				RecordTypeId = techPartnerRecordType.Id,
				Severity_Community__c = '3',
				Subject = caseSubject,
				Type = type,
				AccountId = String.valueOf(accountId),
				OwnerId = ownerId
			);

			insert newCaseObj;
			ret = newCaseObj.Id;

			String caseId = newCaseObj.Id;
			String soql2 = 'SELECT CaseNumber FROM Case ' + 'WHERE Id= \'' + caseId + '\'';

			List<Case> cases = Database.query(soql2);
			String threadid;
			String caseNumber;
			if (cases.size() != 0) {
				threadid = EmailMessages.getFormattedThreadingToken(cases[0].Id);
				caseNumber = String.valueOf(cases[0].CaseNumber);
			}

			// Get org wide sender id
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();
			String owea = '0D260000000XZFgCAO';

			// Send Email
			List<String> to = new List<String>();
			to.add(getSupportEmail());

			String emailSubject = '(Description->Email Slipstream) ' + threadid;
			String htmlBody = 'Case submitted via form:<br>' + caseDescriptionHtml;
			String textBody = 'Case submitted via form:\n' + caseDescriptionTxt;

			Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
			mail.setOrgWideEmailAddressId(owea);
			mail.setToAddresses(to);
			mail.setSubject(emailSubject);
			mail.setHtmlBody(htmlBody);
			mail.setPlainTextBody(textBody);
			if (!Utility.isSandbox()) {
				Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
			}
		} catch (Exception e) {
			ret = 'Error:' + e.getMessage();
			Map<String, String> inVar = new Map<String, String>();
			inVar.put('type', type);
			inVar.put('firstName', firstName);
			inVar.put('lastName', lastName);
			inVar.put('nickName', nickName);
			inVar.put('email', email);
			inVar.put('phone', phone);
			inVar.put('companyName', companyName);
			inVar.put('companyURL', companyURL);
			inVar.put('companyDescription', companyDescription);
			inVar.put('companyAddress', companyAddress);
			inVar.put('companyAddress2', companyAddress2);
			inVar.put('companyAddressCity', companyAddressCity);
			inVar.put('companyAddressState', companyAddressState);
			inVar.put('companyAddressZip', companyAddressZip);
			inVar.put('companyAddressCountry', companyAddressCountry);
			inVar.put('companyReason', companyReason);
			inVar.put('ret', ret);
			RoscoLog.addEntry(
				UserInfo.getUserId(),
				'Exception',
				'RoscoCmtyDevReg:createDevRegCase()',
				1,
				'Error',
				'Processing resulted in ' + ret,
				String.valueOf(JSON.serializePretty(inVar, true)),
				e.getMessage(),
				e.getStackTraceString()
			);
		}

		return ret;
	}

	public static String createUser(
		String firstName,
		String lastName,
		String nickName,
		String email,
		String contactId,
		String accountId
	) {
		String ret = 'Error creating community user';

		try {
			String soql = 'SELECT Id ' + 'FROM User ' + 'WHERE Email = \'' + email + '\' LIMIT 1';

			List<User> users = Database.query(soql);
			if (users.isEmpty()) {
				Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium Community Login Unknown']
				.Id;

				User newU = new User(
					Email = email,
					FirstName = firstName,
					LastName = lastName,
					UserName = email,
					Alias = nickName.substring(0, 7),
					CommunityNickName = nickName,
					TimeZoneSidKey = 'America/Los_Angeles',
					LocaleSidKey = 'en_US',
					EmailEncodingKey = 'ISO-8859-1',
					ProfileId = profileId,
					LanguageLocaleKey = 'en_US',
					ContactId = contactId
				);

				String userId = Site.createPortalUser(newU, accountId, '', true);
				ret = String.valueOf(userId);
				createUserPostProcessing(userId, email);
			} else {
				ret = String.valueOf(users[0].Id);
			}
		} catch (Exception e) {
			Map<String, String> inVar = new Map<String, String>();
			inVar.put('firstName', firstName);
			inVar.put('lastName', lastName);
			inVar.put('nickName', lastName);
			inVar.put('email', email);
			inVar.put('contactId', contactId);
			inVar.put('accountId', accountId);
			RoscoLog.addEntry(
				UserInfo.getUserId(),
				'Exception',
				'RoscoCmtyDevReg:createUser()',
				1,
				'Error',
				'Processing resulted in ' + ret,
				String.valueOf(JSON.serializePretty(inVar, true)),
				e.getMessage(),
				e.getStackTraceString()
			);
		}

		return ret;
	}

	@future
	public static void createUserPostProcessing(String userId, String email) {
		try {
			List<PermissionSetAssignment> psAssignments = new List<PermissionSetAssignment>();
			User u = [SELECT Id FROM User WHERE Id = :userId];
			u.FederationIdentifier = email;
			update u;

			Id constellantDevPermSetId = [
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

			Id zoominUserPermSetId = [
				SELECT Id
				FROM PermissionSet
				WHERE Name = :Constants.ZOOMIN_COMMUNITY_CLOUD_PERM_SET
			]
			.Id;

			psAssignments.add(
				new PermissionSetAssignment(
					PermissionSetId = constellantDevPermSetId,
					AssigneeId = u.Id
				)
			);

			psAssignments.add(
				new PermissionSetAssignment(
					PermissionSetId = partnerCaseAccessPermSetId,
					AssigneeId = u.Id
				)
			);

			psAssignments.add(
				new PermissionSetAssignment(PermissionSetId = zoominUserPermSetId, AssigneeId = u.Id)
			);

			List<Database.SaveResult> saveResult = Database.insert(psAssignments, false);
			Logger.logDatabaseErrors(
					LoggingLevel.ERROR,
					'RoscoCmtyDevReg.createUserPostProcessing Errors',
					saveResult
				)
				.addTag('apex');
			Logger.saveLog();
		} catch (Exception e) {
			Map<String, String> inVar = new Map<String, String>();
			inVar.put('userId', userId);
			inVar.put('email', email);
			RoscoLog.addEntry(
				UserInfo.getUserId(),
				'Exception',
				'RoscoCmtyDevReg:createUserPostProcessing()',
				1,
				'Error',
				'Failure Processing',
				String.valueOf(JSON.serializePretty(inVar, true)),
				e.getMessage(),
				e.getStackTraceString()
			);
		}
	}

	public static String getAccountIdDefault() {
		String ret = '0010e00001RcgMsAAJ';

		try {
			String soql =
				'SELECT Id ' +
				'FROM Account ' +
				'WHERE Name = \'Tanium Support Transitory\' LIMIT 1';

			String defAccountId = [SELECT Id FROM Account WHERE Name = 'Tanium Support Transitory'].Id;

			List<Account> accounts = Database.query(soql);
			if (!accounts.isEmpty()) {
				ret = accounts[0].Id;
			}
		} catch (Exception e) {
			RoscoLog.addEntry(
				UserInfo.getUserId(),
				'Exception',
				'RoscoCmtyDevReg:getAccountIdDefault()',
				1,
				'Error',
				'Processing resulted in ' + ret,
				'no arguments',
				e.getMessage(),
				e.getStackTraceString()
			);
		}

		return ret;
	}

	public static String getAccountIdFromContact(String email) {
		String ret = null;

		try {
			String soql =
				'SELECT AccountId ' +
				'FROM Contact ' +
				'WHERE Email = \'' +
				email +
				'\' LIMIT 1';

			List<Contact> contacts = Database.query(soql);
			if (!contacts.isEmpty()) {
				ret = contacts[0].AccountId;
			}
		} catch (Exception e) {
			Map<String, String> inVar = new Map<String, String>();
			inVar.put('email', email);
			RoscoLog.addEntry(
				UserInfo.getUserId(),
				'Exception',
				'RoscoCmtyDevReg:getAccountIdFromContact()',
				1,
				'Error',
				'Processing resulted in ' + ret,
				String.valueOf(JSON.serializePretty(inVar, true)),
				e.getMessage(),
				e.getStackTraceString()
			);
		}

		return ret;
	}

	public static String getAccountIdRoscoDomain(String email) {
		String ret = null;

		try {
			List<String> aEmail = email.split('@');
			String domain = aEmail[1];

			String soql =
				'SELECT Account__c ' +
				'FROM Rosco_domain__c ' +
				'WHERE name = \'' +
				domain +
				'\' ' +
				'AND Auto_register_developer_tanium_com__c = true LIMIT 1';

			List<Rosco_domain__c> rd = Database.query(soql);
			if (!rd.isEmpty()) {
				ret = rd[0].Account__c;
			}
		} catch (Exception e) {
			Map<String, String> inVar = new Map<String, String>();
			inVar.put('email', email);
			RoscoLog.addEntry(
				UserInfo.getUserId(),
				'Exception',
				'RoscoCmtyDevReg:getAccountIdRoscoDomain()',
				1,
				'Error',
				'Processing resulted in ' + ret,
				String.valueOf(JSON.serializePretty(inVar, true)),
				e.getMessage(),
				e.getStackTraceString()
			);
		}

		return ret;
	}

	public static List<Map<String, String>> getCountryCodes() {
		List<Map<String, String>> ret = new List<Map<String, String>>();

		// Temporarily hard mapping until Tanium org setup
		ret.add(new Map<String, String>{ 'value' => 'US', 'label' => 'United States' });
		ret.add(new Map<String, String>{ 'value' => 'AF', 'label' => 'Afghanistan' });
		ret.add(new Map<String, String>{ 'value' => 'AX', 'label' => 'Aland Islands' });
		ret.add(new Map<String, String>{ 'value' => 'AL', 'label' => 'Albania' });
		ret.add(new Map<String, String>{ 'value' => 'DZ', 'label' => 'Algeria' });
		ret.add(new Map<String, String>{ 'value' => 'AD', 'label' => 'Andorra' });
		ret.add(new Map<String, String>{ 'value' => 'AO', 'label' => 'Angola' });
		ret.add(new Map<String, String>{ 'value' => 'AI', 'label' => 'Anguilla' });
		ret.add(new Map<String, String>{ 'value' => 'AQ', 'label' => 'Antarctica' });
		ret.add(new Map<String, String>{ 'value' => 'AG', 'label' => 'Antigua and Barbuda' });
		ret.add(new Map<String, String>{ 'value' => 'AR', 'label' => 'Argentina' });
		ret.add(new Map<String, String>{ 'value' => 'AM', 'label' => 'Armenia' });
		ret.add(new Map<String, String>{ 'value' => 'AW', 'label' => 'Aruba' });
		ret.add(new Map<String, String>{ 'value' => 'AU', 'label' => 'Australia' });
		ret.add(new Map<String, String>{ 'value' => 'AT', 'label' => 'Austria' });
		ret.add(new Map<String, String>{ 'value' => 'AZ', 'label' => 'Azerbaijan' });
		ret.add(new Map<String, String>{ 'value' => 'BS', 'label' => 'Bahamas' });
		ret.add(new Map<String, String>{ 'value' => 'BH', 'label' => 'Bahrain' });
		ret.add(new Map<String, String>{ 'value' => 'BD', 'label' => 'Bangladesh' });
		ret.add(new Map<String, String>{ 'value' => 'BB', 'label' => 'Barbados' });
		ret.add(new Map<String, String>{ 'value' => 'BY', 'label' => 'Belarus' });
		ret.add(new Map<String, String>{ 'value' => 'BE', 'label' => 'Belgium' });
		ret.add(new Map<String, String>{ 'value' => 'BZ', 'label' => 'Belize' });
		ret.add(new Map<String, String>{ 'value' => 'BJ', 'label' => 'Benin' });
		ret.add(new Map<String, String>{ 'value' => 'BM', 'label' => 'Bermuda' });
		ret.add(new Map<String, String>{ 'value' => 'BT', 'label' => 'Bhutan' });
		ret.add(
			new Map<String, String>{ 'value' => 'BO', 'label' => 'Bolivia, Plurinational State of' }
		);
		ret.add(
			new Map<String, String>{ 'value' => 'BQ', 'label' => 'Bonaire, Sint Eustatius and Saba' }
		);
		ret.add(new Map<String, String>{ 'value' => 'BA', 'label' => 'Bosnia and Herzegovina' });
		ret.add(new Map<String, String>{ 'value' => 'BW', 'label' => 'Botswana' });
		ret.add(new Map<String, String>{ 'value' => 'BV', 'label' => 'Bouvet Island' });
		ret.add(new Map<String, String>{ 'value' => 'BR', 'label' => 'Brazil*' });
		ret.add(
			new Map<String, String>{ 'value' => 'IO', 'label' => 'British Indian Ocean Territory' }
		);
		ret.add(new Map<String, String>{ 'value' => 'BN', 'label' => 'Brunei Darussalam' });
		ret.add(new Map<String, String>{ 'value' => 'BG', 'label' => 'Bulgaria' });
		ret.add(new Map<String, String>{ 'value' => 'BF', 'label' => 'Burkina Faso' });
		ret.add(new Map<String, String>{ 'value' => 'BI', 'label' => 'Burundi' });
		ret.add(new Map<String, String>{ 'value' => 'KH', 'label' => 'Cambodia' });
		ret.add(new Map<String, String>{ 'value' => 'CM', 'label' => 'Cameroon' });
		ret.add(new Map<String, String>{ 'value' => 'CA', 'label' => 'Canada' });
		ret.add(new Map<String, String>{ 'value' => 'CV', 'label' => 'Cape Verde' });
		ret.add(new Map<String, String>{ 'value' => 'KY', 'label' => 'Cayman Islands' });
		ret.add(new Map<String, String>{ 'value' => 'CF', 'label' => 'Central African Republic' });
		ret.add(new Map<String, String>{ 'value' => 'TD', 'label' => 'Chad' });
		ret.add(new Map<String, String>{ 'value' => 'CL', 'label' => 'Chile' });
		ret.add(new Map<String, String>{ 'value' => 'CN', 'label' => 'China' });
		ret.add(new Map<String, String>{ 'value' => 'CX', 'label' => 'Christmas Island' });
		ret.add(new Map<String, String>{ 'value' => 'CC', 'label' => 'Cocos (Keeling) Islands' });
		ret.add(new Map<String, String>{ 'value' => 'CO', 'label' => 'Colombia' });
		ret.add(new Map<String, String>{ 'value' => 'KM', 'label' => 'Comoros' });
		ret.add(new Map<String, String>{ 'value' => 'CG', 'label' => 'Congo' });
		ret.add(
			new Map<String, String>{
				'value' => 'CD',
				'label' => 'Congo, the Democratic Republic of the'
			}
		);
		ret.add(new Map<String, String>{ 'value' => 'CK', 'label' => 'Cook Islands' });
		ret.add(new Map<String, String>{ 'value' => 'CR', 'label' => 'Costa Rica' });
		ret.add(new Map<String, String>{ 'value' => 'CI', 'label' => 'Cote d’Ivoire' });
		ret.add(new Map<String, String>{ 'value' => 'HR', 'label' => 'Croatia' });
		ret.add(new Map<String, String>{ 'value' => 'CU', 'label' => 'Cuba' });
		ret.add(new Map<String, String>{ 'value' => 'CW', 'label' => 'Curaçao' });
		ret.add(new Map<String, String>{ 'value' => 'CY', 'label' => 'Cyprus' });
		ret.add(new Map<String, String>{ 'value' => 'CZ', 'label' => 'Czech Republic' });
		ret.add(new Map<String, String>{ 'value' => 'DK', 'label' => 'Denmark' });
		ret.add(new Map<String, String>{ 'value' => 'DJ', 'label' => 'Djibouti' });
		ret.add(new Map<String, String>{ 'value' => 'DM', 'label' => 'Dominica' });
		ret.add(new Map<String, String>{ 'value' => 'DO', 'label' => 'Dominican Republic' });
		ret.add(new Map<String, String>{ 'value' => 'EC', 'label' => 'Ecuador' });
		ret.add(new Map<String, String>{ 'value' => 'EG', 'label' => 'Egypt' });
		ret.add(new Map<String, String>{ 'value' => 'SV', 'label' => 'El Salvador' });
		ret.add(new Map<String, String>{ 'value' => 'GQ', 'label' => 'Equatorial Guinea' });
		ret.add(new Map<String, String>{ 'value' => 'ER', 'label' => 'Eritrea' });
		ret.add(new Map<String, String>{ 'value' => 'EE', 'label' => 'Estonia' });
		ret.add(new Map<String, String>{ 'value' => 'ET', 'label' => 'Ethiopia' });
		ret.add(new Map<String, String>{ 'value' => 'FK', 'label' => 'Falkland Islands (Malvinas)' });
		ret.add(new Map<String, String>{ 'value' => 'FO', 'label' => 'Faroe Islands' });
		ret.add(new Map<String, String>{ 'value' => 'FJ', 'label' => 'Fiji' });
		ret.add(new Map<String, String>{ 'value' => 'FI', 'label' => 'Finland' });
		ret.add(new Map<String, String>{ 'value' => 'FR', 'label' => 'France' });
		ret.add(new Map<String, String>{ 'value' => 'GF', 'label' => 'French Guiana' });
		ret.add(new Map<String, String>{ 'value' => 'PF', 'label' => 'French Polynesia' });
		ret.add(new Map<String, String>{ 'value' => 'TF', 'label' => 'French Southern Territories' });
		ret.add(new Map<String, String>{ 'value' => 'GA', 'label' => 'Gabon' });
		ret.add(new Map<String, String>{ 'value' => 'GM', 'label' => 'Gambia' });
		ret.add(new Map<String, String>{ 'value' => 'GE', 'label' => 'Georgia' });
		ret.add(new Map<String, String>{ 'value' => 'DE', 'label' => 'Germany' });
		ret.add(new Map<String, String>{ 'value' => 'GH', 'label' => 'Ghana' });
		ret.add(new Map<String, String>{ 'value' => 'GI', 'label' => 'Gibraltar' });
		ret.add(new Map<String, String>{ 'value' => 'GR', 'label' => 'Greece' });
		ret.add(new Map<String, String>{ 'value' => 'GL', 'label' => 'Greenland' });
		ret.add(new Map<String, String>{ 'value' => 'GD', 'label' => 'Grenada' });
		ret.add(new Map<String, String>{ 'value' => 'GP', 'label' => 'Guadeloupe' });
		ret.add(new Map<String, String>{ 'value' => 'GT', 'label' => 'Guatemala' });
		ret.add(new Map<String, String>{ 'value' => 'GG', 'label' => 'Guernsey' });
		ret.add(new Map<String, String>{ 'value' => 'GN', 'label' => 'Guinea' });
		ret.add(new Map<String, String>{ 'value' => 'GW', 'label' => 'Guinea-Bissau' });
		ret.add(new Map<String, String>{ 'value' => 'GY', 'label' => 'Guyana' });
		ret.add(new Map<String, String>{ 'value' => 'HT', 'label' => 'Haiti' });
		ret.add(
			new Map<String, String>{ 'value' => 'HM', 'label' => 'Heard Island and McDonald Islands' }
		);
		ret.add(
			new Map<String, String>{ 'value' => 'VA', 'label' => 'Holy See (Vatican City State)' }
		);
		ret.add(new Map<String, String>{ 'value' => 'HN', 'label' => 'Honduras' });
		ret.add(new Map<String, String>{ 'value' => 'HU', 'label' => 'Hungary' });
		ret.add(new Map<String, String>{ 'value' => 'IS', 'label' => 'Iceland' });
		ret.add(new Map<String, String>{ 'value' => 'IN', 'label' => 'India' });
		ret.add(new Map<String, String>{ 'value' => 'ID', 'label' => 'Indonesia' });
		ret.add(new Map<String, String>{ 'value' => 'IR', 'label' => 'Iran, Islamic Republic of' });
		ret.add(new Map<String, String>{ 'value' => 'IQ', 'label' => 'Iraq' });
		ret.add(new Map<String, String>{ 'value' => 'IE', 'label' => 'Ireland*' });
		ret.add(new Map<String, String>{ 'value' => 'IM', 'label' => 'Isle of Man' });
		ret.add(new Map<String, String>{ 'value' => 'IL', 'label' => 'Israel' });
		ret.add(new Map<String, String>{ 'value' => 'IT', 'label' => 'Italy' });
		ret.add(new Map<String, String>{ 'value' => 'JM', 'label' => 'Jamaica' });
		ret.add(new Map<String, String>{ 'value' => 'JP', 'label' => 'Japan' });
		ret.add(new Map<String, String>{ 'value' => 'JE', 'label' => 'Jersey' });
		ret.add(new Map<String, String>{ 'value' => 'JO', 'label' => 'Jordan' });
		ret.add(new Map<String, String>{ 'value' => 'KZ', 'label' => 'Kazakhstan' });
		ret.add(new Map<String, String>{ 'value' => 'KE', 'label' => 'Kenya' });
		ret.add(new Map<String, String>{ 'value' => 'KI', 'label' => 'Kiribati' });
		ret.add(
			new Map<String, String>{
				'value' => 'KP',
				'label' => 'Korea, Democratic People’s Republic of'
			}
		);
		ret.add(new Map<String, String>{ 'value' => 'KR', 'label' => 'Korea, Republic of' });
		ret.add(new Map<String, String>{ 'value' => 'KW', 'label' => 'Kuwait' });
		ret.add(new Map<String, String>{ 'value' => 'KG', 'label' => 'Kyrgyzstan' });
		ret.add(
			new Map<String, String>{ 'value' => 'LA', 'label' => 'Lao People’s Democratic Republic' }
		);
		ret.add(new Map<String, String>{ 'value' => 'LV', 'label' => 'Latvia' });
		ret.add(new Map<String, String>{ 'value' => 'LB', 'label' => 'Lebanon' });
		ret.add(new Map<String, String>{ 'value' => 'LS', 'label' => 'Lesotho' });
		ret.add(new Map<String, String>{ 'value' => 'LR', 'label' => 'Liberia' });
		ret.add(new Map<String, String>{ 'value' => 'LY', 'label' => 'Libya' });
		ret.add(new Map<String, String>{ 'value' => 'LI', 'label' => 'Liechtenstein' });
		ret.add(new Map<String, String>{ 'value' => 'LT', 'label' => 'Lithuania' });
		ret.add(new Map<String, String>{ 'value' => 'LU', 'label' => 'Luxembourg' });
		ret.add(new Map<String, String>{ 'value' => 'MO', 'label' => 'Macao' });
		ret.add(
			new Map<String, String>{
				'value' => 'MK',
				'label' => 'Macedonia, the former Yugoslav Republic of'
			}
		);
		ret.add(new Map<String, String>{ 'value' => 'MG', 'label' => 'Madagascar' });
		ret.add(new Map<String, String>{ 'value' => 'MW', 'label' => 'Malawi' });
		ret.add(new Map<String, String>{ 'value' => 'MY', 'label' => 'Malaysia' });
		ret.add(new Map<String, String>{ 'value' => 'MV', 'label' => 'Maldives' });
		ret.add(new Map<String, String>{ 'value' => 'ML', 'label' => 'Mali' });
		ret.add(new Map<String, String>{ 'value' => 'MT', 'label' => 'Malta' });
		ret.add(new Map<String, String>{ 'value' => 'MQ', 'label' => 'Martinique' });
		ret.add(new Map<String, String>{ 'value' => 'MR', 'label' => 'Mauritania' });
		ret.add(new Map<String, String>{ 'value' => 'MU', 'label' => 'Mauritius' });
		ret.add(new Map<String, String>{ 'value' => 'YT', 'label' => 'Mayotte' });
		ret.add(new Map<String, String>{ 'value' => 'MX', 'label' => 'Mexico' });
		ret.add(new Map<String, String>{ 'value' => 'MD', 'label' => 'Moldova, Republic of' });
		ret.add(new Map<String, String>{ 'value' => 'MC', 'label' => 'Monaco' });
		ret.add(new Map<String, String>{ 'value' => 'MN', 'label' => 'Mongolia' });
		ret.add(new Map<String, String>{ 'value' => 'ME', 'label' => 'Montenegro' });
		ret.add(new Map<String, String>{ 'value' => 'MS', 'label' => 'Montserrat' });
		ret.add(new Map<String, String>{ 'value' => 'MA', 'label' => 'Morocco' });
		ret.add(new Map<String, String>{ 'value' => 'MZ', 'label' => 'Mozambique' });
		ret.add(new Map<String, String>{ 'value' => 'MM', 'label' => 'Myanmar' });
		ret.add(new Map<String, String>{ 'value' => 'NA', 'label' => 'Namibia' });
		ret.add(new Map<String, String>{ 'value' => 'NR', 'label' => 'Nauru' });
		ret.add(new Map<String, String>{ 'value' => 'NP', 'label' => 'Nepal' });
		ret.add(new Map<String, String>{ 'value' => 'NL', 'label' => 'Netherlands' });
		ret.add(new Map<String, String>{ 'value' => 'NC', 'label' => 'New Caledonia' });
		ret.add(new Map<String, String>{ 'value' => 'NZ', 'label' => 'New Zealand' });
		ret.add(new Map<String, String>{ 'value' => 'NI', 'label' => 'Nicaragua' });
		ret.add(new Map<String, String>{ 'value' => 'NE', 'label' => 'Niger' });
		ret.add(new Map<String, String>{ 'value' => 'NG', 'label' => 'Nigeria' });
		ret.add(new Map<String, String>{ 'value' => 'NU', 'label' => 'Niue' });
		ret.add(new Map<String, String>{ 'value' => 'NF', 'label' => 'Norfolk Island' });
		ret.add(new Map<String, String>{ 'value' => 'NO', 'label' => 'Norway' });
		ret.add(new Map<String, String>{ 'value' => 'OM', 'label' => 'Oman' });
		ret.add(new Map<String, String>{ 'value' => 'PK', 'label' => 'Pakistan' });
		ret.add(new Map<String, String>{ 'value' => 'PS', 'label' => 'Palestine' });
		ret.add(new Map<String, String>{ 'value' => 'PA', 'label' => 'Panama' });
		ret.add(new Map<String, String>{ 'value' => 'PG', 'label' => 'Papua New Guinea' });
		ret.add(new Map<String, String>{ 'value' => 'PY', 'label' => 'Paraguay' });
		ret.add(new Map<String, String>{ 'value' => 'PE', 'label' => 'Peru' });
		ret.add(new Map<String, String>{ 'value' => 'PH', 'label' => 'Philippines' });
		ret.add(new Map<String, String>{ 'value' => 'PN', 'label' => 'Pitcairn' });
		ret.add(new Map<String, String>{ 'value' => 'PL', 'label' => 'Poland' });
		ret.add(new Map<String, String>{ 'value' => 'PT', 'label' => 'Portugal' });
		ret.add(new Map<String, String>{ 'value' => 'QA', 'label' => 'Qatar' });
		ret.add(new Map<String, String>{ 'value' => 'RE', 'label' => 'Reunion' });
		ret.add(new Map<String, String>{ 'value' => 'RO', 'label' => 'Romania' });
		ret.add(new Map<String, String>{ 'value' => 'RU', 'label' => 'Russian Federation' });
		ret.add(new Map<String, String>{ 'value' => 'RW', 'label' => 'Rwanda' });
		ret.add(new Map<String, String>{ 'value' => 'BL', 'label' => 'Saint Barthélemy' });
		ret.add(
			new Map<String, String>{
				'value' => 'SH',
				'label' => 'Saint Helena, Ascension and Tristan da Cunha'
			}
		);
		ret.add(new Map<String, String>{ 'value' => 'KN', 'label' => 'Saint Kitts and Nevis' });
		ret.add(new Map<String, String>{ 'value' => 'LC', 'label' => 'Saint Lucia' });
		ret.add(new Map<String, String>{ 'value' => 'MF', 'label' => 'Saint Martin (French part)' });
		ret.add(new Map<String, String>{ 'value' => 'PM', 'label' => 'Saint Pierre and Miquelon' });
		ret.add(
			new Map<String, String>{ 'value' => 'VC', 'label' => 'Saint Vincent and the Grenadines' }
		);
		ret.add(new Map<String, String>{ 'value' => 'WS', 'label' => 'Samoa' });
		ret.add(new Map<String, String>{ 'value' => 'SM', 'label' => 'San Marino' });
		ret.add(new Map<String, String>{ 'value' => 'ST', 'label' => 'Sao Tome and Principe' });
		ret.add(new Map<String, String>{ 'value' => 'SA', 'label' => 'Saudi Arabia' });
		ret.add(new Map<String, String>{ 'value' => 'SN', 'label' => 'Senegal' });
		ret.add(new Map<String, String>{ 'value' => 'RS', 'label' => 'Serbia' });
		ret.add(new Map<String, String>{ 'value' => 'SC', 'label' => 'Seychelles' });
		ret.add(new Map<String, String>{ 'value' => 'SL', 'label' => 'Sierra Leone' });
		ret.add(new Map<String, String>{ 'value' => 'SG', 'label' => 'Singapore' });
		ret.add(new Map<String, String>{ 'value' => 'SX', 'label' => 'Sint Maarten (Dutch part)' });
		ret.add(new Map<String, String>{ 'value' => 'SK', 'label' => 'Slovakia' });
		ret.add(new Map<String, String>{ 'value' => 'SI', 'label' => 'Slovenia' });
		ret.add(new Map<String, String>{ 'value' => 'SB', 'label' => 'Solomon Islands' });
		ret.add(new Map<String, String>{ 'value' => 'SO', 'label' => 'Somalia' });
		ret.add(new Map<String, String>{ 'value' => 'ZA', 'label' => 'South Africa' });
		ret.add(
			new Map<String, String>{
				'value' => 'GS',
				'label' => 'South Georgia and the South Sandwich Islands'
			}
		);
		ret.add(new Map<String, String>{ 'value' => 'SS', 'label' => 'South Sudan' });
		ret.add(new Map<String, String>{ 'value' => 'ES', 'label' => 'Spain' });
		ret.add(new Map<String, String>{ 'value' => 'LK', 'label' => 'Sri Lanka' });
		ret.add(new Map<String, String>{ 'value' => 'SD', 'label' => 'Sudan' });
		ret.add(new Map<String, String>{ 'value' => 'SR', 'label' => 'Suriname' });
		ret.add(new Map<String, String>{ 'value' => 'SJ', 'label' => 'Svalbard and Jan Mayen' });
		ret.add(new Map<String, String>{ 'value' => 'SZ', 'label' => 'Swaziland' });
		ret.add(new Map<String, String>{ 'value' => 'SE', 'label' => 'Sweden' });
		ret.add(new Map<String, String>{ 'value' => 'CH', 'label' => 'Switzerland' });
		ret.add(new Map<String, String>{ 'value' => 'SY', 'label' => 'Syrian Arab Republic' });
		ret.add(new Map<String, String>{ 'value' => 'TW', 'label' => 'Taiwan' });
		ret.add(new Map<String, String>{ 'value' => 'TJ', 'label' => 'Tajikistan' });
		ret.add(
			new Map<String, String>{ 'value' => 'TZ', 'label' => 'Tanzania, United Republic of' }
		);
		ret.add(new Map<String, String>{ 'value' => 'TH', 'label' => 'Thailand' });
		ret.add(new Map<String, String>{ 'value' => 'TL', 'label' => 'Timor-Leste' });
		ret.add(new Map<String, String>{ 'value' => 'TG', 'label' => 'Togo' });
		ret.add(new Map<String, String>{ 'value' => 'TK', 'label' => 'Tokelau' });
		ret.add(new Map<String, String>{ 'value' => 'TO', 'label' => 'Tonga' });
		ret.add(new Map<String, String>{ 'value' => 'TT', 'label' => 'Trinidad and Tobago' });
		ret.add(new Map<String, String>{ 'value' => 'TN', 'label' => 'Tunisia' });
		ret.add(new Map<String, String>{ 'value' => 'TR', 'label' => 'Turkey' });
		ret.add(new Map<String, String>{ 'value' => 'TM', 'label' => 'Turkmenistan' });
		ret.add(new Map<String, String>{ 'value' => 'TC', 'label' => 'Turks and Caicos Islands' });
		ret.add(new Map<String, String>{ 'value' => 'TV', 'label' => 'Tuvalu' });
		ret.add(new Map<String, String>{ 'value' => 'UG', 'label' => 'Uganda' });
		ret.add(new Map<String, String>{ 'value' => 'UA', 'label' => 'Ukraine' });
		ret.add(new Map<String, String>{ 'value' => 'AE', 'label' => 'United Arab Emirates' });
		ret.add(new Map<String, String>{ 'value' => 'GB', 'label' => 'United Kingdom' });
		ret.add(new Map<String, String>{ 'value' => 'UY', 'label' => 'Uruguay' });
		ret.add(new Map<String, String>{ 'value' => 'UZ', 'label' => 'Uzbekistan' });
		ret.add(new Map<String, String>{ 'value' => 'VU', 'label' => 'Vanuatu' });
		ret.add(
			new Map<String, String>{ 'value' => 'VE', 'label' => 'Venezuela, Bolivarian Republic of' }
		);
		ret.add(new Map<String, String>{ 'value' => 'VN', 'label' => 'Vietnam' });
		ret.add(new Map<String, String>{ 'value' => 'VG', 'label' => 'Virgin Islands, British' });
		ret.add(new Map<String, String>{ 'value' => 'WF', 'label' => 'Wallis and Futuna' });
		ret.add(new Map<String, String>{ 'value' => 'EH', 'label' => 'Western Sahara' });
		ret.add(new Map<String, String>{ 'value' => 'YE', 'label' => 'Yemen' });
		ret.add(new Map<String, String>{ 'value' => 'ZM', 'label' => 'Zambia' });
		ret.add(new Map<String, String>{ 'value' => 'ZW', 'label' => 'Zimbabwe' });

		return ret;
	}

	@AuraEnabled
	public static Map<String, Object> getDevRegInit() {
		Map<String, Object> ret = new Map<String, Object>();

		try {
			ret.put('logToConsole', 'false');

			ret.put('countryCodes', getCountryCodes());
			ret.put('siteKey', recaptchaConfig.siteKey__c);

			String loggedInUserName = UserInfo.getUserName();
			if (!loggedInUserName.containsIgnoreCase('tanium_customer_community@')) {
				ret.put('notLoggedIn', 'false');
				ret.put('email', UserInfo.getUserEmail());
				ret.put('firstName', UserInfo.getFirstName());
				ret.put('lastName', UserInfo.getLastName());

				String userId = UserInfo.getUserId();
				User u = [SELECT CommunityNickname FROM User WHERE Id = :userId];
				ret.put('nickName', u.CommunityNickname);
			} else {
				ret.put('notLoggedIn', 'true');
			}
		} catch (Exception e) {
			RoscoLog.addEntry(
				UserInfo.getUserId(),
				'Exception',
				'RoscoCmtyDevReg:getDevRegInit()',
				1,
				'Error',
				'Processing resulted in ' + ret,
				'no arguments',
				e.getMessage(),
				e.getStackTraceString()
			);
		}

		return ret;
	}

	public static String getSupportEmail() {
		String ret = '';

		try {
			String soql =
				'SELECT LocalPart, EmailDomainName ' +
				'FROM EmailServicesAddress ' +
				'WHERE FunctionId IN (SELECT ID FROM EmailServicesFunction WHERE FunctionName = \'Rosco Email Service\')';

			List<EmailServicesAddress> rs = Database.query(soql);
			if (!rs.isEmpty()) {
				ret = rs[0].LocalPart + '@' + rs[0].EmailDomainName;
			}
		} catch (Exception e) {
			RoscoLog.addEntry(
				UserInfo.getUserId(),
				'Exception',
				'RoscoCmtyDevReg:getSupportEmail()',
				1,
				'Error',
				'Processing resulted in ' + ret,
				'no arguments',
				e.getMessage(),
				e.getStackTraceString()
			);
		}

		return ret;
	}

	public static Boolean isEmailDomainBlacklisted(String email) {
		Boolean ret = true;

		try {
			Set<String> setBlacklistedDomain = new Set<String>();
			for (String blackListedDomain : Site_User_Blacklisted_Domains__c.getAll().keySet()) {
				setBlacklistedDomain.add(blackListedDomain.toLowerCase());
			}

			email = String.isBlank(email) ? '' : email;
			List<String> emailParts = email.trim().split('@');

			if (emailParts.size() == 2) {
				String emailDomain = emailParts[1];
				if (!setBlacklistedDomain.contains(emailDomain.toLowerCase())) {
					ret = false;
				}
			}
		} catch (Exception e) {
			Map<String, String> inVar = new Map<String, String>();
			inVar.put('email', email);
			RoscoLog.addEntry(
				UserInfo.getUserId(),
				'Exception',
				'RoscoCmtyDevReg:isEmailDomainBlacklisted()',
				1,
				'Error',
				'Processing resulted in ' + ret,
				String.valueOf(JSON.serializePretty(inVar, true)),
				e.getMessage(),
				e.getStackTraceString()
			);
		}

		return ret;
	}

	public static Boolean isExistingUser(String email) {
		Boolean ret = false;

		try {
			String soql =
				'SELECT Id ' +
				'FROM User ' +
				'WHERE IsActive = True ' +
				'AND Email = \'' +
				email +
				'\' LIMIT 1';

			List<User> users = Database.query(soql);
			if (!users.isEmpty()) {
				ret = true;
			}
		} catch (Exception e) {
			Map<String, String> inVar = new Map<String, String>();
			inVar.put('email', email);
			RoscoLog.addEntry(
				UserInfo.getUserId(),
				'Exception',
				'RoscoCmtyDevReg:isExistingUser()',
				1,
				'Error',
				'Processing resulted in ' + ret,
				String.valueOf(JSON.serializePretty(inVar, true)),
				e.getMessage(),
				e.getStackTraceString()
			);
		}

		return ret;
	}

	@AuraEnabled
	public static Boolean isExistingNickName(String nickName) {
		Boolean ret = false;

		try {
			User u = [SELECT Id FROM User WHERE CommunityNickname = :nickName];
			if (!nullOrEmpty(u)) {
				ret = true;
			}
		} catch (Exception e) {
			System.debug('isExistingNickName: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}

		return ret;
	}

	public static String modifyUser(
		String firstName,
		String lastName,
		String nickName,
		String email,
		String contactId,
		String accountId
	) {
		String ret = 'Error modifying community user';

		try {
			String soql =
				'SELECT Id ' +
				'FROM User ' +
				'WHERE Email = \'' +
				email +
				'\' ' +
				'AND IsActive = True ' +
				'LIMIT 1';

			List<User> users = Database.query(soql);
			if (!users.isEmpty()) {
				users[0].FirstName = firstName;
				users[0].LastName = lastName;
				users[0].CommunityNickName = nickName;
				update users[0];

				createUserPostProcessing(users[0].Id, email);

				ret = 'Processed User Async';
			}
		} catch (Exception e) {
			Map<String, String> inVar = new Map<String, String>();
			inVar.put('email', email);
			RoscoLog.addEntry(
				UserInfo.getUserId(),
				'Exception',
				'RoscoCmtyDevReg:modifyUser()',
				1,
				'Error',
				'Processing resulted in ' + ret,
				String.valueOf(JSON.serializePretty(inVar, true)),
				e.getMessage(),
				e.getStackTraceString()
			);
		}

		return ret;
	}

	public static Boolean nullOrEmpty(Object o) {
		return (null == o) ||
			((o instanceof String) && (0 == ((String) o).trim().length())) ||
			((o instanceof List<object>) && (0 == ((List<object>) o).size()));
	}

	@AuraEnabled
	public static String processDevRegistration(
		String firstName,
		String lastName,
		String nickName,
		String email,
		String phone,
		String companyName,
		String companyURL,
		String companyDescription,
		String companyAddress,
		String companyAddress2,
		String companyAddressCity,
		String companyAddressState,
		String companyAddressZip,
		String companyAddressCountry,
		String companyReason,
		String recaptchaResponse
	) {
		String ret = 'Unknown error';
		try {
			Boolean existingUser = isExistingUser(email);
			String loggedInUserEmail = UserInfo.getUserEmail();
			String dscAccountId = getAccountIdRoscoDomain(email);

			Boolean isUnknownCompanyPreCheck =
				!(existingUser &&
				UserInfo.getUserName().containsIgnoreCase('tanium_customer_community')) &&
				!(!UserInfo.getUserName().containsIgnoreCase('tanium_customer_community') &&
				(loggedInUserEmail.toLowerCase() != email.toLowerCase())) &&
				!isEmailDomainBlacklisted(email) &&
				dscAccountId == null &&
				nullOrEmpty(companyName);

			if (isUnknownCompanyPreCheck) {
				ret = 'Unknown email domain';
			} else {
				String recaptchaResult = verifyCaptcha(recaptchaResponse);
				if (!recaptchaResult.startsWithIgnoreCase('Success')) {
					RoscoLog.addEntry(
						UserInfo.getUserId(),
						'Audit',
						'RoscoCmtyDevReg:processDevRegistration()',
						1,
						'Warning',
						'reCAPTCHA rejected',
						null,
						null,
						null
					);
					return 'Captcha failed';
				}

				if (
					existingUser &&
					UserInfo.getUserName().containsIgnoreCase('tanium_customer_community')
				) {
					ret = 'Can not be modified unless logged in';
				} else if (
					!UserInfo.getUserName().containsIgnoreCase('tanium_customer_community') &&
					(loggedInUserEmail.toLowerCase() != email.toLowerCase())
				) {
					ret = 'Can not modify other users';
				} else if (isEmailDomainBlacklisted(email)) {
					ret = 'Please use corporate domain';
				} else {
					String defAccountId = getAccountIdDefault();
					String accountId = defAccountId;
					if (dscAccountId != null) {
						accountId = dscAccountId;
					}
					String contactId = createContact(firstName, lastName, email, phone, accountId);
					String conAccountId = getAccountIdFromContact(email);
					if (dscAccountId == null) {
						ret =
							'createDevRegCase returned:' +
							createDevRegCase(
								'Registration-New Partner',
								firstName,
								lastName,
								nickName,
								email,
								phone,
								companyName,
								companyURL,
								companyDescription,
								companyAddress,
								companyAddress2,
								companyAddressCity,
								companyAddressState,
								companyAddressZip,
								companyAddressCountry,
								companyReason
							);
					} else {
						if (conAccountId == dscAccountId)
							if (existingUser) {
								ret =
									'modifyUser returned:' +
									modifyUser(
										firstName,
										lastName,
										nickName,
										email,
										contactId,
										conAccountId
									);
							} else {
								ret =
									'createUser returned:' +
									createUser(
										firstName,
										lastName,
										nickName,
										email,
										contactId,
										dscAccountId
									);
							}
						else {
							ret =
								'createDevRegCase returned:' +
								createDevRegCase(
									'Registration-Contact Account mismatch',
									firstName,
									lastName,
									nickName,
									email,
									phone,
									companyName,
									companyURL,
									companyDescription,
									companyAddress,
									companyAddress2,
									companyAddressCity,
									companyAddressState,
									companyAddressZip,
									companyAddressCountry,
									companyReason
								);
						}
					}
				}
			}

			Map<String, String> inVar = new Map<String, String>();
			inVar.put('firstName', firstName);
			inVar.put('lastName', lastName);
			inVar.put('nickName', nickName);
			inVar.put('email', email);
			inVar.put('phone', phone);
			inVar.put('companyName', companyName);
			inVar.put('companyURL', companyURL);
			inVar.put('companyDescription', companyDescription);
			inVar.put('companyAddress', companyAddress);
			inVar.put('companyAddress2', companyAddress2);
			inVar.put('companyAddressCity', companyAddressCity);
			inVar.put('companyAddressState', companyAddressState);
			inVar.put('companyAddressZip', companyAddressZip);
			inVar.put('companyAddressCountry', companyAddressCountry);
			inVar.put('companyReason', companyReason);
			inVar.put('recaptchaResponse', recaptchaResponse);
			RoscoLog.addEntry(
				UserInfo.getUserId(),
				'Audit',
				'RoscoCmtyDevReg:processDevRegistration()',
				1,
				'Informational',
				'Processing resulted in ' + ret,
				String.valueOf(JSON.serializePretty(inVar, true)),
				null,
				null
			);
		} catch (Exception e) {
			Map<String, String> inVar = new Map<String, String>();
			inVar.put('firstName', firstName);
			inVar.put('lastName', lastName);
			inVar.put('nickName', nickName);
			inVar.put('email', email);
			inVar.put('phone', phone);
			inVar.put('companyName', companyName);
			inVar.put('companyURL', companyURL);
			inVar.put('companyDescription', companyDescription);
			inVar.put('companyAddress', companyAddress);
			inVar.put('companyAddress2', companyAddress2);
			inVar.put('companyAddressCity', companyAddressCity);
			inVar.put('companyAddressState', companyAddressState);
			inVar.put('companyAddressZip', companyAddressZip);
			inVar.put('companyAddressCountry', companyAddressCountry);
			inVar.put('companyReason', companyReason);
			inVar.put('recaptchaResponse', recaptchaResponse);
			inVar.put('ret', ret);
			RoscoLog.addEntry(
				UserInfo.getUserId(),
				'Exception',
				'RoscoCmtyDevReg:processDevRegistration()',
				1,
				'Error',
				'Processing resulted in ' + ret,
				String.valueOf(JSON.serializePretty(inVar, true)),
				e.getMessage(),
				e.getStackTraceString()
			);
		}

		return ret;
	}

	@future
	public static void slackInfo(String infoText) {
		try {
			// Custom settings may override some options
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();

			String slackChannel = 'CJ4PWL412';
			if (cmfields.contains('rosco_slack_exceptions__c')) {
				String soa = String.valueOf(cm.get('rosco_slack_exceptions__c'));

				if (nullOrEmpty(soa) == false) {
					slackChannel = soa;
				}
			}

			String webhookURL = 'https://hooks.slack.com/services/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';
			if (cmfields.contains('rosco_slack_incoming_hook__c')) {
				String hook = String.valueOf(cm.get('rosco_slack_incoming_hook__c'));

				if (nullOrEmpty(hook) == false) {
					webhookURL = hook;
				}
			}

			String slackText = 'RoscoCmtyDevReg debug ```' + infoText + '```';

			JSONGenerator soaGen = JSON.createGenerator(true);
			soaGen.writeStartObject();
			soaGen.writeStringField('channel', slackChannel);
			soaGen.writeStringField('icon_url', 'http://grapelabs.net/rosco/rosco.jpg');
			soaGen.writeStringField('text', slackText);
			soaGen.writeEndObject();
			String soaBody = soaGen.getAsString();
			if (!Test.isRunningTest()) {
				System.enqueueJob(new qCallOut(webhookURL, 'POST', soaBody));
			}
		} catch (Exception e) {
			Map<String, String> inVar = new Map<String, String>();
			inVar.put('infoText', infoText);
			RoscoLog.addEntry(
				UserInfo.getUserId(),
				'Exception',
				'RoscoCmtyDevReg:slackInfo()',
				1,
				'Error',
				'Failed to process',
				String.valueOf(JSON.serializePretty(inVar, true)),
				e.getMessage(),
				e.getStackTraceString()
			);
		}
	}

	@future
	public static void sendWelcomeEmail(String email) {
		try {
			Contact contact = [SELECT Id FROM Contact WHERE Email = :email];
			EmailTemplate tpl = (EmailTemplate) [
				SELECT Id
				FROM EmailTemplate
				WHERE DeveloperName = 'Communities_developers_tanium_com_enrollment'
				LIMIT 1
			];
			Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
			mail.setTemplateId(tpl.Id);
			mail.setTargetObjectId(contact.Id);
			String[] toAddresses = new List<String>{ email };
			mail.setToAddresses(toAddresses);

			List<Messaging.SendEmailResult> results = Messaging.sendEmail(
				new List<Messaging.SingleEmailMessage>{ mail }
			);
		} catch (Exception e) {
			Map<String, String> inVar = new Map<String, String>();
			inVar.put('email', email);
			RoscoLog.addEntry(
				UserInfo.getUserId(),
				'Exception',
				'RoscoCmtyDevReg:sendWelcomeEmail()',
				1,
				'Error',
				'Failed to process',
				String.valueOf(JSON.serializePretty(inVar, true)),
				e.getMessage(),
				e.getStackTraceString()
			);
		}
	}

	@future
	public static void writeFeedItem(String caseId, String text) {
		FeedItem fi = new FeedItem(
			Body = text,
			IsRichText = true,
			NetworkScope = 'AllNetworks',
			Type = 'TextPost',
			Visibility = 'InternalUsers',
			ParentId = caseId
		);
		insert fi;
	}

	public static String verifyCaptcha(String recaptchaResponse) {
		if (nullOrEmpty(recaptchaResponse)) {
			return 'Failed - No token';
		}

		String ret;
		try {
			Http http = new Http();
			HttpRequest request = new HttpRequest();
			request.setEndpoint(recaptchaConfig.endPoint__c);
			request.setMethod('POST');
			request.setTimeout(10000);
			request.setBody(
				'secret=' +
				recaptchaConfig.secretKey__c +
				'&response=' +
				recaptchaResponse
			);
			HttpResponse response = http.send(request);

			if (response.getStatusCode() != 200) {
				ret = 'Failed - HTTP ' + response.getStatusCode();
			} else {
				Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
					response.getBody()
				);

				ret = (result.get('success') == true)
					? 'Success - v2'
					: 'Failed - ' + String.valueOf(result.get('error-codes'));
			}
		} catch (Exception e) {
			ret = 'Failed - Exception';
			Map<String, String> inVar = new Map<String, String>{
				'recaptchaResponse' => recaptchaResponse
			};
			RoscoLog.addEntry(
				UserInfo.getUserId(),
				'Exception',
				'RoscoCmtyDevReg:verifyCaptcha()',
				1,
				'Error',
				'Failed to process',
				String.valueOf(JSON.serializePretty(inVar, true)),
				e.getMessage(),
				e.getStackTraceString()
			);
		}
		return ret;
	}

	public class qCallOut implements System.Queueable, Database.AllowsCallouts {
		private final String url;
		private final String method;
		private final String body;

		public qCallOut(String url, String method, String body) {
			this.url = url;
			this.method = method;
			this.body = body;
		}

		public void execute(System.QueueableContext ctx) {
			HttpRequest req = new HttpRequest();
			req.setEndpoint(url);
			req.setMethod(method);
			req.setBody(body);
			Http http = new Http();
			HttpResponse res = http.send(req);
		}
	}
}