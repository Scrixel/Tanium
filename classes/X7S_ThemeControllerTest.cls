/*
 * Licensed Materials - Property of IBM
 * 6949-84J
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@isTest
public class X7S_ThemeControllerTest {
	@isTest
	static void test_UberTheme() {
		System.runAs(TestUserFactory.createTaniumAdminUser()) {
			Test.startTest();

			// call method to get Site Prefix
			String strSitePathPrefix = X7S_ThemeController.getSiteName();
			system.assertEquals(strSitePathPrefix, System.Site.getPathPrefix());
			system.assertEquals('', X7S_ThemeController.getSiteNameInternal('0'));

			Test.stopTest();
		}
	}
}