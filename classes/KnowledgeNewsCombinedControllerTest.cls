@isTest
public with sharing class KnowledgeNewsCombinedControllerTest {
    private static Knowledge__kav buildKnowledge(String title, String summary) {
        return new Knowledge__kav(
            Title = title,
            Summary = summary,
            Urlname = title.normalizeSpace().replaceAll(' ', '-')
        );
    }

    private static X7S_News__c buildNews(String title, String details) {
        return new X7S_News__c(
            Name = title,
            Details__c = details,
            Publish_DateTime__c = Datetime.now()
        );
    }

    @isTest private static void testFetchKnowledgeNewsArticles() {
        User currentUser = new User(Id = UserInfo.getUserId());
        currentUser.UserPermissionsKnowledgeUser = true;
        update currentUser;

        System.runAs(currentUser) {
            X7S_News__c newNewsArticle = buildNews('Test Method Article 1', 'Summary of the test article');
            knowledge__kav newKnowledgeArticle = buildKnowledge('Test Method Article 1', 'Summary of the test article');
            insert newNewsArticle;
            insert newKnowledgeArticle;

            newNewsArticle = [SELECT Id
                              FROM X7S_News__c
                              WHERE Id = :newNewsArticle.Id];

            newKnowledgeArticle = [SELECT Id, KnowledgeArticleId
                                   FROM knowledge__kav
                                   WHERE Id = :newKnowledgeArticle.Id];

            KbManagement.PublishingService.publishArticle(newKnowledgeArticle.KnowledgeArticleId, true);

            Test.startTest();

            KnowledgeNewsCombinedController.ActionResult result;

            result = KnowledgeNewsCombinedController.fetchKnowledgeNewsArticles(1, 5, 'Community');
            System.assert(result.isSuccess, 'Failed to retrieve Knowledge or News articles.');

            Map<String, Object> mapData = (Map<String, Object>)result.data;
            System.assert(mapData.containsKey('mergedArticles'), 'Failed to return merged Knowledge and News.');

            Test.stopTest();
        }
    }

    @isTest private static void testLogException() {
        try {
            System.debug(1/0);
        } catch(Exception ex) {
            KnowledgeNewsCombinedController.logException(ex);
            new KnowledgeNewsCombinedController.ActionResult().setFailure(ex);
        }
    }
}