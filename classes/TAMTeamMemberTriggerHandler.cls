/*
 * @DATE: 2020-05-12
 * @AUTHOR: Shared Services (jason.johnson)
 * @REQUEST: 
 * @BUSINESS: Trigger Handler for the TAM_Team_Member__c class.
 * RequestId       ModifiedDate    Comment
 * SCLOUD-         2020-05-12      Initial Development
 */
public class TAMTeamMemberTriggerHandler extends TriggerHandler {

	public List<TAM_Team_Member__c> listOldMembers { get; set; }
	public List<TAM_Team_Member__c> listNewMembers { get; set; }

	public TAM_Team_Member__c oldMember { get; set; }
	public TAM_Team_Member__c newMember { get; set; }

	public TAMTeamMemberTriggerHandler() {
		this.listOldMembers = (List<TAM_Team_Member__c>) Trigger.old;
		this.listNewMembers = (List<TAM_Team_Member__c>) Trigger.new;

		if(listOldMembers != null){
			oldMember = listOldMembers[0];
		}

		if(listNewMembers != null){
			newMember = listNewMembers[0];
		}				

	}

	public override void afterDelete() {

        System.debug('oldMember:' + JSON.serializePretty(oldMember, true));
        System.debug('newMember:' + JSON.serializePretty(newMember, true));
        RoscoEscalate.removeSMEFromAllCases(oldMember.TAM__c);
	
	}

}