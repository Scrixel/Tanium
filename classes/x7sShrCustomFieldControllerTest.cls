/*
 * Copyright (c) 2022.  7Summits, an IBM company. All rights reserved.
 */

@IsTest
private class x7sShrCustomFieldControllerTest {
	@IsTest
	static void testGetCustomFieldsEmpty() {
        x7sShrCustomFieldList fieldList =  x7sShrCustomFieldController.getCustomFields('');
        System.assertNotEquals(null, fieldList, 'Null not expected' );
	}

	@IsTest
	static void testGetFieldset() {
		x7sShrCustomFieldList fieldList = x7sShrCustomFieldController.getCustomFields('Custom_Field_Set_1');
		System.assertNotEquals(null, fieldList, 'List expected');
		fieldList.dump('Custom_Field_Set_1');
	}

	@IsTest
	static void testSearch() {
		List<String> selectedIds = new List<String>();
		System.assertNotEquals(null, x7sShrCustomFieldController.objectNameFieldSearch('Account', 'Contact', 'test', selectedIds), 'Null not expected');
	}
    
    @IsTest
    static void testgetLookupReference() {
        String referenceObject = x7sShrCustomFieldController.getLookupReference('Contact', 'AccountId');
        System.assertEquals('Account', referenceObject, 'Should return Account');
    }
}