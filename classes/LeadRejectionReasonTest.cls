/**
 * @Business: Test Class for LeadRejectionReasonController
 * @Date: 2017-06-27
 * @Author: Cumulus Vision
 * Modified  ModifiedDate   Description
 * TAN-427   2017-06-27     Initial Development
 * SS-7070   2024-01-20     Added redirect validation
 */
@isTest
private class LeadRejectionReasonTest {
	@TestSetup
	static void makeData() {
		TriggerHandler.bypass(
			new List<String>{
				'AccountTriggerHandler',
				'ContactTriggerHandler',
				'LeadTriggerHandler',
				'opportunityTriggerHandler'
			}
		);
		System.runAs(TestUserFactory.getAdminUser()) {
			List<Lead> leads = new List<Lead>();
			leads.add(TestFactory.buildLead('Test', 'Test', 'test@abc.ocm', 'Test Company', 'Pending'));
			leads.add(
				TestFactory.buildLead('Test', 'Test2', 'test2@abc.ocm', 'Test2 Company', 'Pending')
			);

			insert leads;
		}
	}

	static testMethod void process_WhenStatusIsRejectAndBlankReason_ErrorMessageNotBlank() {
		Lead lead = [SELECT Id, Lead_Reject_Rationale__c, Status FROM Lead LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			PageReference pref = System.Page.LeadRejectReason;
			Test.setCurrentPage(pref);

			Test.startTest();
			ApexPages.StandardSetController sc = new ApexPages.StandardSetController(
				new List<Lead>{ lead }
			);
			sc.setSelected(new List<Lead>{ lead });
			LeadRejectionReasonController lRRC = new LeadRejectionReasonController(sc);
			lRRC.leadRecord.Status = 'Reject';
			lRRC.leadRecord.Lead_Reject_Rationale__c = '';
			lRRC.process();
			lRRC.redirectBackClassic();
			Test.stopTest();

			Assert.isTrue(
				lRRC.errorMessage == 'You must select reject reason if status is set to reject.',
				'Error message should not be blank.'
			);
		}
	}

	static testMethod void process_WhenStatusIsNotReject_UpdateStatus() {
		Lead lead = [SELECT Id, Lead_Reject_Rationale__c, Status FROM Lead LIMIT 1];

		System.runAs(TestUserFactory.getAdminUser()) {
			PageReference pref = System.Page.LeadRejectReason;
			pref.getParameters().put('retURL', '/' + lead.Id);
			Test.setCurrentPage(pref);

			Test.startTest();
			ApexPages.StandardSetController sc = new ApexPages.StandardSetController(
				new List<Lead>{ lead }
			);
			sc.setSelected(new List<Lead>{ lead });
			LeadRejectionReasonController lRRC = new LeadRejectionReasonController(sc);
			lRRC.leadRecord.Status = 'Response';
			lRRC.process();
			lRRC.redirectBackClassic();
			Test.stopTest();

			lead = [SELECT Id, Status FROM Lead WHERE Id = :lead.Id];

			Assert.isTrue(lead.Status == 'Response', 'Status should be updated.');
		}
	}
}