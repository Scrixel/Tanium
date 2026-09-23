/**
 * @Business: Test class for the KnowledgeArticleDetailController
 * @Author: Cumulus Vision
 * Modified    ModifiedDate    Description
 *  TAN-852    2020-04-09      Initial Development
 *  TAN-916    2020-08-12      Fixed issue - System.NoAccessException for the create KnowledgeArticle
 */
@IsTest
private with sharing class KnowledgeArticleDetailControllerTest {
	private static Knowledge__kav buildKnowledge(String title, String summary) {
		return new Knowledge__kav(
			Title = title,
			Summary = summary,
			Urlname = title.normalizeSpace().replaceAll(' ', '-')
		);
	}

	private static testMethod void testFetchKnowledgeArticle() {

		KnowledgeArticleDetailController.getKnowledgeObjectsForTesting();

		User currentUser = new User(Id = UserInfo.getUserId());
		currentUser.UserPermissionsKnowledgeUser = true;
		update currentUser;

		System.runAs(currentUser) {

			knowledge__kav newArticle = buildKnowledge(
				'Test Method Article 1',
				'Summary of the test article'
			);
			insert newArticle;

			Knowledge__DataCategorySelection dcs = new Knowledge__DataCategorySelection(
				DataCategoryGroupName = 'Community',
				DataCategoryName = 'Best_Practices',
				ParentId = newArticle.Id
			);
			insert dcs;

			newArticle = [SELECT Id, KnowledgeArticleId FROM knowledge__kav WHERE Id = :newArticle.Id];

			KbManagement.PublishingService.publishArticle(newArticle.KnowledgeArticleId, true);

			Test.startTest();

			KnowledgeArticleDetailController.ActionResult result;

			result = KnowledgeArticleDetailController.fetchKnowledgeArticle(newArticle.Id);
			System.assert(result.isSuccess);

			Map<String, Object> mapData = (Map<String, Object>) result.data;
			System.assert(mapData.containsKey('knowledgeArticle'));

			result = KnowledgeArticleDetailController.fetchKnowledgeArticle(UserInfo.getUserId());
			System.assert(!result.isSuccess);
			System.assert(String.isNotEmpty(result.error));
			
			
			KnowledgeArticleDetailController.getArticleInit(newArticle.Id);
			KnowledgeArticleDetailController.getArticleIdFromUrl('https://foo/Test-Method-Article-1');

			Test.stopTest();

			
		}
	}

	private static testMethod void testLogException() {
		try {
			System.debug(1 / 0);
		} catch (Exception ex) {
			KnowledgeArticleDetailController.logException(ex);
			new KnowledgeArticleDetailController.ActionResult().setFailure(ex);
		}
	}
}