/*
 * Copyright (c) 2022.  7Summits, an IBM company. All rights reserved.
 */

@IsTest
private class x7sShrCustomFieldListTest {
	@IsTest
	static void test_customFieldList() {
		x7sShrCustomFieldList fieldList = new x7sShrCustomFieldList();
		System.assertNotEquals(null, fieldList, 'LIst expected');
		System.assertEquals(0, fieldList.fields.size(), 'Expected 0 items');
	}

	@IsTest
	static void test_customFieldModel() {
		x7sShrCustomFieldModel fieldModel = new x7sShrCustomFieldModel();
		System.assertEquals('', fieldModel.name, 'Blank name expected');
	}

	@IsTest
	static void test_customFieldListSort() {
		x7sShrCustomFieldList fieldList = new x7sShrCustomFieldList();
		x7sShrCustomFieldModel fieldModel1 = new x7sShrCustomFieldModel();
		fieldModel1.name = 'item1';
		fieldModel1.sequence = 1;
		fieldList.fields.add(fieldModel1);

		x7sShrCustomFieldModel fieldModel2 = new x7sShrCustomFieldModel();
		fieldModel2.name = 'item2';
		fieldModel2.sequence = 0;
		fieldList.fields.add(fieldModel2);

		fieldList.dump('Pre sort');
		System.assertEquals(1, fieldList.fields[0].sequence, '1 expected');
		fieldList.fields.sort();
		fieldList.dump('Post sort');
		System.assertEquals(0, fieldList.fields[0].sequence, '0 expected');
	}
}