/**
 * An apex page controller that exposes the site login functionality
 * Modified  ModifiedDate   Description
 * SS-7070   2024-01-20     Added redirect validation
 */
global with sharing class SiteLoginController {
	global String username { get; set; }
	global String password { get; set; }

	global PageReference login() {
		String startUrl = Utility.isValidRedirectUrl(
				System.currentPageReference().getParameters().get('startURL')
			)
			? System.currentPageReference().getParameters().get('startURL')
			: '/';
		return Site.login(username, password, startUrl);
	}

	global SiteLoginController() {
	}
}