public with sharing class APTS_DynamicChevronController {
	public String longLabelJSON { get; set; }
	public String shortLabelJSON { get; set; }

	@TestVisible
	private static final Map<String, String> objectPicklistFieldMap = new Map<String, String>{
		'Apttus__APTS_Agreement__c' => 'Apttus__Status_Category__c',
		'Opportunity' => 'StageName'
	};

	public APTS_DynamicChevronController(ApexPages.StandardController controller) {
		List<String> longLabelList = generateLongLabels(controller.getId());
		List<String> shortLabelList = generateShortLabels(longLabelList);

		longLabelJSON = JSON.serialize(longLabelList);
		shortLabelJSON = JSON.serialize(shortLabelList);
	}

	@TestVisible
	private static List<String> generateLongLabels(Id recordId) {
		List<String> longLabels = new List<String>();
		Schema.DescribeSObjectResult objectDescribe = recordId.getSobjectType().getDescribe();
		String fieldName = objectPicklistFieldMap.get(objectDescribe.getName());

		if (fieldName != null) {
			List<Schema.PicklistEntry> picklistEntries = objectDescribe.fields.getMap()
				.get(fieldName)
				.getDescribe()
				.getPickListValues();

			for (Schema.PicklistEntry picklistEntry : picklistEntries) {
				longLabels.add(picklistEntry.getLabel());
			}
		}

		return longLabels;
	}

	@TestVisible
	private static List<String> generateShortLabels(List<String> longLabels) {
		List<String> shortLabels = new List<String>();

		for (String longLabel : longLabels) {
			String shortLabel = '';
			List<String> splitLabel = longLabel.trim().split('\\s+'); //Regular expression for any number of spaces

			if (!splitLabel.isEmpty()) {
				shortLabel = splitLabel[0].subString(0, 1).toUpperCase();
				if (splitLabel.size() > 1) {
					shortLabel += splitLabel[1].subString(0, 1).toUpperCase();
				}
			}
			shortLabels.add(shortLabel);
		}

		return shortLabels;
	}
}