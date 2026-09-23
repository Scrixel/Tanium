/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */
@SuppressWarnings('PMD.ApexUnitTestShouldNotUseSeeAllDataTrue, PMD.AvoidGlobalModifier')
@IsTest
global class x7sEventsListControllerTest {
	private static final String RELATED_FILES = 'Related File';
	private static final String NONE = 'None';
	private static final String LIST_VIEW_MODE = 'List';
	private static final String DEFAULT_LITERAL = 'Default';
	private static final String TEST_TOPIC_NAME = 'Test000';
	private static final String SORT_UPCOMING = 'Upcoming';

	@IsTest
	static void test_generalMethods() {
		//Get CMTs
		Map<String, String> settings = x7sEventsListController.getRegistrationCMT();
		String cmtDes = x7sEventsListController.getRegCMTDescription('test');
		System.assertEquals(null, cmtDes);
		System.assertNotEquals(null, settings);

		Map<String, String> eventFormats = x7sEventsListController.getEventIntegrationCMT();
		System.assertEquals(
			true,
			eventFormats.containsKey(x7sEventsListController.EVENT_FORMAT_STANDARD)
		);

		//Get Custom Filter Clause
		String filterString = 'field1:value1;field2:value2;';
		String query = x7sEventsListController.getCustomFilterClause(filterString);
		System.assertNotEquals(null, query);

		//Get Languages
		Map<String, String> languageMap = x7sEventsListController.getLanguageOption();
		System.assertEquals(languageMap.size(), languageMap.size());

		String userLanguage = x7sEventsListController.getLanguage();
		System.assertNotEquals(null, userLanguage);

		//Sync Meeting Id
		String meetingID = '123';
		String eventFormat = DEFAULT_LITERAL;
		String response = x7sEventsListController.syncMeetingId(meetingID, eventFormat);
		System.assertEquals('', response);

		//Getting Virtual Platform
		String virtualPlatform = x7sEventsListController.getVirtualPlatform('Zoom');

		System.assertEquals('Zoom', virtualPlatform);
	}

	@IsTest(SeeAllData=true)
	static void test_eventPagination() {
		Boolean eventListFlag = true;
		Integer numberofresults = 100;
		Integer listSize = 100;
		Integer pageNumber = 1;
		String strfilterType = null;
		String strRecordId = '';
		String sortBy = null;
		String filterByTopic = null;
		String topicName = null;
		String searchTerm = 'Test';
		String fromDate = String.valueOf(System.today());
		String toDate = String.valueOf(System.today().addDays(5));
		Boolean limitToGeneralEvents = false;

		List<X7S_Event__c> eventList = x7sEventsUtility.createEventsRecords(10);
		System.assertEquals(eventList.size(), 10);

        List<Topic> topics = x7sEventsUtility.createTopic(1);
		System.assertEquals(topics.size(), 1);
        
        X7S_Event__c objEvent = new X7S_Event__c();

		objEvent.Name = 'Test Event';
		objEvent.Start_DateTime__c = Datetime.now();
		objEvent.End_DateTime__c = Datetime.now().addDays(1);
		objEvent.Details__c = 'Event Details etc.';
		objEvent.Location_Name__c = 'Location1';
		objEvent.Enable_RSVP__c = false;
        insert objEvent;
        
        
        TopicAssignment topicAssignment = new TopicAssignment(
            EntityId = objEvent.Id,
            TopicId = topics[0].Id,
            NetworkId = System.Network.getNetworkId()
        );
		insert topicAssignment;
        
        
		//Create Community User
		//As we are using custom object News, we have created user with a CUSTOM Community Profile,
		//Because standard community profile do not allow to give permissions to custom objects.
		User communityUser = x7sEventsUtility.createCommunityUsers(
			x7sEventsTestConstants.CUSTOMER_COMMUNITY_USER_CLONE
		);

		System.runAs(communityUser) {
			Test.startTest();
			List<String> eventsList = new List<String>();

			x7sEventsListController.getEvents(
				eventListFlag,
				numberofresults,
				listSize,
				strfilterType,
				strRecordId,
				sortBy,
				'Test000',
				topicName,
				searchTerm,
				'My Events',
				fromDate,
				toDate,
				LIST_VIEW_MODE,
				eventsList,
				DEFAULT_LITERAL,
				limitToGeneralEvents
			);

			//check with pagination next previous
			x7sEventsListController.nextPage(
				eventListFlag,
				numberofresults,
				listSize,
				pageNumber,
				strfilterType,
				strRecordId,
				sortBy,
				filterByTopic,
				topicName,
				searchTerm,
				NONE,
				fromDate,
				toDate,
				LIST_VIEW_MODE,
				eventsList,
				DEFAULT_LITERAL,
				limitToGeneralEvents
			);
			x7sEventsListController.previousPage(
				eventListFlag,
				numberofresults,
				listSize,
				pageNumber,
				strfilterType,
				strRecordId,
				sortBy,
				filterByTopic,
				topicName,
				searchTerm,
				NONE,
				fromDate,
				toDate,
				LIST_VIEW_MODE,
				eventsList,
				DEFAULT_LITERAL,
				limitToGeneralEvents
			);
			System.assertEquals(pageNumber, 1, 'Incorrect page number.');

			Test.stopTest();
		}
	}
    
	@IsTest
	static void test_TopicsAndGroups() {
		Integer topicLimit = x7sEventsListController.getTopicLimit();
		System.debug('test_getTopicLimit: ' + topicLimit);
		System.assertNotEquals(null, topicLimit);
        
		List<User> users = x7sEventsUtility.createUsers(
			1,
			x7sEventsTestConstants.CUSTOMER_COMMUNITY_USER
		);
        
		if (!users.isEmpty()) {
			System.runAs(users[0]) {
				//Create Topic Record
				List<Topic> topics1 = x7sEventsUtility.createTopic(200);
				System.assertEquals(topics1.size(), 200);

				x7sEventsListWrapper wrapper = new x7sEventsListWrapper('field1', 'message1');
				System.assertEquals('field1', wrapper.field);
				System.assertEquals('message1', wrapper.errorMsg);

				Map<String, String> groupList = x7sEventsListController.getAllGroups();

				System.assertNotEquals(null, groupList);
			}
		}
	}

	@IsTest
	static void test_getGroups() {
		UserRole portalRole = [SELECT Id FROM UserRole WHERE PortalType = :NONE LIMIT 1];

		Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

		User admin = new User(
			LastName = 'test user 1',
			Username = 'test.user.groups.1@example.com',
			Email = 'test.1@example.com',
			Alias = 'testu1',
			TimeZoneSidKey = 'GMT',
			LocaleSidKey = 'en_US',
			EmailEncodingKey = 'ISO-8859-1',
			ProfileId = adminProfile.Id,
			UserRoleId = portalRole.Id,
			LanguageLocaleKey = 'en_US'
		);

		System.runAs(admin) {
			Test.startTest();

			x7sEventsUtility.createTestGroup('Test group X1');
            CollaborationGroup cg = new CollaborationGroup();
            cg.NetworkId = System.Network.getNetworkId();
            cg.Name = 'Test Group';
            cg.CollaborationType = 'Private';
            insert cg;
            
            CollaborationGroupMember cgm = new CollaborationGroupMember();
            cgm.CollaborationGroupId = cg.Id;
            cgm.MemberId = admin.Id;
			Map<String, String> groupList = x7sEventsListController.getGroups();
            
            Map<String, String> allGroupList = x7sEventsListController.getAllGroups();
            
            System.assertNotEquals(null, groupList);
			System.assertNotEquals(null, allGroupList);
			Test.stopTest();
		}
	}

	@IsTest
	static void test_userAuthorizedToPost() {
		Boolean canPost = x7sEventsListController.userAuthorizedToPost();
		System.debug('test_userAuthorizedToPost = ' + canPost);
		System.assertNotEquals(null, canPost);
	}

	@IsTest
	static void test_getNameSpacePrefix() {
		x7sEventsBaseController base = new x7sEventsBaseController();
		System.assertNotEquals(null, base);
		x7sEventsBaseController.BaseModel model = x7sEventsBaseController.getModel();
		System.assertNotEquals(null, model);
		String sitePrefix = x7sEventsBaseController.getSitePrefix();
		System.assertNotEquals(null, sitePrefix);
	}

	@IsTest
	static void test_checkCustomFields() {
		String customFieldString = 'Location_Name__c';
		List<String> customFields = x7sEventsListController.getCustomFields(customFieldString);
		System.assertNotEquals(null, customFields);

		customFieldString += ', Event_Type__c ';
		customFields = x7sEventsListController.getCustomFields(customFieldString);
		System.assertNotEquals(null, customFields);

		String invalidField = 'abc';
		customFieldString += ',' + invalidField;
		customFields = x7sEventsListController.getCustomFields(customFieldString);
		System.assertNotEquals(null, customFields);

		System.debug(customFields);
	}

	@IsTest
	static void test_GetCustomFilterClause() {
		String filterString = 'field1:value1;field2:value2;';
		String query = x7sEventsListController.getCustomFilterClause(filterString);
		System.assertNotEquals(null, query);
	}

	@IsTest
	static void test_getLanguage() {
		String userLanguage = x7sEventsListController.getLanguage();
		System.assertNotEquals(null, userLanguage);
	}

	@IsTest
	static void test_getComboboxValue() {
		Map<String, String> languageMap = x7sEventsListController.getLanguageOption();
		System.assertEquals(languageMap.size(), languageMap.size());
	}

	@IsTest
	static void test_multiLanguageSet() {
		List<X7S_Event__c> eventList = x7sEventsUtility.createEventsRecords(10);

		Set<String> duplicate = new Set<String>();
		List<String> myEvents = new List<String>();

		for (X7S_Event__c record : eventList) {
			duplicate.add(record.Id);
			myEvents.add(record.Id);
		}
		Test.startTest();
		Set<String> mulitlanguage = x7sEventsListController.multiLanguageSet(myEvents, duplicate);
		System.assertNotEquals(null, mulitlanguage.size());
		Test.stopTest();
	}

	@IsTest
	static void test_updateImage() {
		List<X7S_Event__c> eventList = x7sEventsUtility.createEventsRecords(1);

		//create Attachment related to news object created
		Attachment attach = new Attachment();
		attach.Name = 'Unit Test Attachment';
		Blob bodyBlob = Blob.valueOf('Unit Test Attachment Body');
		attach.Body = bodyBlob;
		attach.ParentId = eventList[0].Id;
		attach.ContentType = 'image/png';
		insert attach;

		Test.startTest();
		Attachment imageTest = x7sEventsListController.updateImage(
			eventList[0].Id,
			'image/png',
			'Unit Test Attachment',
			'Unit Test Attachment Body'
		);
		System.assertNotEquals(null, imageTest);
		Test.stopTest();
	}

	@IsTest
	static void test_getPicklistValues() {
		x7sEventsUtility.createEventsRecords(1);

		Test.startTest();
		List<String> eventPicklistValue = x7sEventsListController.getEventPickList(
			'School__c',
			'event'
		);
		System.assertNotEquals(null, eventPicklistValue.size());

		Test.stopTest();
	}

	@IsTest(SeeAllData=true)
	static void test_getCalendarWhereClause() {
		List<X7S_Event__c> eventList = x7sEventsUtility.createEventsRecords(1);
		System.assertNotEquals(true, eventList.isEmpty(), 'There must be an event created.');
		String customFieldString = 'Location_Name__c';
		System.debug(customFieldString);

		User communityUser = x7sEventsUtility.createCommunityUsers(
			x7sEventsTestConstants.CUSTOMER_COMMUNITY_USER_CLONE
		);

		System.runAs(communityUser) {
			Test.startTest();
			x7sEventsListController.getEventRecord(eventList[0].Id, 'customFieldString');
			Test.stopTest();
		}
	}

	@IsTest
	static void test_getTimeZone() {
		Test.startTest();
		String currentTime = x7sEventsListController.getTimeZone();
		System.assertNotEquals(null, currentTime);
		Test.stopTest();
	}

    @IsTest
	static void test_breakUpDetails() {
		Test.startTest();
		String sampleData = 'Short string';

		System.assertEquals(
			x7sEventsListController.breakUpDetails(sampleData).length(),
			sampleData.length()
		);

		sampleData =
			'<p>Sample Event <b>Summary</b> 2</p> <HTML><BODY><br/><br/><a href="https:\n' +
			'     //fran-dev-events-w18-developer-edition.gus.force.com/s/event/a01B0000007R';
		System.assertEquals(
			x7sEventsListController.breakUpDetails(sampleData).length(),
			sampleData.length() + 3
		);

		Test.stopTest();
	}

	@IsTest
	static void test_saveRelatedFile() {
		Test.startTest();
		List<Topic> topics = x7sEventsUtility.createTopic(1);
		System.assertEquals(topics.size(), 1);
        
		X7S_Event__c objEvent = new X7S_Event__c();

		objEvent.Name = 'UnitTestEvent';
		objEvent.Start_DateTime__c = System.today();
		objEvent.End_DateTime__c = System.today().addDays(5);
		objEvent.Details__c = 'Event Details is here.';
		objEvent.Location_Name__c = 'Test Location';
		objEvent.Enable_RSVP__c = false;
		objEvent.Image_Type__c = RELATED_FILES;
        insert objEvent;
        
        TopicAssignment topicAssignment = new TopicAssignment(
            EntityId = objEvent.Id,
            TopicId = topics[0].Id,
            //EntityType = 'X7S_Event__c',
            NetworkId = System.Network.getNetworkId()
        );
		insert topicAssignment;
        
		x7sEventsListController.saveEvents(objEvent, topics[0].Id, '');
		System.assertNotEquals(null, objEvent.Id);

		ContentDocumentLink contentDoc = x7sEventsListController.saveRelatedFile(
			objEvent.Id,
			'Attachment1',
			'This is test image'
		);
		System.assertNotEquals(null, contentDoc.Id);

		x7sEventsContentDocModel contentModel = new x7sEventsContentDocModel();
		System.assertEquals('', contentModel.latestImageVersionId);

		Test.stopTest();
	}
    
    @IsTest
	static void test_saveRelatedFile_fieldAccessException() {
		Test.startTest();
		List<Topic> topics = x7sEventsUtility.createTopic(1);
		System.assertEquals(topics.size(), 1);
        
		X7S_Event__c objEvent = new X7S_Event__c();

		objEvent.Name = 'UnitTestEvent';
		objEvent.Start_DateTime__c = System.today();
		objEvent.End_DateTime__c = System.today().addDays(5);
		objEvent.Details__c = 'Event Details is here.';
		objEvent.Location_Name__c = 'Test Location';
		objEvent.Enable_RSVP__c = false;
		objEvent.Image_Type__c = RELATED_FILES;
        insert objEvent;
        
		x7sEventsListController.saveEvents(objEvent, topics[0].Id, '');
		System.assertNotEquals(null, objEvent.Id);

		ContentDocumentLink contentDoc = x7sEventsListController.saveRelatedFile(
			objEvent.Id,
			'Attachment1',
			'This is test image'
		);
		System.assertNotEquals(null, contentDoc.Id);

		x7sEventsContentDocModel contentModel = new x7sEventsContentDocModel();
		System.assertEquals('', contentModel.latestImageVersionId);

		Test.stopTest();
	}

    @IsTest
	static void test_saveRelatedFile_noTopicAssignment() {
        Boolean exceptionThrown = false;
        
        Test.startTest();
		List<Topic> topics = x7sEventsUtility.createTopic(1);
		System.assertEquals(topics.size(), 1);

		X7S_Event__c objEvent = new X7S_Event__c();

		objEvent.Name = 'UnitTestEvent';
		objEvent.Start_DateTime__c = System.today();
		objEvent.End_DateTime__c = System.today().addDays(5);
		objEvent.Details__c = 'Event Details is here.';
		objEvent.Location_Name__c = 'Test Location';
		objEvent.Enable_RSVP__c = false;
		objEvent.Image_Type__c = RELATED_FILES;
        
        System.runAs(TestUserFactory.createTaniumStandardUser()) {
            try {
                x7sEventsListController.saveEvents(objEvent, topics[0].Id, '');
            } catch(Exception e) {
                exceptionThrown = true;
            }
        }
		Test.stopTest();
        
       System.assert(exceptionThrown, 'Exception should be thrown');
	}

	// Audience Test
	@IsTest
	static void test_audienceEnabled() {
		System.assertNotEquals(null, x7sEventsListController.audienceEnabled());
	}

	@IsTest(SeeAllData=true)
	static void test_getAudienceList() {
		List<User> testUsers = x7sEventsUtility.createUsers(1, 'Tanium Community Login Unknown');
		System.runAs(testUsers[0]) {
			Map<String, String> audienceList = x7sEventsListController.getAudienceList(
				x7sEventsTestConstants.TEST_COMMUNITY_ID,
				''
			);
			System.assertNotEquals(null, audienceList);

			System.assertNotEquals(
				null,
				x7sEventsListController.getAudienceTargetIds(x7sEventsTestConstants.TEST_COMMUNITY_ID)
			);
            
            List<String> eventsList = new List<String>();

			x7sEventsListWrapper eventsListWrapper = x7sEventsListController.getEventsList(
				false,
				10,
				10,
				'',
				'',
				'',
				'',
				'',
				'',
				'',
				'',
				'',
				'',
				'',
				eventsList,
				'',
				false
			);
		}
	}

	private static String createTestAudience() {
		String communityId = x7sEventsUtility.strNetworkId;
		ConnectApi.AudienceInput audienceInput = new ConnectApi.AudienceInput();
		audienceInput.name = 'X7SAudience';
		audienceInput.formulaFilterType = ConnectApi.FormulaFilterType.AllCriteriaMatch;

		// User criteria
		ConnectApi.AudienceCriterionInput userCriterionInput = new ConnectApi.AudienceCriterionInput();
		userCriterionInput.criterionType = ConnectApi.AudienceCriteriaType.FieldBased;
		userCriterionInput.criterionOperator = ConnectApi.AudienceCriteriaOperator.Equal;

		// Define the criteria field and value
		List<ConnectApi.AudienceCriterionValueInput> userCriterionValueInputList = new List<ConnectApi.AudienceCriterionValueInput>();
		ConnectApi.AudienceCriterionValueInput userInput = new ConnectApi.AudienceCriterionValueInput();
		userInput.entityType = 'User';
		userInput.entityField = 'LocaleSidKey';
		userInput.fieldValue = 'en_US';
		userCriterionValueInputList.add(userInput);
		userCriterionInput.criterion = userCriterionValueInputList;

		// Add the criteria to the list
		List<ConnectApi.AudienceCriterionInput> criteria = new List<ConnectApi.AudienceCriterionInput>();
		criteria.add(userCriterionInput);
		audienceInput.criteria = criteria;

		// Call the audience apex method to create
		return (String) ConnectApi.Personalization.createAudience(communityId, audienceInput).id;
	}

	@IsTest(SeeAllData=true)
	static void test_assignAudienceToRecord() {
		x7sEventsUtility.createEventRecord(x7sEventsTestConstants.TEST_EVENT_NAME);

		User currentUser = [SELECT Id, Name FROM User WHERE Id = :UserInfo.getUserId()];
		System.runAs(currentUser) {
			Test.startTest();
			X7S_Event__c eventObj = [
				SELECT Id, Name
				FROM X7S_Event__c
				WHERE Name = :x7sEventsTestConstants.TEST_EVENT_NAME
				LIMIT 1
			];

			String audienceId = createTestAudience();
			System.assertNotEquals(null, audienceId);

			x7sEventsListController.assignAudienceToRecord(
				audienceId,
				eventObj.Id,
				x7sEventsUtility.strNetworkId
			);

			audienceId = x7sEventsListController.getAudienceIdForRecordId(
				x7sEventsUtility.strNetworkId,
				eventObj.Id
			);
			System.assertNotEquals(null, audienceId);

			System.assertNotEquals(null, x7sEventsListController.getTargetsForRecordId('', eventObj.Id));

			x7sEventsListController.deleteCurrentAudience(eventObj.Id);
			Test.stopTest();
		}
	}

	@IsTest
	static void test_deleteMeetingExternal() {
		String meetingId = '123';
		String meetingFormat = DEFAULT_LITERAL;
		String meetingType = 'Meeting';

		String result = x7sEventsListController.deleteMeetingExternal(
			meetingId,
			meetingFormat,
			meetingType
		);

		System.assertEquals('', result);
	}

    @IsTest
	static void test_gettermethods() {
		String meetingTypes = x7sEventsListController.getEventMeetingTypeList();
		System.assertNotEquals(0, meetingTypes.length());

		String regRequiredList = x7sEventsListController.getEventRegRequiredList();
		System.assertNotEquals(0, regRequiredList.length());

		List<String> eventformatList = x7sEventsListController.getEventFormatList();
		System.assertNotEquals(0, eventformatList.size());

		String eventExperienceList = x7sEventsListController.getExperienceList();
		System.assertNotEquals(0, eventExperienceList.length());

		List<User> testUsers = x7sEventsUtility.createUsers(
			1,
			x7sEventsTestConstants.CUSTOMER_COMMUNITY_USER
		);
		List<SObject> nameOfRecord = x7sEventsListController.getCustomLookupDisplayName(
			testUsers[0].Id
		);
		System.assertNotEquals(null, nameOfRecord, 'Record name should not be null');

		System.assertNotEquals(
			null,
			x7sEventsListController.getFieldSetName(),
			'There must not be get field set.'
		);

		//Getting Event Type
		List<X7S_Event__c> eventList = x7sEventsUtility.createEventsRecords(11);
		System.assert(!eventList.isEmpty());

		String pickListValues = x7sEventsListController.getEventTypeList();
		System.assertNotEquals(null, pickListValues);
	}
    
    @IsTest
    static void test_EventListWrapper() {
		Integer listSize = 100;

        x7sEventsListController.getSessionId();
        
        x7sEventsListWrapper eventWrapper = new x7sEventsListWrapper();
		System.assertNotEquals(null, eventWrapper);
        
        x7sEventsListWrapper eventListWrapper = new x7sEventsListWrapper(
				'SELECT Id, All_Day_Event__c, Image_Type__c FROM X7S_Event__c LIMIT 1',
				new Set<String>(),
				listSize,
				System.now(),
				System.now().addDays(10),
				System.today(),
				System.today().addDays(10),
				new Set<String>(),
				LIST_VIEW_MODE,
				false,
				new Map<String, String>(),
				'',
				''
			);

			x7sEventsListWrapper eventLWrapper = new x7sEventsListWrapper(
				'SELECT Id, All_Day_Event__c, Image_Type__c FROM X7S_Event__c LIMIT 1',
				new Set<String>(),
				listSize,
				System.now(),
				System.now().addDays(10),
				new Set<String>(),
				LIST_VIEW_MODE,
				false,
				new Map<String, String>(),
				'',
				''
			);

			x7sEventsListWrapper eListWrapper = new x7sEventsListWrapper(
				'SELECT Id, All_Day_Event__c, Image_Type__c FROM X7S_Event__c LIMIT 1',
				new Set<String>(),
				listSize,
				System.now(),
				System.now().addDays(10),
				new Set<String>(),
				LIST_VIEW_MODE,
				false,
				new Map<String, String>(),
				new Set<String>(),
				'',
				''
			);
    }
    
    @IsTest
    static void test_permissionSetMember() {
        Boolean authorized = x7sEventsListController.permissionSetMember(UserInfo.getUserId(), 'X7_Summits_News_User');
        System.assert(authorized == false, 'Permission Set not assigned to user');
    }
    
    @IsTest
    static void test_deleteAttachment() {
        X7S_Event__c event = new X7S_Event__c();

        event.Name = 'event';
        event.Start_DateTime__c = Datetime.now();
        event.End_DateTime__c = Datetime.now().addDays(1);
        event.Details__c = 'Event Details is here.';
        event.Location_Name__c = 'Location';
        event.Enable_RSVP__c = false;
        event.Event_Format__c = '';
        insert event;
        
        Attachment attach = new Attachment();
		attach.Name = 'Unit Test Attachment';
		Blob bodyBlob = Blob.valueOf('Unit Test Attachment Body');
		attach.Body = bodyBlob;
		attach.ParentId = event.Id;
		attach.ContentType = 'image/png';
		insert attach;

        Test.startTest();
        x7sEventsListController.deleteAttachment(String.valueOf(event.Id));
        Test.stopTest();
        
        List<Attachment> attachments = [SELECT Id FROM Attachment WHERE ParentId = :event.Id];
        
        System.assertEquals(0, attachments.size(), 'Attachment should be deleted.');
    }
    
    @IsTest
    static void test_eventObjAccess() {
        X7S_Event__c event = new X7S_Event__c();

        event.Name = 'event';
        event.Start_DateTime__c = Datetime.now();
        event.End_DateTime__c = Datetime.now().addDays(1);
        event.Details__c = 'Event Details is here.';
        event.Location_Name__c = 'Location';
        event.Enable_RSVP__c = false;
        event.Event_Format__c = '';
        insert event;
        
        Test.startTest();
        Boolean creatable = x7sEventsListController.isObjectCreatable();
		Boolean recordEditable = x7sEventsListController.isRecordEditable(event.Id);
       	Boolean objectEditable = x7sEventsListController.isObjectEditable();
        Test.stopTest();
        
        System.assertEquals(true, creatable, 'Object should be creatable');
        System.assertEquals(true, recordEditable, 'Record should be editable');
        System.assertEquals(true, objectEditable, 'Object should be editable');
    }
    
    @IsTest
    static void test_getUserName() {
        Test.startTest();
        String userName = x7sEventsListController.getUserName(String.valueOf(UserInfo.getUserId()));
        Test.stopTest();
                                                            
        System.assert(String.isNotBlank(userName));
    }
    
    @IsTest
    static void test_getCustomLookupDisplayName_exception() {
        String invalidRecordId = '000000';
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            x7sEventsListController.getCustomLookupDisplayName(invalidRecordId);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Exception should be thrown');
    }
    
    @IsTest
    static void test_getUserName_exception() {
        String invalidRecordId = '000000';
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            x7sEventsListController.getUserName(invalidRecordId);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Exception should be thrown');
    }
    
    @IsTest
    static void test_deleteCurrentAudience_exception() {
        String invalidRecordId = '000000';
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            x7sEventsListController.deleteCurrentAudience(invalidRecordId);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Exception should be thrown');
    }
    
    @IsTest
    static void test_saveRelatedFile_exception() {
        String invalidRecordId = '000000';
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            x7sEventsListController.saveRelatedFile(invalidRecordId, 'test name', 'test image');
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Exception should be thrown');
    }
    
    @IsTest
    static void test_updateImage_exception() {
        String invalidRecordId = '000000';
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            x7sEventsListController.updateImage(invalidRecordId, 'test type', 'test name', 'test image');
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Exception should be thrown');
    }
    
    @IsTest
    static void test_getEventPickList_exception() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            x7sEventsListController.getEventPickList(null, null);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Exception should be thrown');
    }
    
    @IsTest
    static void test_getEventRecord_exception() {
        String invalidRecordId = '000000';
        Boolean exceptionThrown = false;
        Test.startTest();
        x7sEventsListController.getTopics();
        try {
            x7sEventsListController.getEventRecord(invalidRecordId, null);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Exception should be thrown');
    }
    
    @IsTest
    static void test_getSortClause() {
        Test.startTest();
        String sortByClause = '';
        sortByClause = x7sEventsListController.getSortClause('Recently Created');
        System.assert(sortByClause.contains('CreatedDate DESC'));
        
        sortByClause = x7sEventsListController.getSortClause('Name A to Z');
        System.assert(sortByClause.contains('ORDER BY Name'));
        
        sortByClause = x7sEventsListController.getSortClause('Name Z to A');
        System.assert(sortByClause.contains('ORDER BY Name DESC'));
        
        sortByClause = x7sEventsListController.getSortClause('Most Attended');
        System.assert(sortByClause.contains('Number_of_Attendees__c DESC NULLS LAST'));
        
        sortByClause = x7sEventsListController.getSortClause('Least Attended');
        System.assert(sortByClause.contains('ORDER BY Number_of_Attendees__c'));
        
        sortByClause = x7sEventsListController.getSortClause('Event Start Date Latest to Earliest');
        System.assert(sortByClause.contains('ORDER BY UpComing_Sort__c DESC'));
        
        sortByClause = x7sEventsListController.getSortClause('Event Start Date Earliest to Latest');
        System.assert(sortByClause.contains('ORDER BY UpComing_Sort__c'));
        Test.stopTest();
    }
    
    @IsTest
    static void test_getEventsList_exception() {
        Boolean exceptionThrown = false;
        List<String> eventsList = new List<String>();
        Test.startTest();
        try {
            x7sEventsListWrapper eventsListWrapper = x7sEventsListController.getEventsList(
				false,
				10,
				10,
				'',
				'',
				'',
				'',
				'',
				'',
				'',
				'',
				'',
				null,
				'',
				eventsList,
				'',
				false
			);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        
        System.assert(exceptionThrown, 'Exception should be thrown');
    }
}