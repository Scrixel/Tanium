/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Testclass for class Constants
 * @Date:     2025-02-28
 * @Author:   Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-10251   2025-02-28    Created the test class
 * SS-10546   2025-03-11    Updated test class to cover PARTNER_CASE_ACCESS
 * SS-10404   2025-04-01    Updated test class to cover ZOOMIN_COMMUNITY_CLOUD_PERM_SET, TANIUM_COMMUNITY_UNKNOWN_PROFILE
 * SS-10474   2025-05-15    Updated test class to cover TANIUM_DSA_USER_ID
 * SS-11999   2025-11-03    Updated test class to cover TANIUM_CUSTOMER_COMMUNITY, TANIUM_CUSTOMER_COMMUNITY_ID
 * SS-12082   2025-11-19    Updated test class to cover CUSTOMER_COMMUNITY_MANAGER_ID
 * SS-12298   2026-01-13    Updated test class to cover CASE_CLOSE_STATUSES
 * SS-12496   2026-02-24    Updated test class to cover DELETE_LEADS_AND_CONTACTS_PERMISSION
 * SS-12847   2026-03-27    Updated test class to cover SALES_SYSTEMS_USER_ID
 * SS-13423   2026-06-24    Updated test class to cover SERVICE_CLOUD_TANIUM_USER_ID
 * SS-13834   2026-08-24    Updated test class to cover PAID_AI_CREDIT_PRODUCT_CODES
 */
@IsTest
private class ConstantsTest {
	@IsTest
	static void testConstants_Always_ReturnConstants() {
		String taniumDeveloperPermSet = Constants.TANIUM_DEVELOPER_USERS_PERM_SET;
		String constellantPermSet = Constants.CONSTELLANT_DEV_PERM_SET;
		String communityPlaybookIdeasId = Constants.COMMUNITY_PLAYBOOK_IDEAS_ID;
		String partnerCaseAccessPermSet = Constants.PARTNER_CASE_ACCESS;
		String zoominCommunityCloudPermSet = Constants.ZOOMIN_COMMUNITY_CLOUD_PERM_SET;
		String taniumCommunityUnknownProfile = Constants.TANIUM_COMMUNITY_UNKNOWN_PROFILE;
		String taniumDsaUserId = Constants.TANIUM_DSA_USER_ID;
		String taniumCustomerCommunity = Constants.TANIUM_CUSTOMER_COMMUNITY;
		String taniumCustomerCommunityId = Constants.TANIUM_CUSTOMER_COMMUNITY_ID;
		Id customerCommunityManagerId = Constants.CUSTOMER_COMMUNITY_MANAGER_ID;
		List<String> caseCloseStatuses = Constants.CASE_CLOSE_STATUSES;
		String caseCloseSummary = Constants.CASE_CLOSE_SUMMARY;
		String deleteLeadsAndContactsPermission = Constants.DELETE_LEADS_AND_CONTACTS_PERMISSION;
		Id salesSystemsUserId = Constants.SALES_SYSTEMS_USER_ID;
		Id serviceCloudTaniumUserId = Constants.SERVICE_CLOUD_TANIUM_USER_ID;
		List<String> paidAiCreditProductCodes = Constants.PAID_AI_CREDIT_PRODUCT_CODES;
		Assert.isTrue(taniumDeveloperPermSet == Constants.TANIUM_DEVELOPER_USERS_PERM_SET);
		Assert.isTrue(constellantPermSet == Constants.CONSTELLANT_DEV_PERM_SET);
		Assert.isTrue(communityPlaybookIdeasId == Constants.COMMUNITY_PLAYBOOK_IDEAS_ID);
		Assert.isTrue(partnerCaseAccessPermSet == Constants.PARTNER_CASE_ACCESS);
		Assert.isTrue(zoominCommunityCloudPermSet == Constants.ZOOMIN_COMMUNITY_CLOUD_PERM_SET);
		Assert.isTrue(taniumCommunityUnknownProfile == Constants.TANIUM_COMMUNITY_UNKNOWN_PROFILE);
		Assert.isTrue(taniumDsaUserId == Constants.TANIUM_DSA_USER_ID);
		Assert.isTrue(taniumCustomerCommunity == Constants.TANIUM_CUSTOMER_COMMUNITY);
		Assert.isTrue(taniumCustomerCommunityId == Constants.TANIUM_CUSTOMER_COMMUNITY_ID);
		Assert.isTrue(customerCommunityManagerId == Constants.CUSTOMER_COMMUNITY_MANAGER_ID);
		Assert.areEqual(2, caseCloseStatuses.size());
		Assert.isTrue(caseCloseStatuses.contains('Closed'));
		Assert.isTrue(caseCloseStatuses.contains('Closed as Duplicate'));
		Assert.isTrue(caseCloseSummary == Constants.CASE_CLOSE_SUMMARY);
		Assert.isTrue(
			deleteLeadsAndContactsPermission == Constants.DELETE_LEADS_AND_CONTACTS_PERMISSION
		);
		Assert.isTrue(salesSystemsUserId == Constants.SALES_SYSTEMS_USER_ID);
		Assert.isTrue(serviceCloudTaniumUserId == Constants.SERVICE_CLOUD_TANIUM_USER_ID);
		Assert.areEqual(2, paidAiCreditProductCodes.size());
		Assert.isTrue(paidAiCreditProductCodes.contains('TANIUM-AI-CREDITS-CLOUD'));
		Assert.isTrue(paidAiCreditProductCodes.contains('TANIUM-AI-CREDITS-CLOUDGOV-US'));
	}
}