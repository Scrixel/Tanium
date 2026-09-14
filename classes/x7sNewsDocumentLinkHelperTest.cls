/*
 * Licensed Materials - Property of IBM
 * 6949-83N
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
*/

@IsTest
private class x7sNewsDocumentLinkHelperTest {

	private static final Integer CONTENT_DOC_QUERY_LIMIT = 5;

	@IsTest
	static void testDocumentLinkHelper() {
		X7S_News__c newsObj = x7sNewsUtilityTest.createNews();

		if (newsObj.Id != null) {
			ContentVersion contentVersionInsert = new ContentVersion(
				Title = 'Test news content trigger',
				PathOnClient = 'Test.jpg',
				VersionData = Blob.valueOf('Test Content Data'),
				IsMajorVersion = true
			);
			insert contentVersionInsert;

			// Test INSERT
			ContentVersion contentVersionSelect = [SELECT Id, Title, ContentDocumentId FROM ContentVersion WHERE Id = :contentVersionInsert.Id LIMIT 1];
			System.assertNotEquals(null, contentVersionSelect);

			List<ContentDocument> documents = [SELECT Id, Title, LatestPublishedVersionId FROM ContentDocument LIMIT :CONTENT_DOC_QUERY_LIMIT];
			System.assertEquals(documents.size(), 1);

			// attempt to fire the trigger
			ContentDocumentLink contentLink = new ContentDocumentLink();
			contentLink.LinkedEntityId = newsObj.Id;
			contentLink.ShareType = 'V';
			contentLink.ContentDocumentId = documents[0].Id;
			insert contentLink;
		}
	}
}