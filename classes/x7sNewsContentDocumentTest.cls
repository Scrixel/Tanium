/*
 * Licensed Materials - Property of IBM
 * 6949-83N
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
*/

@IsTest
public class x7sNewsContentDocumentTest {
	public static String strNetId {
		get {
			return [SELECT Id FROM Network LIMIT 1][0].Id;
		}
	}

	@IsTest static void testMethods() {
		X7S_News__c newsObj = x7sNewsUtilityTest.createNews(strNetId);

		ContentVersion cv = new ContentVersion(
			Title = 'Test',
			PathOnClient = 'Test.jpg',
			VersionData = Blob.valueOf('Test Content Data'),
			IsMajorVersion = true
		);
		insert cv;		

		ContentDocumentLink cdl = new ContentDocumentLink();
		cdl.ContentDocumentId = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id =: cv.Id].ContentDocumentId;
		cdl.LinkedEntityId = newsObj.Id;
		cdl.ShareType = 'V';
		insert cdl;

		List<Id> listIds = new List<Id>();
		listIds.add(cv.Id);

		List<ContentDocumentLink> documentList = x7sNewsContentDocument.getContentDocumentLinks(listIds);
		x7sNewsContentDocument.containsEntityId(documentList, newsObj.Id);
		System.assertNotEquals(null, documentList, 'List expected');

	}

	@IsTest static void test_CMTPicklist() {
		x7sNewsCMTPicklist cmtPicklistClass = new x7sNewsCMTPicklist();

		System.assertNotEquals(null, cmtPicklistClass.getDefaultValue(), 'Incorrect CMT Picklist default value.');	
		System.assertEquals(true, cmtPicklistClass.getValues().size() > 0, 'There must be picklist values.');
	}
}