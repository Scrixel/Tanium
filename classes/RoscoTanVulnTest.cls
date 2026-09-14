@isTest
public with sharing class RoscoTanVulnTest {
	@isTest(SeeAllData=false)
	static void unit_addSubscriberEmail() {
		String email = 'test_Unit_createCase@roscolab.com';

		/*Account accountObj = new Account(
			name = 'test_Unit_createCase',
			slack_channel_id__c = 'TESTCASE',
			Country_Exception_Approved__c = true
		);*/
        Account accountObj = TestFactory.buildAccount('test_Unit_createCase');
        accountObj.slack_channel_id__c = 'TESTCASE';
		accountObj.Country_Exception_Approved__c = true;        
		insert accountObj;

		Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium Community Login Authenticated'].Id;

		Contact contactObj = new Contact(
			Email = email,
			FirstName = 'Test',
			LastName = 'Apex',
			AccountId = accountObj.Id
		);
		insert contactObj;

		User userObj = new User(
			Email = email,
			FirstName = 'Foo',
			LastName = 'Bar',
			UserName = email,
			Alias = 'foo',
			CommunityNickName = 'foo',
			TimeZoneSidKey = 'America/Los_Angeles',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'ISO-8859-1',
			ProfileId = profileId,
			LanguageLocaleKey = 'en_US',
			ContactId = contactObj.Id
		);
		insert userObj;

		List<Map<String, String>> results = RoscoTanVuln.addSubscriberEmail(email);
		System.debug(results);
	}

	@isTest(SeeAllData=false)
	static void unit_exportCommunityMembers() {
		String email = 'test_Unit_createCase@roscolab.com';

        Account accountObj = TestFactory.buildAccount('test_Unit_createCase');
        accountObj.slack_channel_id__c = 'TESTCASE';
		accountObj.Country_Exception_Approved__c = true;        
		insert accountObj;

		Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium Community Login Authenticated'].Id;

		Contact contactObj = new Contact(
			Email = email,
			FirstName = 'Test',
			LastName = 'Apex',
			AccountId = accountObj.Id
		);
		insert contactObj;

		User userObj = new User(
			Email = email,
			FirstName = 'Foo',
			LastName = 'Bar',
			UserName = email,
			Alias = 'foo',
			CommunityNickName = 'foo',
			TimeZoneSidKey = 'America/Los_Angeles',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'ISO-8859-1',
			ProfileId = profileId,
			LanguageLocaleKey = 'en_US',
			ContactId = contactObj.Id
		);
		insert userObj;

		List<Map<String, String>> results = RoscoTanVuln.addSubscriberEmail(email);

		String results2 = RoscoTanVuln.exportCommunityMembers();
		System.debug(results2);
	}

	@isTest(SeeAllData=true)
	static void unit_getInit() {
		System.runAs(TestFactory.getTaniumAdminUser()) {
			Case_Management__c cmSetting = new Case_Management__c();
			cmSetting.Name = '';
			cmSetting.Customer_Community_URL__c = 'https://foo';
			//insert cmSetting;

			Case_Management__c cmSetting2 = new Case_Management__c();
			cmSetting2.Name = '';
			cmSetting2.rosco_tanium_vulnerabilty_tool_auth__c = UserInfo.getUserEmail();
			//insert cmSetting2;

			String recordTypeId = RoscoUtility.getRecordTypeIdByAPIName(
				'Knowledge__kav',
				'Tanium_Vulnerability'
			);
			System.debug(recordTypeId);

			// help article
			/*
            Knowledge__kav article0 = new Knowledge__kav(
                Title = 'ROSCOTESTCASE Tanium Server',
                Summary = 'ROSCOTESTCASE',
                UrlName = 'tan-vuln-help',
                Language = 'en_US',         
                IsVisibleInCsp = true,
                IsVisibleInPkb = true,
                IsVisibleInPrm = true,
                RecordTypeId = recordTypeId         
            );
            insert article0;
    
            Knowledge__kav currentArticleDetail0 = [
                SELECT ArticleCreatedDate, ArticleNumber
                FROM Knowledge__kav
                WHERE Id = :article0.Id
              ];
    
            KnowledgeArticle knowledgeArticle0 = [
                SELECT Id
                FROM KnowledgeArticle
                WHERE ArticleNumber = :currentArticleDetail0.get('ArticleNumber').toString()
            ];
    
            
            ConnectApi.Topic topic0 = ConnectAPI.Topics.createTopic(null,'ROSCOTESTCASE','ROSCOTESTCASE');
            ConnectAPI.Topics.assignTopic(null,article0.ID,topic0.Id);
    
            KbManagement.PublishingService.publishArticle(knowledgeArticle0.Id, true);
           */
			// Vulnerability article
			Knowledge__kav article = new Knowledge__kav(
				Title = 'ROSCOTESTCASE Tanium Server',
				Summary = 'ROSCOTESTCASE',
				UrlName = 'urlname',
				Language = 'en_US',
				IsVisibleInCsp = true,
				IsVisibleInPkb = true,
				IsVisibleInPrm = true,
				RecordTypeId = recordTypeId
			);
			insert article;

			Knowledge__kav currentArticleDetail = [
				SELECT ArticleCreatedDate, ArticleNumber
				FROM Knowledge__kav
				WHERE Id = :article.Id
			];

			KnowledgeArticle knowledgeArticle = [
				SELECT Id
				FROM KnowledgeArticle
				WHERE ArticleNumber = :currentArticleDetail.get('ArticleNumber').toString()
			];

			Knowledge__DataCategorySelection dataCategory = new Knowledge__DataCategorySelection();
			dataCategory.ParentId = article.ID;
			dataCategory.DataCategoryGroupName = 'Customer_KB';
			dataCategory.DataCategoryName = 'Tanium_Vulnerability';
			//insert dataCategory;

			ConnectApi.Topic topic = ConnectAPI.Topics.createTopic(
				null,
				'ROSCOTESTCASE',
				'ROSCOTESTCASE'
			);
			ConnectAPI.Topics.assignTopic(null, article.ID, topic.Id);

			KbManagement.PublishingService.publishArticle(knowledgeArticle.Id, true);

			Map<String, String> results = RoscoTanVuln.getInit();
			System.debug(results);
		}

	}

	@isTest(SeeAllData=false)
	static void unit_getSplashPageContent() {
		Rosco_CmtyContent__c rcc = new Rosco_CmtyContent__c();
		rcc.body__c = 'ROSCOTESTCASE';
		rcc.Name = 'splashTaniumVuln';
		rcc.Status__c = 'Online';
		rcc.Title__c = 'ROSCOTESTCASE';
		rcc.Topics__c = 'ROSCOTESTCASE';
		rcc.Content_Type__c = 'Core Doc';
		insert rcc;

		String results = RoscoTanVuln.getSplashPageContent();
		System.debug(results);
	}

	@isTest(SeeAllData=false)
	static void unit_getSubscribers() {
		String email = 'test_Unit_createCase@roscolab.com';

        Account accountObj = TestFactory.buildAccount('test_Unit_createCase');
        accountObj.slack_channel_id__c = 'TESTCASE';
		accountObj.Country_Exception_Approved__c = true;        
		insert accountObj;

		Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium Community Login Authenticated'].Id;

		Contact contactObj = new Contact(
			Email = email,
			FirstName = 'Test',
			LastName = 'Apex',
			AccountId = accountObj.Id
		);
		insert contactObj;

		User userObj = new User(
			Email = email,
			FirstName = 'Foo',
			LastName = 'Bar',
			UserName = email,
			Alias = 'foo',
			CommunityNickName = 'foo',
			TimeZoneSidKey = 'America/Los_Angeles',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'ISO-8859-1',
			ProfileId = profileId,
			LanguageLocaleKey = 'en_US',
			ContactId = contactObj.Id
		);
		insert userObj;

		List<Map<String, String>> results = RoscoTanVuln.addSubscriberEmail(email);

		List<Map<String, String>> results2 = RoscoTanVuln.getSubscribers();
		System.debug(results2);
	}

	@isTest(SeeAllData=false)
	static void unit_getSubscriberLookup2() {
		String email = 'test_test_Unit_createCase@roscolab.com';

        Account accountObj = TestFactory.buildAccount('test_Unit_createCase');
        accountObj.slack_channel_id__c = 'TESTCASE';
		accountObj.Country_Exception_Approved__c = true;        
		insert accountObj;

		Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium Community Login Authenticated'].Id;

		Contact contactObj = new Contact(
			Email = email,
			FirstName = 'test_test_1',
			LastName = 'Apex',
			AccountId = accountObj.Id
		);
		insert contactObj;

		User userObj = new User(
			Email = email,
			FirstName = '1test1',
			LastName = '1test1',
			UserName = email,
			Alias = 'foo',
			CommunityNickName = 'foo',
			TimeZoneSidKey = 'America/Los_Angeles',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'ISO-8859-1',
			ProfileId = profileId,
			LanguageLocaleKey = 'en_US',
			ContactId = contactObj.Id
		);
		insert userObj;
		List<Map<String, String>> results = RoscoTanVuln.addSubscriberEmail(email);

		List<Map<String, String>> results2 = RoscoTanVuln.getSubscriberLookup2('test');
	}

	@isTest(SeeAllData=false)
	static void unit_getUsersLastOpen() {
		Map<String, String> results = RoscoTanVuln.getUsersLastOpen();
		System.debug(results);
	}

	/*
    @isTest(SeeAllData=true) static void unit_getZendeskMigrationCsv() {
        String results = RoscoTanVuln.getZendeskMigrationCsv();
        System.debug(results);
    }    
    */

	@isTest(SeeAllData=false)
	static void unit_isSubscribed() {
		String results = RoscoTanVuln.isSubscribed('x', UserInfo.getUserId());
		System.debug(results);
	}

	@isTest(SeeAllData=false)
	static void unit_removeSubscriberEmail() {
		String email = 'test_Unit_createCase@roscolab.com';

        Account accountObj = TestFactory.buildAccount('test_Unit_createCase');
        accountObj.slack_channel_id__c = 'TESTCASE';
		accountObj.Country_Exception_Approved__c = true;        
		insert accountObj;

		Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium Community Login Authenticated'].Id;

		Contact contactObj = new Contact(
			Email = email,
			FirstName = 'Test',
			LastName = 'Apex',
			AccountId = accountObj.Id
		);
		insert contactObj;

		User userObj = new User(
			Email = email,
			FirstName = 'Foo',
			LastName = 'Bar',
			UserName = email,
			Alias = 'foo',
			CommunityNickName = 'foo',
			TimeZoneSidKey = 'America/Los_Angeles',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'ISO-8859-1',
			ProfileId = profileId,
			LanguageLocaleKey = 'en_US',
			ContactId = contactObj.Id
		);
		insert userObj;
		List<Map<String, String>> results = RoscoTanVuln.addSubscriberEmail(email);

		List<Map<String, String>> results2 = RoscoTanVuln.removeSubscriberEmail(email);
		System.debug(results2);
	}

	@isTest(SeeAllData=true)
	static void unit_saveSplashPageContent() {
		Rosco_CmtyContent__c rcc = new Rosco_CmtyContent__c();
		rcc.body__c = 'ROSCOTESTCASE';
		rcc.Name = 'splashTaniumVuln';
		rcc.Status__c = 'Online';
		rcc.Title__c = 'ROSCOTESTCASE';
		rcc.Topics__c = 'ROSCOTESTCASE';
		rcc.Content_Type__c = 'Core Doc';
		insert rcc;

		String results = RoscoTanVuln.saveSplashPageContent('foo');
		System.debug(results);
	}

	@isTest(SeeAllData=true)
	static void unit_sendEmail() {
		OrgWideEmailAddress o = [SELECT Id FROM OrgWideEmailAddress LIMIT 1];

		Case_Management__c cmSetting = new Case_Management__c();
		cmSetting.Name = '';
		cmSetting.rosco_owea__c = String.valueOf(o.Id);
		//insert cmSetting;

		String results = RoscoTanVuln.sendEmail('foo', 'foo', 'foo');
		System.debug(results);
		String results2 = RoscoTanVuln.sendEmail('foo', 'foo', 'SendToAllSubscribers');
		System.debug(results2);
	}

	@isTest(SeeAllData=true)
	static void unit_sendEmailSolo() {

		String email = 'test_Unit_createCase@roscolab.com';

        Account accountObj = TestFactory.buildAccount('test_Unit_createCase');
        accountObj.slack_channel_id__c = 'TESTCASE';
		accountObj.Country_Exception_Approved__c = true;        
		insert accountObj;

		Contact contactObj = new Contact(
			Email = email,
			FirstName = 'Test',
			LastName = 'Apex',
			AccountId = accountObj.Id
		);
		insert contactObj;
		Id profileId = [SELECT Id FROM Profile WHERE Name = 'Tanium Community Login Authenticated'].Id;		
		User userObj = new User(
			Email = email,
			FirstName = 'Foo',
			LastName = 'Bar',
			UserName = email,
			Alias = 'foo',
			CommunityNickName = 'foo',
			TimeZoneSidKey = 'America/Los_Angeles',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'ISO-8859-1',
			ProfileId = profileId,
			LanguageLocaleKey = 'en_US',
			ContactId = contactObj.Id
		);
		insert userObj;

		List<Map<String, String>> results = RoscoTanVuln.addSubscriberEmail(email);		

		String results2 = RoscoTanVuln.sendEmailSolo('foo', 'foo', email);
		System.debug(results2);
	}	
	/*
    
    @isTest(SeeAllData=true) static void unit_subscribeUser() {
        String results = RoscoTanVuln.subscribeUser();
        System.debug(results);
    }    


    @isTest(SeeAllData=true) static void unit_unSubscribeUser() {
        String results = RoscoTanVuln.unSubscribeUser();
        System.debug(results);
    }    
    */
}