/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Custom Metadata Saver
 * @Date: 2026-03-30
 * @Authors: Tanium Dev Team
 * RequestId   ModifiedDate  Description
 * SS-12915    2026-03-30    Class Created
 */

public inherited sharing class CustomMetadataSaver {
	@TestVisible
	private static final String MOCK_DEPLOYMENT_ID = 'fakeDeploymentId';

	@TestVisible
	private static final Set<String> IGNORED_FIELD_NAMES = new Set<String>{
		'DeveloperName',
		'Id',
		'Label',
		'Language',
		'MasterLabel',
		'NamespacePrefix',
		'QualifiedApiName'
	};

	public class FlowActionException extends Exception {
	}

	public class FlowInput {
		@InvocableVariable(required=true label='Custom Metadata Type Records to Deploy')
		public List<SObject> customMetadataRecords;
	}

	private CustomMetadataSaver() {
	}

	@InvocableMethod(
		category='Custom Metadata'
		label='Deploy Custom Metadata Type Records'
		description='Deploys changes to the list of custom metadata records (create and update)'
	)
	public static List<String> createCustomMetadataRecords(List<FlowInput> inputs) {
		List<SObject> allCustomMetadataRecords = new List<SObject>();
		for (FlowInput input : inputs) {
			if (input?.customMetadataRecords != null) {
				allCustomMetadataRecords.addAll(input.customMetadataRecords);
			}
		}

		Metadata.DeployCallback callback = new DefaultDeployCallback();
		String jobId = createCustomMetadataRecords(allCustomMetadataRecords, callback);

		List<String> flowJobIds = new List<String>();
		for (Integer i = 0; i < inputs.size(); i++) {
			flowJobIds.add(jobId);
		}
		return flowJobIds;
	}

	public static String createCustomMetadataRecords(List<SObject> customMetadataRecords) {
		return createCustomMetadataRecords(customMetadataRecords, new DefaultDeployCallback());
	}

	public static String createCustomMetadataRecords(
		List<SObject> customMetadataRecords,
		Metadata.DeployCallback callback
	) {
		Metadata.DeployContainer deployment = new Metadata.DeployContainer();

		for (SObject customMetadataRecord : customMetadataRecords) {
			if (customMetadataRecord != null) {
				Metadata.CustomMetadata cmdt = createDeployableCustomMetadata(customMetadataRecord);
				deployment.addMetadata(cmdt);
			}
		}

		String jobId = Test.isRunningTest()
			? MOCK_DEPLOYMENT_ID
			: Metadata.Operations.enqueueDeployment(deployment, callback);

		return jobId;
	}

	@TestVisible
	private static Metadata.CustomMetadata createDeployableCustomMetadata(
		SObject customMetadataRecord
	) {
		String objectApiName = customMetadataRecord.getSObjectType().getDescribe().getName();
		if (String.isBlank(objectApiName) || !objectApiName.endsWith('__mdt')) {
			throw new FlowActionException('Input SObject must be a custom metadata type (__mdt).');
		}

		Map<String, Schema.SObjectField> fieldsByApiName = customMetadataRecord
			.getSObjectType()
			.getDescribe()
			.fields.getMap();

		String developerName = fieldsByApiName.containsKey('DeveloperName')
			? (String) customMetadataRecord.get('DeveloperName')
			: null;
		Schema.SObjectField field;
		Object value;

		String label = fieldsByApiName.containsKey('MasterLabel')
			? (String) customMetadataRecord.get('MasterLabel')
			: null;
		if (String.isBlank(label) && fieldsByApiName.containsKey('Label')) {
			label = (String) customMetadataRecord.get('Label');
		}

		if (String.isBlank(developerName)) {
			if (String.isBlank(label)) {
				throw new FlowActionException(
					'Provide MasterLabel/Label for create or DeveloperName for update.'
				);
			}
			developerName = label.replaceAll(' ', '_');
		}

		if (String.isBlank(label)) {
			label = developerName;
		}

		String customMetadataTypePrefix = objectApiName.replace('__mdt', '');

		Metadata.CustomMetadata cmdt = new Metadata.CustomMetadata();
		cmdt.fullName = customMetadataTypePrefix + '.' + developerName;
		cmdt.label = label;
		cmdt.values = new List<Metadata.CustomMetadataValue>();

		Map<String, Object> populatedFields = customMetadataRecord.getPopulatedFieldsAsMap();
		for (String fieldName : populatedFields.keySet()) {
			field = null;
			if (!IGNORED_FIELD_NAMES.contains(fieldName)) {
				field = fieldsByApiName.get(fieldName);
			}

			if (field != null) {
				Schema.DisplayType displayType = field.getDescribe().getType();
				if (
					displayType == Schema.DisplayType.PICKLIST ||
					displayType == Schema.DisplayType.MULTIPICKLIST
				) {
					value = String.valueOf(populatedFields.get(fieldName));
				} else {
					value = populatedFields.get(fieldName);
				}

				Metadata.CustomMetadataValue cmdtValue = new Metadata.CustomMetadataValue();
				cmdtValue.field = fieldName;
				cmdtValue.value = value;
				cmdt.values.add(cmdtValue);
			}
		}

		return cmdt;
	}

	public class DefaultDeployCallback implements Metadata.DeployCallback {
		@TestVisible
		private Boolean success;

		@TestVisible
		private Integer numberComponentsTotal;

		@TestVisible
		private Integer numberComponentErrors;

		public void handleResult(
			Metadata.DeployResult result,
			Metadata.DeployCallbackContext context
		) {
			this.success = result?.success;
			this.numberComponentsTotal = result?.numberComponentsTotal;
			this.numberComponentErrors = result?.numberComponentErrors;
		}
	}
}