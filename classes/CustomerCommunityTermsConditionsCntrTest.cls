/**
 * @Business: Test class for the CustomerCommunityTermsConditionsCntrl class
 * @Date: 2019-05-28
 * @Author: Cumulus Vision
 * Modified    ModifiedDate    Description
 *  TAN-773    2019-05-28      Initial Development
 *  SS-7294    2024-03-06      Add Test Methods
 */
@IsTest
private class CustomerCommunityTermsConditionsCntrTest {
	@TestSetup
	private static void makeData() {
		SBQQ.TriggerControl.disable();
		TriggerHandler.bypass(
			new List<String>{ 'AccountTriggerHandler', 'ContactTriggerHandler', 'UserTriggerHandler' }
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			Account acc = TestFactory.buildAccount('Grazitti');
			insert acc;

			Contact con = TestFactory.buildContact(acc.Id);
			insert con;

			User communityUser = TestUserFactory.createBasicUser(
				'CommunityUser',
				Utility.getProfileId('Customer Community User')
			);
			communityUser.ContactId = con.Id;
			communityUser.UserRoleId = null;
			insert communityUser;

			CollaborationGroup collabGroup = new CollaborationGroup(
				CollaborationType = 'Private',
				Description = 'Test CollabGroup',
				Name = 'Test CollabGroup'
			);
			insert collabGroup;

			Automation_Management__c autoManagement = new Automation_Management__c(
				EDR_Community_Group_Id__c = collabGroup.Id,
				Tanium_Endpoint_Management_Group__c = collabGroup.Id
			);
			insert autoManagement;
		}
	}

	@IsTest
	static void updateCommunityContact_WhenCommunityUserNotExists_ReturnNotValidUserError() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			CustomerCommunityTermsConditionsCntrl.ActionResult result = CustomerCommunityTermsConditionsCntrl.updateCommunityContact(
				UserInfo.getUserId()
			);

			Test.stopTest();

			Assert.isFalse(result.isSuccess);
			Assert.areEqual(
				CustomerCommunityTermsConditionsCntrl.INVALID_USER_MESSAGE,
				result.error,
				'Invalid user message should be returned.'
			);
		}
	}

	@IsTest
	static void updateCommunityContact_WhenDMLFailed_ReturnExceptionMessage() {
		User communityUser = [SELECT Id FROM User WHERE LastName = 'CommunityUser'];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			CustomerCommunityTermsConditionsCntrl.ActionResult result = CustomerCommunityTermsConditionsCntrl.updateCommunityContact(
				communityUser.Id
			);

			Test.stopTest();

			Assert.isFalse(result.isSuccess);
			Assert.isTrue(String.isNotBlank(result.error), 'Error message should be returned.');
		}
	}

	@IsTest
	static void updateCommunityContact_WhenCommunityUserExists_ReturnSuccessMsg() {
		User communityUser = [SELECT Id FROM User WHERE LastName = 'CommunityUser'];

		System.runAs(communityUser) {
			Test.startTest();
			CustomerCommunityTermsConditionsCntrl.ActionResult result = CustomerCommunityTermsConditionsCntrl.updateCommunityContact(
				UserInfo.getUserId()
			);

			Test.stopTest();
			Map<String, String> messageMap = (Map<String, String>) result.data;

			Assert.isTrue(result.isSuccess);
			Assert.areEqual(
				CustomerCommunityTermsConditionsCntrl.SUCCESS_MESSAGE,
				messageMap.get('message'),
				'Success message should be returned.'
			);
		}
	}

	@IsTest
	static void updateCommunityContactEndpointDiscussion_WhenCommunityUserNotExists_ReturnNotValidUserError() {
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			CustomerCommunityTermsConditionsCntrl.ActionResult result = CustomerCommunityTermsConditionsCntrl.updateCommunityContactEndpointDiscussion(
				UserInfo.getUserId()
			);

			Test.stopTest();

			Assert.isFalse(result.isSuccess);
			Assert.areEqual(
				CustomerCommunityTermsConditionsCntrl.INVALID_USER_MESSAGE,
				result.error,
				'Invalid user message should be returned.'
			);
		}
	}

	@IsTest
	static void updateCommunityContactEndpointDiscussion_WhenDMLFailed_ReturnExceptionMessage() {
		User communityUser = [SELECT Id FROM User WHERE LastName = 'CommunityUser'];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			CustomerCommunityTermsConditionsCntrl.ActionResult result = CustomerCommunityTermsConditionsCntrl.updateCommunityContactEndpointDiscussion(
				communityUser.Id
			);

			Test.stopTest();

			Assert.isFalse(result.isSuccess);
			Assert.isFalse(String.isBlank(result.error), 'Error message should be returned.');
		}
	}

	@IsTest
	static void updateCommunityContactEndpointDiscussion_WhenCommunityUserExists_ReturnSuccessMsg() {
		User communityUser = [SELECT Id FROM User WHERE LastName = 'CommunityUser'];

		System.runAs(communityUser) {
			Test.startTest();
			CustomerCommunityTermsConditionsCntrl.ActionResult result = CustomerCommunityTermsConditionsCntrl.updateCommunityContactEndpointDiscussion(
				UserInfo.getUserId()
			);

			Test.stopTest();
			Map<String, String> messageMap = (Map<String, String>) result.data;
			Assert.isTrue(result.isSuccess);
			Assert.areEqual(
				CustomerCommunityTermsConditionsCntrl.SUCCESS_MESSAGE,
				messageMap.get('message'),
				'Success message should be returned.'
			);
		}
	}
}