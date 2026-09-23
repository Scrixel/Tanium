/*
 * @Business: see Attachment Trigger Handler
 * @Date: 2016-03-23
 * @Author: Cumulus Vision
 * @Request: TAN-107
 * Modified  ModifiedDate   Description
 * TAN-728   2018-12-13     updated to include Budget Attachment Summary.
 */
@isTest
public class AttachmentTriggerHandlerTest {
	static void CreateRecords() {
		//Creates the standard records needed to support application functionality
		TriggerHandler.bypass(new List<String>{ 'AccountTriggerHandler' });
	}

	private static testMethod void budgetClaculating_onAfterInsert() {
		CreateRecords();
		Budget__c testBudget = new Budget__c();
		insert testBudget;

		List<Attachment> lstAttach = new List<Attachment>();
		lstAttach.add(
			new Attachment(
				parentId = testBudget.Id,
				name = 'Winner Reports.csv',
				body = Blob.valueOf('Unit Test')
			)
		);
		lstAttach.add(
			new Attachment(
				parentId = testBudget.Id,
				name = 'The Winning Report.doc',
				body = Blob.valueOf('Unit Test')
			)
		);
		lstAttach.add(
			new Attachment(
				parentId = testBudget.Id,
				name = 'The Winners Reporter is here.doc',
				body = Blob.valueOf('Unit Test')
			)
		);

		Test.startTest();
		insert lstAttach;
		Test.stopTest();

		Budget__c resultBudgets = [
			SELECT Id, Attachment_Summary__c, (SELECT Id FROM Attachments)
			FROM Budget__c
			WHERE Id = :testBudget.Id
			LIMIT 1
		];
		Site site = [
			SELECT GuestUserId, Name, Subdomain, UrlPathPrefix
			FROM Site
			WHERE Name = :'Budget_Attachments'
		];
		Organization org = [SELECT InstanceName, IsSandbox, OrganizationType FROM Organization];
		String siteFullUrl =
			'https://' +
			UserInfo.getUserName().substringAfterLast('.') +
			'-' +
			site.Subdomain +
			'.';
		siteFullUrl +=
			(org.IsSandbox || org.OrganizationType == 'Developer Edition'
				? (org.InstanceName.toLowerCase() + '.')
				: '') + 'force.com';
		siteFullUrl += '/' + site.UrlPathPrefix;
	}

	private static testMethod void budgetClaculating_onAfterDelete() {
		CreateRecords();
		Budget__c testBudget = new Budget__c();
		insert testBudget;

		List<Attachment> lstAttach = new List<Attachment>();
		lstAttach.add(
			new Attachment(
				parentId = testBudget.Id,
				name = 'Winner Reports.csv',
				body = Blob.valueOf('Unit Test')
			)
		);
		lstAttach.add(
			new Attachment(
				parentId = testBudget.Id,
				name = 'The Winning Report.doc',
				body = Blob.valueOf('Unit Test')
			)
		);
		lstAttach.add(
			new Attachment(
				parentId = testBudget.Id,
				name = 'The Winners Reporter is here.doc',
				body = Blob.valueOf('Unit Test')
			)
		);
		insert lstAttach;

		Test.startTest();
		delete lstAttach[0];
		Test.stopTest();

		Budget__c resultBudgets = [
			SELECT Id, Attachment_Summary__c, (SELECT Id FROM Attachments)
			FROM Budget__c
			WHERE Id = :testBudget.Id
			LIMIT 1
		];
		Site site = [
			SELECT GuestUserId, Name, Subdomain, UrlPathPrefix
			FROM Site
			WHERE Name = :'Budget_Attachments'
		];
		Organization org = [SELECT InstanceName, IsSandbox, OrganizationType FROM Organization];
		String siteFullUrl =
			'https://' +
			UserInfo.getUserName().substringAfterLast('.') +
			'-' +
			site.Subdomain +
			'.';
		siteFullUrl +=
			(org.IsSandbox || org.OrganizationType == 'Developer Edition'
				? (org.InstanceName.toLowerCase() + '.')
				: '') + 'force.com';
		siteFullUrl += '/' + site.UrlPathPrefix;
	}
}