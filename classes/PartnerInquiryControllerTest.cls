/**
 * @Business: Test class for PartnerInquiryController
 * @Authors: Cumulus Vision, Tanium Dev team
 * RequestId  	ModifiedDate   	Description
 * TAN-855   	2020-03-17     	Created the test class
 * SS-9959   	2025-01-11     	Added test method to handle validation
 */
@IsTest
private class PartnerInquiryControllerTest {
	@TestSetup
	static void makeData() {
		Partner_Inquiry__c partnerInquiry = new Partner_Inquiry__c();
		partnerInquiry.First_Name__c = 'Test';
		partnerInquiry.Last_Name__c = 'Test';
		insert partnerInquiry;
	}

	@IsTest
	static void testPartnerInquiryController_whenSavePartnerInquiry_createPartnerInquiryRecord() {
		PageReference pageRef = Page.PartnerInquiry;
		Test.setCurrentPage(pageRef);

		Test.startTest();
		PartnerInquiryController controller = new PartnerInquiryController();
		pageRef = controller.showEmailValidationError();
		pageRef = controller.renderPrimaryContactInfo();
		pageRef = controller.renderOutSourcingInfo();
		pageRef = controller.renderGovTiesDirectorInfo();
		pageRef = controller.renderGovRelationDirectorInfo();
		pageRef = controller.renderDisciplinedDirectorInfo();
		pageRef = controller.renderCorruptDirectorInfo();
		pageRef = controller.renderConvictedDirectorInfo();
		pageRef = controller.savePartnerInquiry();
		Test.stopTest();

		Partner_Inquiry__c[] partnerInquiries = [SELECT Id FROM Partner_Inquiry__c];
		Assert.isTrue(partnerInquiries.size() == 1);
	}

	@IsTest
	static void testIsNameAndAdressValuesValid_whenPartnerInquiryIsValid_returnTrue() {
		Partner_Inquiry__c partnerInquiry = [SELECT Id, First_Name__c FROM Partner_Inquiry__c LIMIT 1];
		Test.startTest();

		partnerInquiry.First_Name__c = 'www.test.com';
		Boolean isValidAfterUpdate = PartnerInquiryController.isNameAndAdressValuesValid(
			partnerInquiry
		);
		Test.stopTest();

		Assert.isFalse(isValidAfterUpdate, 'First Name is invalid');
	}
}