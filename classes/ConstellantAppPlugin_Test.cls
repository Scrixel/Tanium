@isTest
private class ConstellantAppPlugin_Test {
	@TestSetup
	static void makeData() {
		System.runAs(TestUserFactory.getAdminUser()) {
			User internalUser = TestFactory.buildUser(
				'Guy',
				'test' +
				Math.random() +
				'@tanium.com',
				'TestGuy',
				UserInfo.getProfileId()
			);
			insert internalUser;

			Account acct = TestFactory.buildAccount('Test Account');
			insert acct;
			Contact contct = TestFactory.buildContact(acct.Id);
			insert contct;
			User externalUser = TestFactory.buildUser(
				'Portal',
				'test' +
				Math.random() +
				'@tanium.com',
				'PortalGy',
				[SELECT Id FROM Profile WHERE Name = 'Customer Community User' LIMIT 1]
				.Id
			);
			externalUser.ContactId = contct.Id;
			insert externalUser;

			Account partnerAcct = TestFactory.buildAccount('Partner Account');
			partnerAcct.Type = ConstellantAppPlugin.CUSTOMER_ACCOUNT_TYPES[0];
			partnerAcct.RecordTypeId = ConstellantAppPlugin.PARTNER_RECORD_TYPE_ID;
			insert partnerAcct;
			Contact partnerContct = TestFactory.buildContact(partnerAcct.Id);
			insert partnerContct;
			User partnerUser = TestFactory.buildUser(
				'Partner',
				'test' +
				Math.random() +
				'@tanium.com',
				'PartnrGy',
				[SELECT Id FROM Profile WHERE Name = 'Customer Community User' LIMIT 1]
				.Id
			);
			partnerUser.ContactId = partnerContct.Id;
			insert partnerUser;
		}
	}

	@isTest
	static void customAttributes_WhenInternalUserAuthenticates_ThrowsException() {
		User internalUser = [SELECT Id FROM User WHERE alias = 'TestGuy'];

		Id constellantAppId = [
			SELECT Id
			FROM ConnectedApplication
			WHERE Name LIKE '%Constellant%'
			LIMIT 1
		]
		.Id;

		String actual = '';

		Test.startTest();
		try {
			ConstellantAppPlugin plugin = new ConstellantAppPlugin();
			plugin.customAttributes(
				internalUser.Id,
				constellantAppId,
				new Map<String, String>(),
				Auth.InvocationContext.SAML_ASSERTION
			);
		} catch (Exception error) {
			actual = error.getMessage();
		}
		Test.stopTest();

		System.assert(actual.contains(ConstellantAppPlugin.USER_WITHOUT_CONTACT));
	}

	@isTest
	static void customAttributes_WhenExternalUserNotPartnerOrCustomer_ThrowsException() {
		User externalUser = [SELECT Id FROM User WHERE alias = 'PortalGy'];

		Id constellantAppId = [
			SELECT Id
			FROM ConnectedApplication
			WHERE Name LIKE '%Constellant%'
			LIMIT 1
		]
		.Id;

		String actual = '';

		Test.startTest();
		try {
			ConstellantAppPlugin plugin = new ConstellantAppPlugin();
			plugin.customAttributes(
				externalUser.Id,
				constellantAppId,
				new Map<String, String>(),
				Auth.InvocationContext.SAML_ASSERTION
			);
		} catch (Exception error) {
			actual = error.getMessage();
		}
		Test.stopTest();

		System.assert(actual.contains(ConstellantAppPlugin.ACCOUNT_NOT_PARTNER_OR_CUSTOMER));
	}

	@isTest
	static void customAttributes_PartnerUserAuthenticates_ReturnsMapOfAttributes() {
		User partnerUser = [SELECT Id FROM User WHERE alias = 'PartnrGy'];
		Id constellantAppId = [
			SELECT Id
			FROM ConnectedApplication
			WHERE Name LIKE '%Constellant%'
			LIMIT 1
		]
		.Id;

		Test.startTest();
		ConstellantAppPlugin plugin = new ConstellantAppPlugin();
		Map<String, String> actual = plugin.customAttributes(
			partnerUser.Id,
			constellantAppId,
			new Map<String, String>(),
			Auth.InvocationContext.SAML_ASSERTION
		);
		Test.stopTest();

		Map<String, String> expected = new Map<String, String>{ 'lastName' => 'Partner' };

		for (String key : expected.keySet()) {
			System.assertEquals(expected.get(key), actual.get(key));
		}
	}

	@isTest
	static void customAttributes_CustomerUserAuthenticates_ReturnsMapOfAttributes() {
		User customerUser = [SELECT Id FROM User WHERE alias = 'PartnrGy'];
		Id constellantAppId = [
			SELECT Id
			FROM ConnectedApplication
			WHERE Name LIKE '%Constellant%'
			LIMIT 1
		]
		.Id;

		Test.startTest();
		ConstellantAppPlugin plugin = new ConstellantAppPlugin();
		Map<String, String> actual = plugin.customAttributes(
			customerUser.Id,
			constellantAppId,
			new Map<String, String>(),
			Auth.InvocationContext.SAML_ASSERTION
		);
		Test.stopTest();

		Map<String, String> expected = new Map<String, String>{ 'lastName' => 'Partner' };

		for (String key : expected.keySet()) {
			System.assertEquals(expected.get(key), actual.get(key));
		}
	}
}