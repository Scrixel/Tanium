/*
 * Licensed Materials - Property of IBM
 * 6949-83K
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
private class x7sMembersFilters_Test {
	static string filterSetNull = 'filterSet is null';

	@IsTest
	private static void testFilterGetFilter() {
		Test.startTest();

		x7sMembersFilters filterSet = new x7sMembersFilters();
		System.assertNotEquals(null, filterSet, filterSetNull);
		System.debug('Filter set : ' + filterSet);

		X7S_Members_Filter_Item__mdt testFilter = filterSet.getFilterByName(
			filterSet.filters[0].DeveloperName
		);
		System.assertNotEquals(null, testFilter, 'testFilter is null');

		testFilter = filterSet.getFilterByName('SHOULD_NOT_EXIST');
		System.assertEquals(null, testFilter, 'testFilter should not be null');

		for (X7S_Members_Filter_Item__mdt filter : filterSet.filters) {
			testFilter = filterSet.getFilterByFieldName(filter.Field_Name__c);
			System.assertNotEquals(null, testFilter, 'testFilter is null');
		}

		testFilter = filterSet.getFilterByFieldName('SHOULD_NOT_EXIST');
		System.assertEquals(null, testFilter, 'testFilter should not be null');

		Test.stopTest();
	}

	@IsTest
	private static void testClearFilter() {
		Test.startTest();

		x7sMembersFilters filterSet = new x7sMembersFilters();
		System.assertNotEquals(null, filterSet, filterSetNull);

		X7S_Members_Filter__c clearFilter = filterSet.clearFilter(filterSet.filters[0].DeveloperName);
		System.assertNotEquals(null, clearFilter, 'clearFilter is null');

		Test.stopTest();
	}

	@IsTest
	private static void testGetRecords() {
		Test.startTest();

		x7sMembersFilters filterSet = new x7sMembersFilters();
		System.assertNotEquals(null, filterSet, filterSetNull);

		List<String> records = filterSet.getFieldRecords(filterSet.filters[0]);
		System.assertNotEquals(null, records, 'there are no records');
		System.debug('Records: ' + records);

		Test.stopTest();
	}

	@IsTest
	private static void testGetFieldName() {
		Test.startTest();

		x7sMembersFilters filterSet = new x7sMembersFilters();
		System.assertNotEquals(null, filterSet, filterSetNull);

		String fieldName = filterSet.getFieldName(filterSet.filters[0]);
		System.assertNotEquals(null, fieldName, 'fieldName is null');

		Test.stopTest();
	}

	@IsTest
	private static void testGetFilterEntries() {
		Test.startTest();
		try {
			x7sMembersFilters filterSet = new x7sMembersFilters();
			System.assertNotEquals(null, filterSet, filterSetNull);

			List<X7S_Members_Filter_Entry__c> entries = filterSet.getFilterEntries(filterSet.filters[0]);
			System.assertNotEquals(null, entries, 'entries is null');
		} catch (Exception e) {
			System.debug(e.getMessage());
		}
		Test.stopTest();
	}
}