/*
 * Licensed Materials - Property of IBM
 * 6949-83K
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
private class x7sMembersFilterBatch_Test {
	// Can only be called once
	@IsTest
	public static void testFilterBatch() {
		Test.startTest();

		x7sMembersFilters filterSet = new x7sMembersFilters();

		x7sMembersFilterBatch filterBatch = new x7sMembersFilterBatch(
			filterSet.filters[0].DeveloperName
		);
		System.debug('testFilterBatch with ' + filterBatch.fieldName);

		Id batchProcessId = Database.executeBatch(filterBatch);
		System.assertNotEquals(null, batchProcessId);

		Test.stopTest();
	}
}