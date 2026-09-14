/*
 * Copyright (c) 2021. 7Summits, an IBM Company. All rights reserved.
 */

@IsTest
public class x7sIdeasCustomFieldTest {
	@IsTest
	static void testCustomField() {
		X7S_Ideas_Custom_Field__mdt customRecord = x7sIdeasCustomFieldTest.getCustomFieldCMT();
		x7sIdeasCustomField customField = new x7sIdeasCustomField(customRecord, 1);
		System.assertNotEquals(null, customField);
		customField.dumpModel('testCustomField');

		x7sIdeasCustomField customField2 = new x7sIdeasCustomField(customRecord, 2);
		System.assertNotEquals(null, customField2);
		List<x7sIdeasCustomField> fieldList = new List<x7sIdeasCustomField>();
		fieldList.add(customField);
		fieldList.add(customField2);
		fieldList.sort();
	}

	private static X7S_Ideas_Custom_Field__mdt getCustomFieldCMT() {
		X7S_Ideas_Custom_Field__mdt cmt = new X7S_Ideas_Custom_Field__mdt();
		cmt.DeveloperName = 'Default';
		cmt.Id = null;
		cmt.Label = 'label';
		cmt.Alignment__c = '';
		cmt.API_Name__c = '';
		cmt.Data__c = '';
		cmt.Field_Label__c = '';
		cmt.Info__c = '';
		cmt.Type__c = '';
		cmt.Required__c = true;

		return cmt;
	}
}