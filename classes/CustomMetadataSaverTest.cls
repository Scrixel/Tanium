/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Custom Metadata Saver Test
 * @Date: 2026-03-30
 * @Authors: Tanium Dev Team
 * RequestId   ModifiedDate  Description
 * SS-12915    2026-03-30    Class Created
 */

@IsTest
private class CustomMetadataSaverTest {
	private static String getAnyCmdtObjectApiName() {
		Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
		for (String name : globalDescribe.keySet()) {
			if (name == null || !name.endsWith('__mdt')) {
				continue;
			}
			Schema.SObjectType sobjectType = globalDescribe.get(name);
			if (sobjectType == null) {
				continue;
			}
			for (Schema.SObjectField fieldToken : sobjectType.getDescribe().fields.getMap().values()) {
				Schema.DisplayType t = fieldToken.getDescribe().getType();
				if (t == Schema.DisplayType.PICKLIST || t == Schema.DisplayType.MULTIPICKLIST) {
					return name;
				}
			}
		}
		return null;
	}

	private static SObject newCmdtRecord(String cmdtObjectApiName) {
		SObjectType sobjectType = Schema.getGlobalDescribe().get(cmdtObjectApiName);
		SObject record = sobjectType.newSObject();
		record.put('DeveloperName', 'Test_Record_' + System.now().getTime());
		record.put('MasterLabel', 'Test Record');
		return record;
	}

	private static SObject newCmdtCreateRecord(String cmdtObjectApiName, String label) {
		SObjectType sobjectType = Schema.getGlobalDescribe().get(cmdtObjectApiName);
		SObject record = sobjectType.newSObject();
		record.put('MasterLabel', label);
		return record;
	}

	@IsTest
	static void testDeploy_returnsMockJobId_inTests() {
		String cmdtObjectApiName = getAnyCmdtObjectApiName();
		Assert.areNotEqual(
			null,
			cmdtObjectApiName,
			'Expected at least one __mdt type in the org to run this test.'
		);
		SObject record = newCmdtRecord(cmdtObjectApiName);

		Test.startTest();
		String jobId = CustomMetadataSaver.createCustomMetadataRecords(new List<SObject>{ record });
		Test.stopTest();

		Assert.areEqual('fakeDeploymentId', jobId);
	}

	@IsTest
	static void testDeploy_returnsOneJobIdPerInput() {
		String cmdtObjectApiName = getAnyCmdtObjectApiName();
		Assert.areNotEqual(
			null,
			cmdtObjectApiName,
			'Expected at least one __mdt type in the org to run this test.'
		);

		CustomMetadataSaver.FlowInput in1 = new CustomMetadataSaver.FlowInput();
		in1.customMetadataRecords = new List<SObject>{ newCmdtRecord(cmdtObjectApiName) };

		CustomMetadataSaver.FlowInput in2 = new CustomMetadataSaver.FlowInput();
		in2.customMetadataRecords = new List<SObject>{ newCmdtRecord(cmdtObjectApiName) };

		Test.startTest();
		List<String> jobIds = CustomMetadataSaver.createCustomMetadataRecords(
			new List<CustomMetadataSaver.FlowInput>{ in1, in2 }
		);
		Test.stopTest();

		Assert.areEqual(2, jobIds.size());
		Assert.areEqual('fakeDeploymentId', jobIds[0]);
		Assert.areEqual('fakeDeploymentId', jobIds[1]);
	}

	@IsTest
	static void testDeploy_throws_whenInputIsNotCustomMetadataType() {
		Account record = new Account(Name = 'Not CMDT');

		try {
			Test.startTest();
			CustomMetadataSaver.createCustomMetadataRecords(new List<SObject>{ record });
			Test.stopTest();
			Assert.fail('Expected createCustomMetadataRecords() to throw for non-__mdt input');
		} catch (CustomMetadataSaver.FlowActionException ex) {
			Assert.isTrue(
				ex.getMessage().contains('__mdt'),
				'Expected error message to mention __mdt requirement'
			);
		}
	}

	@IsTest
	static void testCreateDeployableCustomMetadata_derivesDeveloperNameFromLabel_whenBlank() {
		String cmdtObjectApiName = getAnyCmdtObjectApiName();
		Assert.areNotEqual(
			null,
			cmdtObjectApiName,
			'Expected at least one __mdt type in the org to run this test.'
		);

		SObject record = newCmdtCreateRecord(cmdtObjectApiName, 'Test Label');
		Metadata.CustomMetadata cmdt = CustomMetadataSaver.createDeployableCustomMetadata(record);

		Assert.areEqual('Test Label', cmdt.label);
		Assert.areEqual(
			(cmdtObjectApiName.replace('__mdt', '') + '.Test_Label').toLowerCase(),
			cmdt.fullName?.toLowerCase()
		);
	}

	@IsTest
	static void testCreateDeployableCustomMetadata_throws_whenLabelAndDeveloperNameMissing() {
		String cmdtObjectApiName = getAnyCmdtObjectApiName();
		Assert.areNotEqual(
			null,
			cmdtObjectApiName,
			'Expected at least one __mdt type in the org to run this test.'
		);

		SObjectType sobjectType = Schema.getGlobalDescribe().get(cmdtObjectApiName);
		SObject record = sobjectType.newSObject();

		try {
			CustomMetadataSaver.createDeployableCustomMetadata(record);
			Assert.fail('Expected createDeployableCustomMetadata() to throw');
		} catch (CustomMetadataSaver.FlowActionException ex) {
			Assert.isTrue(
				ex.getMessage().contains('MasterLabel') ||
					ex.getMessage().contains('Label') ||
					ex.getMessage().contains('DeveloperName'),
				'Expected error message to describe required fields'
			);
		}
	}

	@IsTest
	static void testDefaultDeployCallback_setsSuccessTrue_whenDeploySucceeds() {
		CustomMetadataSaver.DefaultDeployCallback callback = new CustomMetadataSaver.DefaultDeployCallback();
		Assert.areEqual(null, callback.success);

		Metadata.DeployResult result = new Metadata.DeployResult();
		result.success = true;
		result.numberComponentsTotal = 5;
		result.numberComponentErrors = 0;

		Metadata.DeployCallbackContext context = new Metadata.DeployCallbackContext();

		Test.startTest();
		callback.handleResult(result, context);
		Test.stopTest();

		Assert.areEqual(true, callback.success);
		Assert.areEqual(5, callback.numberComponentsTotal);
		Assert.areEqual(0, callback.numberComponentErrors);
	}

	@IsTest
	static void testDefaultDeployCallback_setsSuccessFalse_whenDeployFails() {
		CustomMetadataSaver.DefaultDeployCallback callback = new CustomMetadataSaver.DefaultDeployCallback();
		Assert.areEqual(null, callback.success);

		Metadata.DeployResult result = new Metadata.DeployResult();
		result.success = false;
		result.numberComponentsTotal = 5;
		result.numberComponentErrors = 2;

		Metadata.DeployCallbackContext context = new Metadata.DeployCallbackContext();

		Test.startTest();
		callback.handleResult(result, context);
		Test.stopTest();

		Assert.areEqual(false, callback.success);
		Assert.areEqual(5, callback.numberComponentsTotal);
		Assert.areEqual(2, callback.numberComponentErrors);
	}
}