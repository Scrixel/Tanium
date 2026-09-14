/**
 * @Business: Controller class for the LTNG component - CustomerCommunityTermsAndConditions
 * @Date: 2019-05-27
 * @Author: Cumulus Vision
 * Modified    ModifiedDate    Description
 * TAN-773     2019-05-28      Initial Development
 * TAN-809     2019-09-10      Added logic to create the CollaborationGroupMemberRequest record.
 * TAN-1024    2020-12-10      Changed group name in query from Tanium EDR Discussion Group to reflect name change
 * TAN-1173    2021-03-05      remove contact update -- this is a spring 21 issue as well Tanium isn't approving group requests via contact any longer.
 * TAN-1076    2021-01-21      removed hardcoded group name using custom setting
 * SS-7294     2024-03-06      Use final variables for hardcoded values, move the checking of existing community user
 */
public class CustomerCommunityTermsConditionsCntrl {
	@TestVisible
	private static final String SUCCESS_MESSAGE = 'Information successfully updated';
	@TestVisible
	private static final String INVALID_USER_MESSAGE = 'Not valid Community User for this operation.';

	public class ActionResult {
		@AuraEnabled
		public Boolean isSuccess;

		@AuraEnabled
		public String error;

		@AuraEnabled
		public Object data;

		public void setSucess(Map<String, Object> mapData) {
			isSuccess = true;
			data = mapData;
		}

		public void setFailure(Exception ex) {
			isSuccess = false;
			error = ex.getMessage();
			data = new Map<String, Object>{ 'exception' => ex.getStackTraceString() };
		}

		public void setFailure(String errorMessage) {
			isSuccess = false;
			error = errorMessage;
		}
	}

	@AuraEnabled
	public static ActionResult updateCommunityContact(Id communityUserId) {
		ActionResult result = new ActionResult();
		Automation_Management__c automationManagement = Automation_Management__c.getOrgDefaults();

		try {
			List<User> listUser = [SELECT Id, ContactId FROM User WHERE Id = :communityUserId];

			if (listUser.isEmpty() || String.isBlank(listUser[0].ContactId)) {
				result.setFailure(INVALID_USER_MESSAGE);
				return result;
			}

			List<CollaborationGroup> listEDRGroup = [
				SELECT Id, Name
				FROM CollaborationGroup
				WHERE Id = :automationManagement.EDR_Community_Group_Id__c
			];

			Database.SaveResult cgmrSaveResult;
			if (!listEDRGroup.isEmpty()) {
				Integer existingRequestCount = [
					SELECT COUNT()
					FROM CollaborationGroupMemberRequest
					WHERE CollaborationGroupId = :listEDRGroup[0].Id AND RequesterId = :communityUserId
				];
				if (existingRequestCount == 0) {
					CollaborationGroupMemberRequest cgmr = new CollaborationGroupMemberRequest(
						CollaborationGroupId = listEDRGroup[0].Id,
						RequesterId = communityUserId
					);
					cgmrSaveResult = Database.insert(cgmr, false);
				}
			}

			List<String> listError = new List<String>();

			if (cgmrSaveResult != null && !cgmrSaveResult.success) {
				listError.add(cgmrSaveResult.errors[0].message);
			}

			if (listError.isEmpty()) {
				Map<String, String> mapData = new Map<String, String>();
				mapData.put('message', SUCCESS_MESSAGE);
				result.setSucess(mapData);
			} else {
				result.setFailure(String.join(listError, ','));
			}
		} catch (Exception ex) {
			result.setFailure(ex);
		}
		return result;
	}

	@AuraEnabled
	public static ActionResult updateCommunityContactEndpointDiscussion(Id communityUserId) {
		ActionResult result = new ActionResult();
		Automation_Management__c automationManagement = Automation_Management__c.getOrgDefaults();

		try {
			List<User> listUser = [SELECT Id, ContactId FROM User WHERE Id = :communityUserId];

			if (listUser.isEmpty() || String.isBlank(listUser[0].ContactId)) {
				result.setFailure(INVALID_USER_MESSAGE);
				return result;
			}

			List<CollaborationGroup> listEDRGroup = [
				SELECT Id, Name
				FROM CollaborationGroup
				WHERE Id = :automationManagement.Tanium_Endpoint_Management_Group__c
			];

			Database.SaveResult cgmrSaveResult;
			if (!listEDRGroup.isEmpty()) {
				Integer existingRequestCount = [
					SELECT COUNT()
					FROM CollaborationGroupMemberRequest
					WHERE CollaborationGroupId = :listEDRGroup[0].Id AND RequesterId = :communityUserId
				];
				if (existingRequestCount == 0) {
					CollaborationGroupMemberRequest cgmr = new CollaborationGroupMemberRequest(
						CollaborationGroupId = listEDRGroup[0].Id,
						RequesterId = communityUserId
					);
					cgmrSaveResult = Database.insert(cgmr, false);
				}
			}

			List<String> listError = new List<String>();

			if (cgmrSaveResult != null && !cgmrSaveResult.success) {
				listError.add(cgmrSaveResult.errors[0].message);
			}

			if (listError.isEmpty()) {
				Map<String, String> mapData = new Map<String, String>();
				mapData.put('message', SUCCESS_MESSAGE);
				result.setSucess(mapData);
			} else {
				result.setFailure(String.join(listError, ','));
			}
		} catch (Exception ex) {
			result.setFailure(ex);
		}
		return result;
	}
}