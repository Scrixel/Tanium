/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Test class for AccountSupportRequestTriggerUtility
 * @Date: 2024-01-18
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Comment
 * SS-7240    2024-01-18    Initial development
 * SS-12847   2026-03-31    Added test methods for new method processESOApprovedISR
 */
@IsTest
private class AccountSupportRequestTriggerUtilityTest {
	private static final String ESO_APPROVED_STATUS = AccountSupportRequestTriggerUtility.ESO_APPROVED_STATUS;
	private static final String ESO_DRAFT_STATUS = 'ESO Draft';
	private static final String DRAFT_STATUS = 'Draft';
	private static final String PENDING_ADVISOR_RESPONSE_STATUS = 'Pending response from Sr. Advisor contact';
	private static final String MEETING_COMPLETED_STATUS = 'Call or Meeting Completed - No Current Interest';
	private static Id ADVISOR_ENGAGEMENT_RECORDTYPEID = Utility.getRecordTypeIdByAPIName(
		'Account_Support_Request__c',
		'Sr_Advisor_Engagement'
	);
	private static Id ESO_ISR_RECORDTYPEID = Utility.getRecordTypeIdByAPIName(
		'Account_Support_Request__c',
		'ESO_Support_Request'
	);

	@TestSetup
	private static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'OpportunityTriggerHandler',
				'UserTriggerHandler'
			}
		);

		System.runAs(TestUserFactory.getAdminUser()) {
			List<Account> accts = new List<Account>();
			accts.add(TestFactory.buildAccount('Test Account'));
			accts.add(TestFactory.buildAccount('Test Account with Draft ISR'));
			insert accts;

			List<Opportunity> opps = new List<Opportunity>();
			opps.add(
				TestFactory.buildOpportunity('Test Opp', Date.today(), Utility.PROSPECTING, accts[0].Id)
			);
			opps.add(
				TestFactory.buildOpportunity(
					'Test Opp with approved ISR',
					Date.today(),
					Utility.PROSPECTING,
					accts[0].Id
				)
			);
			opps[1].CloseDate = Date.today().addDays(1);
			insert opps;

			Contact contact = TestFactory.buildContact(accts[0].Id);
			insert contact;

			List<Account_Support_Request__c> accSupportReqs = new List<Account_Support_Request__c>();
			accSupportReqs.add(
				TestFactory.buildAccountSupportRequest(
					accts[0].Id,
					opps[0].Id,
					ESO_DRAFT_STATUS,
					ESO_ISR_RECORDTYPEID
				)
			);
			accSupportReqs.add(
				TestFactory.buildAccountSupportRequest(
					accts[0].Id,
					opps[1].Id,
					ESO_APPROVED_STATUS,
					ESO_ISR_RECORDTYPEID
				)
			);
			accSupportReqs[1].ESO_Selection__c = 'Cloud Migration';
			accSupportReqs[1].Business_Unit__c = 'Americas Commercial';

			accSupportReqs.add(
				TestFactory.buildAccountSupportRequest(
					accts[0].Id,
					opps[0].Id,
					MEETING_COMPLETED_STATUS,
					ADVISOR_ENGAGEMENT_RECORDTYPEID
				)
			);
			accSupportReqs.add(
				TestFactory.buildAccountSupportRequest(
					accts[0].Id,
					opps[0].Id,
					PENDING_ADVISOR_RESPONSE_STATUS,
					ADVISOR_ENGAGEMENT_RECORDTYPEID
				)
			);
			accSupportReqs.add(
				TestFactory.buildAccountSupportRequest(
					accts[1].Id,
					null,
					DRAFT_STATUS,
					ADVISOR_ENGAGEMENT_RECORDTYPEID
				)
			);
			accSupportReqs.add(
				TestFactory.buildAccountSupportRequest(
					accts[0].Id,
					opps[1].Id,
					ESO_APPROVED_STATUS,
					ESO_ISR_RECORDTYPEID
				)
			);
			accSupportReqs[5].Kimble_Proposal_Created__c = false;
			accSupportReqs[5].ESO_Selection__c = 'Service Package';
			accSupportReqs[5].Business_Unit__c = 'Americas Commercial';
			insert accSupportReqs;
		}
	}

	@IsTest
	private static void computeAccountRollups_WhenRelatedISRExists_AlwaysSyncSrAdvisorEngagementOnAccount() {
		List<Account_Support_Request__c> internalSupportReq = [
			SELECT Id, Status__c, Account__c, RecordTypeId, RecordType.DeveloperName, CreatedDate
			FROM Account_Support_Request__c
			WHERE
				RecordTypeId = :ADVISOR_ENGAGEMENT_RECORDTYPEID
				AND Status__c = :MEETING_COMPLETED_STATUS
				AND Account__r.Name = 'Test Account'
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountSupportRequestTriggerUtility.computeAccountRollups(internalSupportReq);
			Test.stopTest();
		}

		internalSupportReq = [
			SELECT Id, Status__c, Account__c, RecordTypeId, RecordType.DeveloperName, CreatedDate
			FROM Account_Support_Request__c
			WHERE RecordTypeId = :ADVISOR_ENGAGEMENT_RECORDTYPEID AND Account__r.Name = 'Test Account'
			ORDER BY Name ASC
		];

		Account_Support_Request__c srAdvisorEngagement = internalSupportReq[0];
		Account_Support_Request__c lastSrAdvisorEngagement = internalSupportReq[1];

		Account acc = [
			SELECT Sr_Advisor_Engagement__c, Last_Sr_Advisor_Engagement__c
			FROM Account
			WHERE Id = :internalSupportReq[0].Account__c
		];

		Assert.areEqual(
			srAdvisorEngagement.Status__c,
			acc.Sr_Advisor_Engagement__c,
			'The Sr Advisor Engagement should be the same with the last ISR status'
		);
		Assert.areEqual(
			lastSrAdvisorEngagement.CreatedDate,
			acc.Last_Sr_Advisor_Engagement__c,
			'The Last Sr Advisor Engagement should be the same with the last ISR created date'
		);
	}

	@IsTest
	private static void computeAccountRollups_WhenRelatedISRIsDraft_NullSrAdvisorEngagementOnAccount() {
		List<Account_Support_Request__c> internalSupportReq = [
			SELECT Id, Status__c, Account__c, RecordTypeId, RecordType.DeveloperName, CreatedDate
			FROM Account_Support_Request__c
			WHERE Account__r.Name = 'Test Account with Draft ISR'
		];

		for (Account_Support_Request__c isr : internalSupportReq) {
			isr.Status__c = ESO_DRAFT_STATUS;
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountSupportRequestTriggerUtility.computeAccountRollups(internalSupportReq);
			Test.stopTest();
		}

		Account_Support_Request__c lastSrAdvisorEngagement = [
			SELECT Id, Status__c, Account__c, RecordTypeId, RecordType.DeveloperName, CreatedDate
			FROM Account_Support_Request__c
			WHERE Account__r.Name = 'Test Account with Draft ISR'
			ORDER BY CreatedDate DESC
			LIMIT 1
		];

		Account acc = [
			SELECT Sr_Advisor_Engagement__c, Last_Sr_Advisor_Engagement__c
			FROM Account
			WHERE Id = :internalSupportReq[0].Account__c
		];

		Assert.isNull(
			acc.Sr_Advisor_Engagement__c,
			'The Sr Advisor Engagement should be the NULL if the last ISR status is Draft OR Request Completed'
		);

		Assert.areEqual(
			lastSrAdvisorEngagement.CreatedDate,
			acc.Last_Sr_Advisor_Engagement__c,
			'The Last Sr Advisor Engagement should be the same with the last ISR created date'
		);
	}

	@IsTest
	private static void checkApprovedESOISR_WhenApprovedESOExists_ReturnsErrorMessage() {
		List<Account_Support_Request__c> esoISRs = [
			SELECT Id, Status__c, RecordTypeId, ESO_Selection__c, Business_Unit__c, Opportunity__c
			FROM Account_Support_Request__c
			WHERE
				RecordTypeId = :ESO_ISR_RECORDTYPEID
				AND Opportunity__r.Name = 'Test Opp with approved ISR'
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountSupportRequestTriggerUtility.checkApprovedESOISR(esoISRs);
			ApexPages.Message[] pageMessages = ApexPages.getMessages();
			Test.stopTest();

			Assert.areEqual(
				System.Label.Approved_ESO_ISR_Exists,
				pageMessages[0].getSummary(),
				'Custom label message should display'
			);
		}
	}

	@IsTest
	private static void checkApprovedESOISR_WhenApprovedESONotExists_NoError() {
		List<Account_Support_Request__c> esoISRs = [
			SELECT Id, Status__c, RecordTypeId, ESO_Selection__c, Business_Unit__c, Opportunity__c
			FROM Account_Support_Request__c
			WHERE RecordTypeId = :ESO_ISR_RECORDTYPEID AND Opportunity__r.Name = 'Test Opp'
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountSupportRequestTriggerUtility.checkApprovedESOISR(esoISRs);
			ApexPages.Message[] pageMessages = ApexPages.getMessages();
			Test.stopTest();

			Assert.isTrue(
				pageMessages.size() == 0,
				'No error should occur when required fields are populated.'
			);
		}
	}

	@IsTest
	private static void checkApprovedESORequiredFields_WhenESOISRIsApproved_SelectionAndBusinessUnitAreRequired() {
		List<Account_Support_Request__c> esoISRs = [
			SELECT Id, Status__c, RecordTypeId, ESO_Selection__c, Business_Unit__c
			FROM Account_Support_Request__c
			WHERE RecordTypeId = :ESO_ISR_RECORDTYPEID AND Opportunity__r.Name = 'Test Opp'
		];

		Map<Id, Account_Support_Request__c> oldMap = new Map<Id, Account_Support_Request__c>(
			esoISRs.deepClone(true, true, true)
		);

		for (Account_Support_Request__c isr : esoISRs) {
			isr.Status__c = ESO_APPROVED_STATUS;
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountSupportRequestTriggerUtility.checkApprovedESORequiredFields(esoISRs, oldMap);
			ApexPages.Message[] pageMessages = ApexPages.getMessages();
			Test.stopTest();

			Assert.areEqual(
				System.Label.Approved_ESO_Required_Field_Missing,
				pageMessages[0].getSummary(),
				'Custom label message should display'
			);
		}
	}

	@IsTest
	private static void checkApprovedESORequiredFields_WhenESOISRIsApprovedAndRequiredFieldsPopulated_NoError() {
		List<Account_Support_Request__c> esoISRs = [
			SELECT Id, Status__c, RecordTypeId, ESO_Selection__c, Business_Unit__c
			FROM Account_Support_Request__c
			WHERE RecordTypeId = :ESO_ISR_RECORDTYPEID AND Opportunity__r.Name = 'Test Opp'
		];

		Map<Id, Account_Support_Request__c> oldMap = new Map<Id, Account_Support_Request__c>(
			esoISRs.deepClone(true, true, true)
		);

		for (Account_Support_Request__c isr : esoISRs) {
			isr.Status__c = ESO_APPROVED_STATUS;
			isr.ESO_Selection__c = 'Cloud Migration';
			isr.Business_Unit__c = 'Americas Commercial';
		}

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountSupportRequestTriggerUtility.checkApprovedESORequiredFields(esoISRs, oldMap);
			ApexPages.Message[] pageMessages = ApexPages.getMessages();
			Test.stopTest();

			Assert.isTrue(
				pageMessages.size() == 0,
				'No error should occur when required fields are populated.'
			);
		}
	}

	@IsTest
	static void testProcessESOApprovedISR_WhenESOApprovedISRExists_CreateKimbleProposal() {
		List<Account_Support_Request__c> esoISRs = [
			SELECT
				Id,
				Name,
				Status__c,
				RecordTypeId,
				ESO_Selection__c,
				Business_Unit__c,
				Opportunity__c,
				Opportunity__r.CloseDate,
				Account__c,
				Business_Unit_ID_Formula__c,
				Forecast_Status_Id_Formula__c,
				ESO_Selection_ID_Formula__c,
				Kimble_Proposal_Created__c
			FROM Account_Support_Request__c
			WHERE ESO_Selection__c = 'Service Package' AND Business_Unit__c = 'Americas Commercial'
		];

		System.runAs(TestUserFactory.getAdminUser()) {
			Test.startTest();
			AccountSupportRequestTriggerUtility.processESOApprovedISR(esoISRs);
			Test.stopTest();
		}
	}
}