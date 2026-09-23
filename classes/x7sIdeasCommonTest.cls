/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
public with sharing class x7sIdeasCommonTest {

	@IsTest
	static void test_X7s_Ideas_Common() {
		x7sIdeasCommon common = new x7sIdeasCommon('', true);

		// custom settings
		System.assertNotEquals(null, common);
		System.assertNotEquals(null, common.allowDownVoting);
		System.assertNotEquals(null, common.showAlternateCTA);
		//System.assertNotEquals(null, common.voteDisableStatus);
		//System.assertNotEquals(null, common.emailIdeaStatusTemplate);
		//System.assertNotEquals(null, common.chatterProfiles);

		System.assertNotEquals(null, common.debugMode);
		System.assertNotEquals(null, common.nicknameEnabled);
		System.assertNotEquals(null, common.isAuthenticated);
		System.assertNotEquals(null, common.zoneId);

		x7sIdeasCommon.dumpSettings('Test', common);

		x7sIdeasCommon common2 = new x7sIdeasCommon('');
		System.assertNotEquals(null, common2);
	}
}