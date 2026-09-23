/**
 * @Business: APEX Controller class for SDRMappingEdit VF Page
 * @Date: 2019-08-08
 * @Author: Cumulus Vision
 * @Request: TAN-796
 * Modified  ModifiedDate   Description
 * TAN-796   2019-08-08     Initial development
 * TAN-799   2019-08-13     Feedback Changes dt. 08/12/2019, Removed "required=true" on State_Province__c field, Added manual validation instead
 * TAN-803   2019-09-06     Removed validation that made State mandatory if Country was 'US' or 'Canada'.
 */

public class SDRMappingEditController {
	public SDR_Mapping__c sdrMapping { get; set; }
	private Map<Id, Group> mapQueue;

	public SDRMappingEditController(ApexPages.StandardController stdCon) {
		sdrMapping = (SDR_Mapping__c) stdCon.getRecord();

		if (sdrMapping.Id != null) {
			sdrMapping = [
				SELECT Id, Country__c, State_Province__c, SDR_Owner__c, Queue_ID__c, Queue_Name__c
				FROM SDR_Mapping__c
				WHERE Id = :sdrMapping.Id
			];
		}
	}

	public List<SelectOption> getQueues() {
		List<SelectOption> listOption = new List<SelectOption>();

		mapQueue = new Map<Id, Group>(
			[
				SELECT
					Id,
					Name,
					Type,
					(SELECT Id, SobjectType FROM QueueSobjects WHERE SobjectType = 'Lead')
				FROM Group
				WHERE Type = 'Queue'
			]
		);
		listOption.add(new SelectOption('NOPE', '--None--'));
		for (Group queue : mapQueue.values()) {
			if (!queue.QueueSobjects.isEmpty()) {
				listOption.add(new SelectOption(queue.Id, queue.Name));
			}
		}

		return listOption;
	}

	public PageReference save() {
		PageReference pageRef = null;

		try {
			// Validate State_Province__c if Country is UnitedStates or Canada
			// String country = sdrMapping.Country__c;
			// if ((country.equalsIgnoreCase('United States') || country.equalsIgnoreCase('Canada')) && String.isBlank(sdrMapping.State_Province__c)) {
			//     ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Please select valid State if Country is "United State" or "Canada"'));
			//     return pageRef;
			// }

			// Get Queue Name
			if (sdrMapping.Queue_ID__c == 'NOPE') {
				sdrMapping.Queue_Name__c = null;
			} else {
				sdrMapping.Queue_Name__c = mapQueue.get(sdrMapping.Queue_ID__c).Name;
			}

			// Save SDR Mapping Record
			upsert sdrMapping;

			// Redirect to SDR Mapping Record
			pageRef = new PageReference('/' + sdrMapping.Id);
		} catch (Exception ex) {
			ApexPages.addMessage(
				new ApexPages.Message(ApexPages.Severity.ERROR, 'Exception: ' + ex.getMessage())
			);
		}

		return pageRef;
	}

	public PageReference cancel() {
		Schema.DescribeSObjectResult result = SDR_Mapping__c.SObjectType.getDescribe();
		PageReference pageRef = new PageReference('/' + result.getKeyPrefix());
		return pageRef;
	}
}