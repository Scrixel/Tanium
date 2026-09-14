@isTest
class RoscoSandboxTest {
	@isTest
	static void testMySandboxPrep() {
		// Insert logic here to create records of the objects that the class you’re testing
		// manipulates.

		Test.startTest();

		Profile p = [SELECT Id FROM Profile WHERE Name = 'Tanium System Administrator'];
		User userObj = new User(
			Email = 'roscosandbox@tanium.com.invalid',
			FirstName = 'Rosco',
			LastName = 'Sandbox',
			Username = 'roscosandbox@tanium.com.random',
			Alias = 'roscobox',
			TimeZoneSidKey = 'America/Los_Angeles',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'ISO-8859-1',
			LanguageLocaleKey = 'en_US',
			ProfileId = p.Id
		);
		insert userObj;

		Test.testSandboxPostCopyScript(
			new RoscoSandbox(),
			UserInfo.getOrganizationId(),
			UserInfo.getOrganizationId(),
			UserInfo.getOrganizationName()
		);

		Test.stopTest();

		// Insert assert statements here to check that the records you created above have
		// the values you expect.
	}
}