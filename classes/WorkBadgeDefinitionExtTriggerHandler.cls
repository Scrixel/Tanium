/*
 * @DATE: 2024-09-06
 * @AUTHOR: Tanium Dev Team
 * @BUSINESS: Trigger Handler for the WorkBadgeDefinitionExtensionTrigger  class.
 * Modified	  ModifiedDate    Comment
 * SS-8303    2024-09-06    Assign points to badges
 */
public with sharing class WorkBadgeDefinitionExtTriggerHandler extends TriggerHandler {
	public List<WorkBadgeDefinitionExtension__c> workBadgeDefinitionExtensions { get; set; }
	public Map<Id, WorkBadgeDefinitionExtension__c> oldMap { get; set; }

	public WorkBadgeDefinitionExtTriggerHandler() {
		super('WorkBadgeDefinitionExtTriggerHandler');
		this.workBadgeDefinitionExtensions = (List<WorkBadgeDefinitionExtension__c>) Trigger.new;
		this.oldMap = (Map<Id, WorkBadgeDefinitionExtension__c>) Trigger.oldMap;
	}

	public override void beforeInsert() {
		WorkBadgeDefinitionExtTriggerUtility.validateBadges(workBadgeDefinitionExtensions, oldMap);
		WorkBadgeDefinitionExtTriggerUtility.validateDuplicateBadgeDefinition(
			workBadgeDefinitionExtensions
		);
		WorkBadgeDefinitionExtTriggerUtility.setSourceId(workBadgeDefinitionExtensions);
	}

	public override void beforeUpdate() {
		WorkBadgeDefinitionExtTriggerUtility.validateBadges(workBadgeDefinitionExtensions, oldMap);
	}
}