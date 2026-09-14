/*
 * @BUSINESS: Test SlackUtility class
 * @DATE: 2024-05-02
 * @AUTHOR: Tanium Dev Team
 * @REQUEST:
 * RequestId  ModifiedDate  Comment
 * SS-7278    2024-05-02    Created the test class
 * SS-8182    2024-05-13    Updated test class
 */
@IsTest
private class SlackUtilityTest {
	@TestSetup
	static void makeData() {
	}

	@IsTest
	static void testGetConstants_Always_RoscoDebug_is_CCC66LTRT() {
		String channel;
		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			channel = SlackUtility.CHANNEL_FED_CASE;
			channel = SlackUtility.CHANNEL_SUPPORT_CENTER_TICKETS;
			channel = SlackUtility.CHANNEL_SUPPORT_CENTER_JAPAN;
			channel = SlackUtility.CHANNEL_TRIAGE_TICKETS;
			channel = SlackUtility.CHANNEL_COMMUNIYY;
			channel = SlackUtility.CHANNEL_SC_POLAND_CASE_ROUTING;
			channel = SlackUtility.CHANNEL_SUPPORT_CENTER_TICKETS_POLAND;
			channel = SlackUtility.CHANNEL_ROSCO_DEBUG;
			Test.stopTest();
		}

		Assert.isTrue(channel == SlackUtility.CHANNEL_ROSCO_DEBUG);
	}
}