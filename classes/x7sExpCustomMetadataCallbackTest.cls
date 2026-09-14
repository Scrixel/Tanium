/*
 * Copyright (c) 2020. 7Summits Inc.
 */

@IsTest
public with sharing class x7sExpCustomMetadataCallbackTest {
	@IsTest
	public static void testCustomMetadataCallback() {
		x7sExpCustomMetadataCallback testCallback = new x7sExpCustomMetadataCallback();

		// Test result
		Metadata.DeployResult testResult = new Metadata.DeployResult();
		testResult.success = false;
		testResult.status = Metadata.DeployStatus.Failed;

		testResult.details = new Metadata.DeployDetails();
		Metadata.DeployMessage deployMsg = new Metadata.DeployMessage();
		deployMsg.fullName = 'Test FullName';
		deployMsg.success = false;
		testResult.details.componentFailures = new List<Metadata.DeployMessage>{ deployMsg };

		// Test context
		Metadata.DeployCallbackContext testContext = new Metadata.DeployCallbackContext();

		// First, test failure
		testCallback.handleResult(testResult, testContext);

		// Now, test success
		testResult.success = true;
		testResult.status = Metadata.DeployStatus.Succeeded;
		System.assertNotEquals(null, testResult);
		testCallback.handleResult(testResult, testContext);
	}
}