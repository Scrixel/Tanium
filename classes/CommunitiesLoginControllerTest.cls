/**
 * An apex page controller that exposes the site login functionality
 */
@IsTest
private class CommunitiesLoginControllerTest {
	@IsTest
	static void testCommunitiesLoginController() {
		CommunitiesLoginController controller = new CommunitiesLoginController();
		System.assertEquals(null, controller.forwardToAuthPage());
	}
}