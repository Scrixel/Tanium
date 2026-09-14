/*
 * @BUSINESS: Test methods for class DevPortalCaseController
 * @DATE: 2025-02-19
 * @AUTHOR: Tanium Dev Team
 * @REQUEST:
 * RequestId  ModifiedDate  Comment
 * SS-7142   2025-02-15     Created
 */
@IsTest
private class DevPortalCaseControllerTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler' });

		System.runAs(TestUserFactory.getAdminUser()) {
			Account acct = TestFactory.buildAccount('Test Account');
			insert acct;

			ContentVersion contentVersion = new ContentVersion(
				Title = 'Test Uploaded File',
				PathOnClient = '/Test Uploaded File.png',
				VersionData = Blob.valueOf('Test Uploaded File'),
				CreatedDate = System.today().addDays(-100)
			);
			insert contentVersion;
		}
	}

	@IsTest
	static void testCreateCase_WhenCaseFieldsArePopulated_CreateCaseRecord() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Id tecnicalPartnershipsRecordTypeId = Utility.getRecordTypeIdByAPIName(
				'Case',
				'Technical_Partnerships'
			);
			Account account = [SELECT Id FROM Account LIMIT 1];
			Case caseRecord = TestFactory.buildCase(account.Id);
			caseRecord.RecordTYpeId = tecnicalPartnershipsRecordTypeId;
			caseRecord.Description = 'Test Case';
			caseRecord.Subject = 'Test Case Subject';

			ContentDocument contentDoc = [SELECT Id FROM ContentDocument LIMIT 1];

			Test.startTest();
			Case createdCase = DevPortalCaseController.createCase(
				caseRecord,
				new List<String>{ contentDoc.Id }
			);
			Test.stopTest();

			Assert.isNotNull(createdCase, 'Case created');
		}
	}

	@IsTest
	static void testCreateCase_WhenCaseIsNull_ThrowAnException() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Boolean hasException = false;

			Test.startTest();
			try {
				Case createdCase = DevPortalCaseController.createCase(null, new List<String>());
			} catch (Exception ex) {
				hasException = true;
			}
			Test.stopTest();

			Assert.isTrue(hasException, 'Exception encountered');
		}
	}
}