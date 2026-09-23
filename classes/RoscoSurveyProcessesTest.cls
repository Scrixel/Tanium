@isTest
public with sharing class RoscoSurveyProcessesTest {
	private static String accountNameFooTest = 'Foo Account Test';
	private static String accountNameMultipleTest = 'Multiple Account Test';
	private static String accountName = 'testAccountRosco';
	private static String contactEmail = 'foo@bar.com';
	private static String contactEmailMultipleTest = 'fooMultiple@bar.com';

	static void makeData() {
		String accountMultiId = createAccount(accountNameMultipleTest);
		String contactMultiId = createContact(accountMultiId, contactEmailMultipleTest);
		String caseId = createCase(contactMultiId, accountMultiId);

		Integer days = 0;

		String threeC = 'Extremely satisfied';
		String fourC = 'Extremely satisfied';
		String fiveC = 'Yes';
		String sixC = 'RoscoTestCase-skip-My additional support case comments...';

		String three = 'Experience better by...';
		String four = 'Very satisfied';
		String five = 'Reason for satisfacation rating...';
		String six = 'I purchased Tanium for my organization or company (i.e., I authorized the purchase)';
		String seven = 'RoscoTestCase-skip-My Comment is...';

		List<Survey__c> surveys = new List<Survey__c>();

		surveys.add(buildCaseSurvey(caseId, -16, '0', 'Not so satisfied', threeC, fourC, fiveC, sixC));
		surveys.add(buildCaseSurvey(caseId, -15, '0', 'Not so satisfied', threeC, fourC, fiveC, sixC));
		surveys.add(
			buildCaseSurvey(caseId, -14, '2', 'Somewhat satisfied', threeC, fourC, fiveC, sixC)
		);
		surveys.add(
			buildCaseSurvey(caseId, -13, '2', 'Somewhat satisfied', threeC, fourC, fiveC, sixC)
		);
		surveys.add(buildCaseSurvey(caseId, -12, '7', 'Very satisfied', threeC, fourC, fiveC, sixC));
		surveys.add(buildCaseSurvey(caseId, -11, '7', 'Very satisfied', threeC, fourC, fiveC, sixC));
		surveys.add(
			buildCaseSurvey(caseId, -10, '9', 'Extremely satisfied', threeC, fourC, fiveC, sixC)
		);
		surveys.add(
			buildCaseSurvey(caseId, -9, '9', 'Extremely satisfied', threeC, fourC, fiveC, sixC)
		);

		String two = 'Reason for score...';
		surveys.add(
			buildRelationalSurvey(contactMultiId, -8, '10', two, three, four, five, six, seven)
		);
		surveys.add(
			buildRelationalSurvey(contactMultiId, -7, '10', two, three, four, five, six, seven)
		);
		surveys.add(buildRelationalSurvey(contactMultiId, -6, '9', two, three, four, five, six, seven));
		surveys.add(buildRelationalSurvey(contactMultiId, -5, '9', two, three, four, five, six, seven));
		surveys.add(buildRelationalSurvey(contactMultiId, -4, '8', two, three, four, five, six, seven));
		surveys.add(buildRelationalSurvey(contactMultiId, -3, '8', two, three, four, five, six, seven));
		surveys.add(buildRelationalSurvey(contactMultiId, -2, '6', two, three, four, five, six, seven));
		surveys.add(buildRelationalSurvey(contactMultiId, -1, '6', two, three, four, five, six, seven));

		insert surveys;
	}

	private static String createAccount(String name) {
		Account accountObj = TestFactory.buildAccount(name);
		insert accountObj;
		return String.valueOf(accountObj.Id);
	}

	private static String createCase(String contactId, String accountId) {
		Case caseObj = new Case(
			ContactId = contactId,
			accountid = accountId,
			subject = 'ROSCOTESTCASE',
			Severity_Community__c = '3',
			type = 'Incident',
			Reason = 'New problem',
			Origin = 'Email',
			suppliedEmail = '99@outlook.com',
			status = 'On Hold',
			Description = 'ROSCOTESTCASE',
			RecordTypeId = '0120e000000Dxi7AAC'
		);
		insert caseObj;

		return String.valueOf(caseObj.Id);
	}

	private static String createIsr(String accountId, String name) {
		Id advisorEngagementRecordTypeId = Utility.getRecordTypeIdByAPIName(
			'Account_Support_Request__c',
			'Training_Request'
		);

		Account_Support_Request__c isrObj = new Account_Support_Request__c(
			Account__c = accountId,
			Status__c = 'Call or Meeting Completed - No Current Interest',
			RecordTypeId = advisorEngagementRecordTypeId
		);
		insert isrObj;
		return String.valueOf(isrObj.Id);
	}

	private static String createContact(String accountId, String email) {
		Contact contactObj = new Contact(
			Email = email,
			FirstName = 'Test',
			LastName = 'Apex',
			AccountId = accountId
		);
		insert contactObj;

		return String.valueOf(contactObj.Id);
	}

	private static void createTriggerManagement() {
		Trigger_Management__c surveyTrigger = new Trigger_Management__c(
			name = 'SurveyTrigger',
			Active__c = true
		);
		insert surveyTrigger;

		Trigger_Management__c ringLeadTrigger = new Trigger_Management__c(
			name = 'RingLeadTrigger',
			Active__c = false
		);
		insert ringLeadTrigger;

		Trigger_Management__c contactTrigger = new Trigger_Management__c(
			name = 'ContactTrigger',
			Active__c = false
		);
		insert contactTrigger;

		Trigger_Management__c accountTrigger = new Trigger_Management__c(
			name = 'AccountTrigger',
			Active__c = false
		);
		insert accountTrigger;
	}

	private static Rosco_Account__c getRoscoAccount(String accountId) {
		Rosco_Account__c ret = new Rosco_Account__c();

		String soql =
			'SELECT Support_Type__c, ' +
			'Survey_AllTimeScore__c, ' +
			'Survey_AllTimeCount__c, ' +
			'Survey_Rolling12MonthScore__c, ' +
			'Survey_Rolling12MonthCount__c, ' +
			'Survey_MostRecentScore__c, ' +
			'Survey_AllTimeCaseCount__c, ' +
			'Survey_AllTimeCaseScore__c, ' +
			'Survey_AllTimeRelationalCount__c, ' +
			'Survey_AllTimeRelationalScore__c, ' +
			'Survey_MostRecentCaseDate__c, ' +
			'Survey_MostRecentCaseScore__c, ' +
			'Survey_MostRecentRelationalDate__c, ' +
			'Survey_MostRecentRelationalScore__c, ' +
			'Survey_Rolling12MonthCaseCount__c, ' +
			'Survey_Rolling12MonthCaseScore__c, ' +
			'Survey_Rolling12MonthRelationalCount__c, ' +
			'Survey_Rolling12MonthRelationalScore__c, ' +
			'Survey_AllTimeCaseCSAT__c, ' +
			'Survey_Rolling12MonthCaseCSAT__c, ' +
			'Survey_MostRecentCaseCSAT__c ' +
			'FROM Rosco_Account__c ' +
			'WHERE Account__c = \'' +
			accountId +
			'\'';

		System.debug('soql:' + soql);

		List<Rosco_Account__c> accounts = Database.query(soql);

		if (accounts.size() != 0) {
			ret = accounts[0];
		}

		return ret;
	}

	private static void insertCaseSurvey(
		String caseId,
		Integer days,
		String one,
		String two,
		String three,
		String four,
		String five,
		String six
	) {
		Survey__c cas = new Survey__c();
		cas.Name = 'Support Center CSAT';
		cas.Case__c = caseId;
		cas.SurveyCreateDate__c = Datetime.now().addDays(days);

		cas.Case_1_Recommend__c = one;
		cas.Case_2_Overall_Support__c = two;
		cas.Case_3_Speed_of_Resolution__c = three;
		cas.Case_4_Technical_Knowledge__c = four;
		cas.Case_5_Issue_Resolved__c = five;
		cas.Case_6_Comment__c = six;

		insert cas;
	}

	private static Survey__c buildCaseSurvey(
		String caseId,
		Integer days,
		String one,
		String two,
		String three,
		String four,
		String five,
		String six
	) {
		Survey__c cas = new Survey__c();
		cas.Name = 'Support Center CSAT';
		cas.Case__c = caseId;
		cas.SurveyCreateDate__c = Datetime.now().addDays(days);

		cas.Case_1_Recommend__c = one;
		cas.Case_2_Overall_Support__c = two;
		cas.Case_3_Speed_of_Resolution__c = three;
		cas.Case_4_Technical_Knowledge__c = four;
		cas.Case_5_Issue_Resolved__c = five;
		cas.Case_6_Comment__c = six;

		return cas;
	}

	private static void insertESCSATSurvey(
		String contactId,
		Integer days,
		String one,
		String two,
		String three,
		String four,
		String five,
		String six,
		String seven,
		String eight,
		String nine,
		String ten,
		String eleven
	) {
		Survey__c survey = new Survey__c();
		survey.Name = 'Tanium Enterprise Services Customer Satisfaction Survey';
		survey.Contact__c = contactId;
		survey.SurveyCreateDate__c = Datetime.now().addDays(days);

		survey.ESCSAT_1_Recommend__c = one;
		survey.ESCSAT_2_Reason__c = two;
		survey.ESCSAT_3_Experience__c = three;
		survey.ESCSAT_4_Respect__c = four;
		survey.ESCSAT_5_Goals__c = five;
		survey.ESCSAT_6_Professional__c = six;
		survey.ESCSAT_7_Trusted__c = seven;
		survey.ESCSAT_8_Cost__c = eight;
		survey.ESCSAT_9_Comment__c = nine;
		survey.ESCSAT_10a_Name__c = ten;
		survey.ESCSAT_10b_Company__c = eleven;

		insert survey;
	}

	private static void insertESOSurvey(
		String isrId,
		Integer days,
		String one,
		String two,
		String threeA,
		String threeB,
		String threeC,
		String threeD,
		String threeE,
		String threeF,
		String threeG,
		String threeH,
		String four
	) {
		Survey__c eso = new Survey__c();
		eso.Name = 'Enterprise Services Engagement Feedback Survey';
		eso.ISR__c = isrId;
		eso.SurveyCreateDate__c = Datetime.now().addDays(days);

		eso.ESO_1_Rate__c = one;
		eso.ESO_2_Needs__c = two;
		eso.ESO_3a_Trust__c = threeA;
		eso.ESO_3b_Ease__c = threeB;
		eso.ESO_3c_Effective__c = threeC;
		eso.ESO_3d_Value__c = threeD;
		eso.ESO_3e_SalesExp__c = threeE;
		eso.ESO_3f_SupExp__c = threeF;
		eso.ESO_3g_Recommend__c = threeG;
		eso.ESO_3h_Rate__c = threeH;
		eso.ESO_4_Comment__c = four;

		insert eso;
	}

	private static void insertFTAMSurvey(
		String contactId,
		Integer days,
		String one,
		String two,
		String three,
		String four,
		String five,
		String six,
		String seven,
		String eight,
		String nine,
		String ten
	) {
		Survey__c survey = new Survey__c();
		survey.Name = 'Tanium Technical Account Management Survey';
		survey.Contact__c = contactId;
		survey.SurveyCreateDate__c = Datetime.now().addDays(days);

		survey.FTAM_1_Recommend__c = one;
		survey.FTAM_2_Reason__c = two;
		survey.FTAM_3_Instrumental__c = three;
		survey.FTAM_4_Trusted__c = four;
		survey.FTAM_5_Deployment__c = five;
		survey.FTAM_6_Operationalized__c = six;
		survey.FTAM_7_Planning__c = seven;
		survey.FTAM_8_Comment__c = eight;
		//survey.FTAM_9a_Name__c = nine;
		//survey.FTAM_9b_Company__c = ten;

		insert survey;
	}

	private static void insertImplementSurvey(
		String contactId,
		Integer days,
		String one,
		String two,
		String three,
		String four,
		String five,
		String six,
		String seven,
		String eight,
		String nine
	) {
		Survey__c survey = new Survey__c();
		survey.Name = 'Implement Survey';
		survey.Contact__c = contactId;
		survey.SurveyCreateDate__c = Datetime.now().addDays(days);

		survey.Implement_1_Recommend__c = one;
		survey.Implement_2_Reason__c = two;
		survey.Implement_3_Prepare__c = three;
		survey.Implement_4_Clear__c = four;
		survey.Implement_5_Length__c = five;
		survey.Implement_6_Value__c = six;
		survey.Implement_7_Comment__c = seven;
		survey.Implement_8a_Name__c = eight;
		survey.Implement_8a_Name__c = nine;

		insert survey;
	}

	private static void insertOnboardSurvey(
		String contactId,
		Integer days,
		String one,
		String two,
		String three,
		String four,
		String five,
		String six,
		String seven
	) {
		Survey__c survey = new Survey__c();
		survey.Name = 'Onboard Survey';
		survey.Contact__c = contactId;
		survey.SurveyCreateDate__c = Datetime.now().addDays(days);

		survey.Onboard_1_Recommend__c = one;
		survey.Onboard_2_Reason__c = two;
		survey.Onboard_3_Outcome__c = three;
		survey.Onboard_4_Prepare__c = four;
		survey.Onboard_5_Comment__c = five;
		survey.Onboard_6a_Name__c = six;
		survey.Onboard_6b_Company__c = seven;

		insert survey;
	}

	private static void insertRelationalSurvey(
		String contactId,
		Integer days,
		String one,
		String two,
		String three,
		String four,
		String five,
		String six,
		String seven
	) {
		Survey__c relational = new Survey__c();
		relational.Name = 'Relational NPS';
		relational.Contact__c = contactId;
		relational.SurveyCreateDate__c = Datetime.now().addDays(days);

		relational.Relational_1_Recommend__c = one;
		relational.Relational_2_Recommend_Reason__c = two;
		relational.Relational_3_Experience__c = three;
		relational.Relational_4_Value_Satisfaction__c = four;
		relational.Relational_5_Value_Satisfaction_Reason__c = five;
		relational.Relational_6_Authority__c = six;
		relational.Relational_7_Comment__c = seven;

		insert relational;
	}

	private static Survey__c buildRelationalSurvey(
		String contactId,
		Integer days,
		String one,
		String two,
		String three,
		String four,
		String five,
		String six,
		String seven
	) {
		Survey__c relational = new Survey__c();
		relational.Name = 'Relational NPS';
		relational.Contact__c = contactId;
		relational.SurveyCreateDate__c = Datetime.now().addDays(days);

		relational.Relational_1_Recommend__c = one;
		relational.Relational_2_Recommend_Reason__c = two;
		relational.Relational_3_Experience__c = three;
		relational.Relational_4_Value_Satisfaction__c = four;
		relational.Relational_5_Value_Satisfaction_Reason__c = five;
		relational.Relational_6_Authority__c = six;
		relational.Relational_7_Comment__c = seven;

		return relational;
	}

	@isTest(SeeAllData=false)
	static void caseSurveyTestOneSurvey() {
		createTriggerManagement();
		String accountId = createAccount(accountName);
		//Id accountId = [SELECT Id FROM Account WHERE Name=:accountNameFooTest].Id;
		String contactId = createContact(accountId, 'foo@bar.com');
		String caseId = createCase(contactId, accountId);
		Integer days = 0;

		Case_Management__c cmSetting = new Case_Management__c();
		cmSetting.Name = '';
		cmSetting.rosco_owea_noreply__c = 'foo@tanium.com';
		cmSetting.rosco_include_owner_survey_email__c = 'true';
		cmSetting.rosco_sc_csat_email__c = 'foo@tanium.com';
		cmSetting.rosco_sc_csat_slackId__c = 'foo';
		cmSetting.rosco_owea_noreply__c = 'foo@tanium.com';
		insert cmSetting;

		String one = '10';
		String two = 'Extremely satisfied';
		String three = 'Extremely satisfied';
		String four = 'Extremely satisfied';
		String five = 'Yes';
		String six = 'My additional support case comments...';

		insertCaseSurvey(caseId, days, one, two, three, four, five, six);

		Rosco_Account__c roscoAccount = getRoscoAccount(accountId);
		System.debug(roscoAccount);

		System.assertEquals(1, roscoAccount.Survey_AllTimeCaseCount__c);
		System.assertEquals(100, roscoAccount.Survey_AllTimeCaseScore__c);

		System.assertNotEquals(null, roscoAccount.Survey_MostRecentCaseDate__c);
		System.assertEquals(100, roscoAccount.Survey_MostRecentCaseScore__c);

		System.assertEquals(1, roscoAccount.Survey_Rolling12MonthCaseCount__c);
		System.assertEquals(100, roscoAccount.Survey_Rolling12MonthCaseScore__c);
	}

	/*
    @isTest(SeeAllData=false) static void caseSurveyTestMultipleSurvey() {

        createTriggerManagement();
        String accountId = createAccount(accountName);
        Integer days = 0;

        String one = '10';
        String two = 'Extremely satisfied';
        String three = 'Extremely satisfied';
        String four = 'Extremely satisfied';
        String five = 'Yes';
        String six = 'My additional support case comments...';

        // 1 Detractors
        for(Integer c=0; c < 1; c++){
            String contactId = createContact(accountId, 'detractor' + String.valueOf(c) + '@bar.com');
            String caseId = createCase(contactId, accountId);            
            one = '6';
            insertCaseSurvey(caseId, days, one,two,three,four,five,six);
        }

        // 2 Passives
        for(Integer c=0; c < 2; c++){
            String contactId = createContact(accountId, 'passive' + String.valueOf(c) + '@bar.com');
            String caseId = createCase(contactId, accountId);               
            one = '7';
            insertCaseSurvey(caseId, days, one,two,three,four,five,six);
        }        

        // 7 Promoters
        for(Integer c=0; c < 7; c++){
            String contactId = createContact(accountId, 'promoter' + String.valueOf(c) + '@bar.com');
            String caseId = createCase(contactId, accountId);               
            one = '9';
            insertCaseSurvey(caseId, days, one,two,three,four,five,six);
        }   
        
        // Old Detractor
        String contactId = createContact(accountId, 'oldDetractor@bar.com');
        String caseId = createCase(contactId, accountId);           
        one = '6';
        days = -366;
        insertCaseSurvey(caseId, days, one,two,three,four,five,six);
    
        Rosco_Account__c roscoAccount = getRoscoAccount(accountId);
        System.assertNotEquals(null, roscoAccount.Survey_MostRecentCaseDate__c);
        System.assertEquals(9, roscoAccount.Survey_MostRecentCaseScore__c);

        System.assertEquals(10, roscoAccount.Survey_Rolling12MonthCaseCount__c);
        System.assertEquals(60, roscoAccount.Survey_Rolling12MonthCaseScore__c);
        
        System.assertEquals(11, roscoAccount.Survey_AllTimeCaseCount__c);
        System.assertEquals(45, roscoAccount.Survey_AllTimeCaseScore__c);

    }    
    */
	/*
    @isTest(SeeAllData=false) static void caseSurveyTestMultipleSurveyNegative() {

        createTriggerManagement();
        String accountId = createAccount(accountName);
        Integer days = 0;


        String one = '10';
        String two = 'Extremely satisfied';
        String three = 'Extremely satisfied';
        String four = 'Extremely satisfied';
        String five = 'Yes';
        String six = 'My additional support case comments...';    

        // 7 Detractors
        for(Integer c=0; c < 7; c++){
            String contactId = createContact(accountId, 'detractor' + String.valueOf(c) + '@bar.com');
            String caseId = createCase(contactId, accountId);               
            one = '6';
            insertCaseSurvey(caseId, days, one,two,three,four,five,six);
        }

        // 2 Passives
        for(Integer c=0; c < 2; c++){
            String contactId = createContact(accountId, 'passive' + String.valueOf(c) + '@bar.com');
            String caseId = createCase(contactId, accountId);               
            one = '7';
            insertCaseSurvey(caseId, days, one,two,three,four,five,six);
        }        

        // 1 Promoters
        for(Integer c=0; c < 1; c++){
            String contactId = createContact(accountId, 'promoter' + String.valueOf(c) + '@bar.com');
            String caseId = createCase(contactId, accountId);               
            one = '9';
            insertCaseSurvey(caseId, days, one,two,three,four,five,six);
        }   
        
        // Old Detractor
        String contactId = createContact(accountId, 'oldDetractor@bar.com');
        String caseId = createCase(contactId, accountId);           
        one = '6';
        days = -366;
        insertCaseSurvey(caseId, days, one,two,three,four,five,six);
        
        Rosco_Account__c roscoAccount = getRoscoAccount(accountId);
        System.assertNotEquals(null, roscoAccount.Survey_MostRecentCaseDate__c);
        System.assertEquals(9, roscoAccount.Survey_MostRecentCaseScore__c);

        System.assertEquals(10, roscoAccount.Survey_Rolling12MonthCaseCount__c);
        System.assertEquals(-60, roscoAccount.Survey_Rolling12MonthCaseScore__c);
        
        System.assertEquals(11, roscoAccount.Survey_AllTimeCaseCount__c);
        System.assertEquals(-63, roscoAccount.Survey_AllTimeCaseScore__c);

    }   
    */
	@isTest(SeeAllData=false)
	static void escsatSurveyTestOneSurvey() {
		createTriggerManagement();
		String accountId = createAccount(accountName);
		//Id accountId = [SELECT Id FROM Account WHERE Name=:accountNameFooTest].Id;
		String contactId = createContact(accountId, 'foo@bar.com');
		Integer days = 0;

		String one = '10';
		String two = 'Faster Response';
		String threeToEightA = 'Strongly Agree';
		String threeToEightB = 'Agree';
		String threeToEightC = 'Neutral';
		String threeToEightD = 'Disagree';
		String threeToEightE = 'Strongly Disagree';
		String nine = 'Comment123';
		String ten = 'Name 123';
		String eleven = 'Company 123';

		insertESCSATSurvey(
			contactId,
			days,
			one,
			two,
			threeToEightA,
			threeToEightA,
			threeToEightA,
			threeToEightA,
			threeToEightA,
			threeToEightA,
			nine,
			ten,
			eleven
		);
	}

	@isTest(SeeAllData=false)
	static void debugMe() {
	}

	@isTest(SeeAllData=false)
	static void esoSurveyTestOneSurvey() {
		createTriggerManagement();
		String accountId = createAccount(accountName);
		//Id accountId = [SELECT Id FROM Account WHERE Name=:accountNameFooTest].Id;
		String contactId = createContact(accountId, 'foo@bar.com');
		String isrId = createISR(accountId, 'fooisr');
		Integer days = 0;

		String one = '10';
		String two = 'Faster Response';
		String threeA = '10';
		String threeB = '10';
		String threeC = '10';
		String threeD = '10';
		String threeE = '10';
		String threeF = '10';
		String threeG = '10';
		String threeH = '10';
		String four = 'Comment123';

		insertESOSurvey(
			isrId,
			days,
			one,
			two,
			threeA,
			threeB,
			threeC,
			threeD,
			threeE,
			threeF,
			threeG,
			threeH,
			four
		);

		Rosco_Account__c roscoAccount = getRoscoAccount(accountId);
		System.debug(roscoAccount);
	}

	@isTest(SeeAllData=false)
	static void fTAMSurveyTestOneSurvey() {
		createTriggerManagement();
		String accountId = createAccount(accountName);
		//Id accountId = [SELECT Id FROM Account WHERE Name=:accountNameFooTest].Id;
		String contactId = createContact(accountId, 'foo@bar.com');
		Integer days = 0;

		String one = '10';
		String two = 'Faster Response';
		String threeToSevenA = 'Strongly Agree';
		String threeToSevenB = 'Agree';
		String threeToSevenC = 'Neither agree nor disagree';
		String threeToSevenD = 'Disagree';
		String threeToSevenE = 'Strongly Disagree';
		String eight = 'Comment123';
		String nine = 'Name 123';
		String ten = 'Company 123';

		insertFTAMSurvey(
			contactId,
			days,
			one,
			two,
			threeToSevenA,
			threeToSevenA,
			threeToSevenA,
			threeToSevenA,
			threeToSevenA,
			eight,
			nine,
			ten
		);
	}

	static void implementSurveyTestOneSurvey() {
		createTriggerManagement();
		String accountId = createAccount(accountName);
		//Id accountId = [SELECT Id FROM Account WHERE Name=:accountNameFooTest].Id;
		String contactId = createContact(accountId, 'foo@bar.com');
		Integer days = 0;

		String one = '10';
		String two = 'Faster Response';
		String threeToSixA = 'Strongly Agree';
		String threeToSixB = 'Agree';
		String threeToSixC = 'Neutral';
		String threeToSixD = 'Disagree';
		String threeToSixE = 'Strongly Disagree';
		String seven = 'Comment123';
		String eight = 'Name 123';
		String nine = 'Company 123';

		insertImplementSurvey(
			contactId,
			days,
			one,
			two,
			threeToSixA,
			threeToSixA,
			threeToSixA,
			threeToSixA,
			seven,
			eight,
			nine
		);
	}

	@isTest(SeeAllData=false)
	static void onboardSurveyTestOneSurvey() {
		createTriggerManagement();
		String accountId = createAccount(accountName);
		//Id accountId = [SELECT Id FROM Account WHERE Name=:accountNameFooTest].Id;
		String contactId = createContact(accountId, 'foo@bar.com');
		Integer days = 0;

		String one = '10';
		String two = 'Faster Response';
		String threeToFourA = 'Extremely aligned';
		String threeToFourB = 'Very aligned';
		String threeToFourC = 'Somewhat aligned';
		String threeToFourD = 'Not so aligned';
		String threeToFourE = 'Not at all aligned';
		String five = 'Comment123';
		String six = 'Name 123';
		String seven = 'Company 123';

		insertOnboardSurvey(contactId, days, one, two, threeToFourA, threeToFourA, five, six, seven);
	}

	@isTest(SeeAllData=false)
	static void relationalSurveyTestOneSurvey() {
		createTriggerManagement();
		String accountId = createAccount(accountName);
		//Id accountId = [SELECT Id FROM Account WHERE Name=:accountNameFooTest].Id;
		String contactId = createContact(accountId, 'foo@bar.com');
		Integer days = 0;

		String one = '10';
		String two = 'Reason for score...';
		String three = 'Experience better by...';
		String four = 'Very satisfied';
		String five = 'Reason for satisfacation rating...';
		String six = 'I purchased Tanium for my organization or company (i.e., I authorized the purchase)';
		String seven = 'My Comment is...';

		insertRelationalSurvey(contactId, days, one, two, three, four, five, six, seven);

		Rosco_Account__c roscoAccount = getRoscoAccount(accountId);
		System.debug(roscoAccount);

		System.assertEquals(1, roscoAccount.Survey_AllTimeRelationalCount__c);
		System.assertEquals(100, roscoAccount.Survey_AllTimeRelationalScore__c);

		System.assertNotEquals(null, roscoAccount.Survey_MostRecentRelationalDate__c);
		System.assertEquals(100, roscoAccount.Survey_MostRecentRelationalScore__c);

		System.assertEquals(1, roscoAccount.Survey_Rolling12MonthRelationalCount__c);
		System.assertEquals(100, roscoAccount.Survey_Rolling12MonthRelationalScore__c);
	}
	/*
    @isTest(SeeAllData=false) static void relationalSurveyTestMultipleSurvey() {

        createTriggerManagement();
        String accountId = createAccount(accountName);
        Integer days = 0;

        String one = '10';
        String two = 'Reason for score...';
        String three = 'Experience better by...';
        String four = 'Very satisfied';
        String five = 'Reason for satisfacation rating...';
        String six = 'I purchased Tanium for my organization or company (i.e., I authorized the purchase)';
        String seven = 'My Comment is...';        

        // 1 Detractors
        for(Integer c=0; c < 1; c++){
            String contactId = createContact(accountId, 'detractor' + String.valueOf(c) + '@bar.com');
            one = '6';
            insertRelationalSurvey(contactId, days, one,two,three,four,five,six,seven);
        }

        // 2 Passives
        for(Integer c=0; c < 2; c++){
            String contactId = createContact(accountId, 'passive' + String.valueOf(c) + '@bar.com');
            one = '7';
            insertRelationalSurvey(contactId, days, one,two,three,four,five,six,seven);
        }        

        // 7 Promoters
        for(Integer c=0; c < 7; c++){
            String contactId = createContact(accountId, 'promoter' + String.valueOf(c) + '@bar.com');
            one = '9';
            insertRelationalSurvey(contactId, days, one,two,three,four,five,six,seven);
        }   
        
        // Old Detractor
        String contactId = createContact(accountId, 'oldDetractor@bar.com');
        one = '6';
        days = -366;
        insertRelationalSurvey(contactId, days, one,two,three,four,five,six,seven);
    
        Rosco_Account__c roscoAccount = getRoscoAccount(accountId);
        System.assertNotEquals(null, roscoAccount.Survey_MostRecentRelationalDate__c);
        System.assertEquals(9, roscoAccount.Survey_MostRecentRelationalScore__c);

        System.assertEquals(10, roscoAccount.Survey_Rolling12MonthRelationalCount__c);
        System.assertEquals(60, roscoAccount.Survey_Rolling12MonthRelationalScore__c);
        
        System.assertEquals(11, roscoAccount.Survey_AllTimeRelationalCount__c);
        System.assertEquals(45, roscoAccount.Survey_AllTimeRelationalScore__c);

    }    
    */
	/*
    @isTest(SeeAllData=false) static void relationalSurveyTestMultipleSurveyNegative() {

        createTriggerManagement();
        String accountId = createAccount(accountName);
        Integer days = 0;

        String one = '10';
        String two = 'Reason for score...';
        String three = 'Experience better by...';
        String four = 'Very satisfied';
        String five = 'Reason for satisfacation rating...';
        String six = 'I purchased Tanium for my organization or company (i.e., I authorized the purchase)';
        String seven = 'My Comment is...';        

        // 7 Detractors
        for(Integer c=0; c < 7; c++){
            String contactId = createContact(accountId, 'detractor' + String.valueOf(c) + '@bar.com');
            one = '6';
            insertRelationalSurvey(contactId, days, one,two,three,four,five,six,seven);
        }

        // 2 Passives
        for(Integer c=0; c < 2; c++){
            String contactId = createContact(accountId, 'passive' + String.valueOf(c) + '@bar.com');
            one = '7';
            insertRelationalSurvey(contactId, days, one,two,three,four,five,six,seven);
        }        

        // 1 Promoters
        for(Integer c=0; c < 1; c++){
            String contactId = createContact(accountId, 'promoter' + String.valueOf(c) + '@bar.com');
            one = '9';
            insertRelationalSurvey(contactId, days, one,two,three,four,five,six,seven);
        }   
        
        // Old Detractor
        String contactId = createContact(accountId, 'oldDetractor@bar.com');
        one = '6';
        days = -366;
        insertRelationalSurvey(contactId, days, one,two,three,four,five,six,seven);
        
        Rosco_Account__c roscoAccount = getRoscoAccount(accountId);
        System.assertNotEquals(null, roscoAccount.Survey_MostRecentRelationalDate__c);
        System.assertEquals(9, roscoAccount.Survey_MostRecentRelationalScore__c);

        System.assertEquals(10, roscoAccount.Survey_Rolling12MonthRelationalCount__c);
        System.assertEquals(-60, roscoAccount.Survey_Rolling12MonthRelationalScore__c);
        
        System.assertEquals(11, roscoAccount.Survey_AllTimeRelationalCount__c);
        System.assertEquals(-63, roscoAccount.Survey_AllTimeRelationalScore__c);

    }        
    */

	@isTest(SeeAllData=false)
	static void multipleTest() {
		createTriggerManagement();
		makeData();

		Id accountId = [SELECT Id FROM Account WHERE Name = :accountNameMultipleTest].Id;

		Rosco_Account__c roscoAccount = getRoscoAccount(accountId);
		System.debug(roscoAccount);

		// Relational and Transacational
		System.assertEquals(0, roscoAccount.Survey_AllTimeScore__c);
		System.assertEquals(16, roscoAccount.Survey_AllTimeCount__c);
		System.assertEquals(0, roscoAccount.Survey_Rolling12MonthScore__c);
		System.assertEquals(16, roscoAccount.Survey_Rolling12MonthCount__c);
		System.assertEquals(-100, roscoAccount.Survey_MostRecentScore__c);

		// Relational
		System.assertEquals(25, roscoAccount.Survey_AllTimeRelationalScore__c);
		System.assertEquals(8, roscoAccount.Survey_AllTimeRelationalCount__c);
		System.assertEquals(25, roscoAccount.Survey_Rolling12MonthRelationalScore__c);
		System.assertEquals(8, roscoAccount.Survey_Rolling12MonthRelationalCount__c);
		System.assertEquals(-100, roscoAccount.Survey_MostRecentRelationalScore__c);

		// Transactional
		System.assertEquals(-25, roscoAccount.Survey_AllTimeCaseScore__c);
		System.assertEquals(8, roscoAccount.Survey_AllTimeCaseCount__c);
		System.assertEquals(-25, roscoAccount.Survey_Rolling12MonthCaseScore__c);
		System.assertEquals(8, roscoAccount.Survey_Rolling12MonthCaseCount__c);
		System.assertEquals(100, roscoAccount.Survey_MostRecentCaseScore__c);

		System.assertEquals(75, roscoAccount.Survey_AllTimeCaseCSAT__c);
		System.assertEquals(75, roscoAccount.Survey_Rolling12MonthCaseCSAT__c);
		System.assertEquals(40, roscoAccount.Survey_MostRecentCaseCSAT__c);
	}

	public static void sleep() {
		Long startingTime = System.now().getTime(); // Num milliseconds since Jan 1 1970
		Integer delayInMilliseconds = 500;
		while (System.now().getTime() - startingTime < delayInMilliseconds) {
			// Do nothing until desired delay has passed
		}
	}
}