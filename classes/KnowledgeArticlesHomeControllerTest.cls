/**
 * @Business: Test class for the KnowledgeArticlesHomeController
 * @Author: Cumulus Vision
 * Modified    ModifiedDate    Description
 *  TAN-851    2019-03-26      Initial Development
 *  TAN-916    2020-08-12      Fixed issue - System.NoAccessException for the create KnowledgeArticle
 *  TAN-918    2020-08-26      Minor modifications due to change in the method definition in the actual class.
 */
@IsTest
private class KnowledgeArticlesHomeControllerTest {
	private static Knowledge__kav buildKnowledge(String title, String summary) {
		return new Knowledge__kav(
			Title = title,
			Summary = summary,
			Urlname = title.normalizeSpace().replaceAll(' ', '-')
		);
	}

	private static testMethod void testIsCommunitySession() {
		Test.startTest();

		KnowledgeArticlesHomeController.ActionResult result = KnowledgeArticlesHomeController.isCommunitySession();
		System.assert(result.isSuccess);

		Map<String, Object> mapData = (Map<String, Object>) result.data;
		System.assert(mapData.containsKey('isCommunity'));

		Test.stopTest();
	}

	private static testMethod void testFetchKnowledgeArticles() {
		User currentUser = new User(Id = UserInfo.getUserId());
		currentUser.UserPermissionsKnowledgeUser = true;
		update currentUser;

		System.runAs(currentUser) {
			knowledge__kav newArticle = buildKnowledge(
				'Test Method Article 1',
				'Summary of the test article'
			);
			insert newArticle;

			newArticle = [SELECT Id, KnowledgeArticleId FROM knowledge__kav WHERE Id = :newArticle.Id];

			KbManagement.PublishingService.publishArticle(newArticle.KnowledgeArticleId, true);

			Test.startTest();

			KnowledgeArticlesHomeController.ActionResult result;

			result = KnowledgeArticlesHomeController.fetchKnowledgeArticles(1, 5, null);
			System.assert(result.isSuccess);

			Map<String, Object> mapData = (Map<String, Object>) result.data;
			System.assert(mapData.containsKey('knowledgeArticles'));
			System.assert(mapData.containsKey('totalPages'));

			result = KnowledgeArticlesHomeController.fetchKnowledgeArticles(null, 5, null);
			System.assert(!result.isSuccess);
			System.assert(String.isNotEmpty(result.error));

			Test.stopTest();
		}
	}
}