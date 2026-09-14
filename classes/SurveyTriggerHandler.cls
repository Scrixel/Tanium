public class SurveyTriggerHandler extends TriggerHandler {

	public List<Survey__c> listOldSurveys { get; set; }
	public List<Survey__c> listNewSurveys { get; set; }

	public Survey__c oldSurvey { get; set; }
	public Survey__c newSurvey { get; set; }

	public SurveyTriggerHandler() {
		this.listOldSurveys = (List<Survey__c>) Trigger.old;
		this.listNewSurveys = (List<Survey__c>) Trigger.new;

		if(listOldSurveys != null){
			oldSurvey = listOldSurveys[0];
		}

		if(listNewSurveys != null){
			newSurvey = listNewSurveys[0];
		}				

	}

	public override void beforeInsert() {
		//
		RoscoSurveyProcesses.processSurvey(listNewSurveys);

	}

	//public override void beforeUpdate() {
	//}

	public override void afterInsert() {

		RoscoSurveyProcesses.processRoscoAccountUpdate(listNewSurveys);
		RoscoSurveyProcesses.sendAlert(listNewSurveys);

	}

	//public override void afterUpdate() {
	//}

	
}