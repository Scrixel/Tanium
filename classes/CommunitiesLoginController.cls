/**
 * An apex page controller that exposes the site login functionality
 * Modified  ModifiedDate   Description
 * SS-7070   2024-01-20     Added redirect validation
 */
global with sharing class CommunitiesLoginController {
	global CommunitiesLoginController() {
	}

	// Code we will invoke on page load.
	global PageReference forwardToAuthPage() {
		String startUrl = Utility.isValidRedirectUrl(
				System.currentPageReference().getParameters().get('startURL')
			)
			? System.currentPageReference().getParameters().get('startURL')
			: '/';
		String displayType = System.currentPageReference().getParameters().get('display');
		return Network.forwardToAuthPage(startUrl, displayType);
	}
}