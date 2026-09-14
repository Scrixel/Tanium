/**
 * @Business: Controller class for the LoggedInUserApprovalQueue page
 * @Date: 2016-07-02
 * @Author: Cumulus Vision
 * Modified    ModifiedDate    Description
 *  TAN-613     2016-07-07      Initial Development
 */
public class LoggedInUserApprovalQueueController {
	public class ActionResult {
		public Boolean isSuccess;
		public String error;
		public Object data;

		public ActionResult() {
		}

		private void initialize() {
			isSuccess = false;
		}

		public void setSuccessResult(Map<String, Object> mapData) {
			initialize();
			isSuccess = true;
			data = mapData;
		}

		public void setErrorResult(String errorMessage, Map<String, String> mapErrorDetail) {
			initialize();
			isSuccess = false;
			error = errorMessage;
			data = mapErrorDetail;
		}

		public void setErrorResult(Exception ex) {
			isSuccess = false;
			error = ex.getMessage();
			data = new Map<String, Object>{ 'exception' => ex.getStackTraceString() };
		}
	}

	public class ObjectPendingApprovals {
		public String sObjectName;
		public String sObjectLabel;
		public String nameField;
		public Map<String, String> mapFieldNameToLabel;
		public Map<String, String> mapApprovalProcessNameToLabel;
		public Map<String, List<PendingApprovalRequest>> mapApprovalProcessDevNameToApprovalRequests;

		public ObjectPendingApprovals(
			String tableName,
			String tableLabel,
			String sObjNameField,
			Map<String, String> mapSObjectFieldNameToLabel
		) {
			sObjectName = tableName;
			sObjectLabel = tableLabel;
			nameField = sObjNameField;
			mapFieldNameToLabel = mapSObjectFieldNameToLabel;
			mapApprovalProcessNameToLabel = new Map<String, String>();
			mapApprovalProcessDevNameToApprovalRequests = new Map<String, List<PendingApprovalRequest>>();
		}

		public void splitPendingApprovalsByApprovalProcess(
			List<ProcessInstanceWorkitem> listPIWI,
			List<SObject> listSObject
		) {
			Map<Id, SObject> mapSObject = new Map<Id, SObject>(listSObject);
			for (ProcessInstanceWorkitem piwi : listPIWI) {
				String processDevName = piwi.ProcessInstance.ProcessDefinition.DeveloperName;
				if (!mapApprovalProcessDevNameToApprovalRequests.containsKey(processDevName)) {
					mapApprovalProcessDevNameToApprovalRequests.put(
						processDevName,
						new List<PendingApprovalRequest>()
					);
				}

				if (!mapApprovalProcessNameToLabel.containsKey(processDevName)) {
					mapApprovalProcessNameToLabel.put(
						processDevName,
						piwi.ProcessInstance.ProcessDefinition.Name
					);
				}

				Id pendingApprovalReqId = piwi.ProcessInstanceId;
				Id approvalSObjectId = piwi.ProcessInstance.TargetObjectId;
				Id userId = piwi.ActorId;
				SObject record = mapSObject.get(approvalSObjectId);
				mapApprovalProcessDevNameToApprovalRequests.get(processDevName)
					.add(
						new PendingApprovalRequest(
							pendingApprovalReqId,
							piwi.Id,
							approvalSObjectId,
							userId,
							record
						)
					);
			}
		}
	}

	public class PendingApprovalRequest {
		public Id Id;
		public Id requestStepId;
		public Id approvalRecordId;
		public Id approverId;
		public SObject record;

		public PendingApprovalRequest(
			Id pendingApprovalReqId,
			Id processInstanceWorkitem,
			Id approvalSObjectId,
			Id userId,
			SObject sObjRecord
		) {
			Id = pendingApprovalReqId;
			requestStepId = processInstanceWorkitem;
			approvalRecordId = approvalSObjectId;
			approverId = userId;
			record = sObjRecord;
		}
	}

	@RemoteAction
	public static ActionResult getApprovalItemsForLoggedInUser() {
		ActionResult result = new ActionResult();
		Map<String, String> mapObjectNameToNameField = new Map<String, String>{
			'SBQQ__Quote__c'.toLowerCase() => 'Name',
			'Budget__c'.toLowerCase() => 'Name'
		};

		Map<String, Map<String, String>> mapObjectNameToFieldsInfo = new Map<String, Map<String, String>>{
			'SBQQ__Quote__c'.toLowerCase() => getSBPPQuoteFieldNameToLabel(),
			'Budget__c'.toLowerCase() => getBudgetFieldNameToLabel()
		};

		try {
			// Todo: need to remove following hard-coded Id.
			Id loggedInUserId = UserInfo.getUserId();
			List<ProcessInstanceWorkitem> listPendingApproval = fetchPendingApprovals(
				loggedInUserId,
				mapObjectNameToFieldsInfo.keySet()
			);

			List<ObjectPendingApprovals> listObjectPendingApprovals = splitPendingApprovals(
				listPendingApproval,
				mapObjectNameToNameField,
				mapObjectNameToFieldsInfo
			);

			Map<String, Object> mapData = new Map<String, Object>{
				'objectPendingApprovals' => listObjectPendingApprovals
			};
			result.setSuccessResult(mapData);
		} catch (Exception ex) {
			result.setErrorResult(ex);
		}
		return result;
	}

	private static List<ProcessInstanceWorkitem> fetchPendingApprovals(
		Id approverId,
		Set<String> setObjectName
	) {
		final String PROCESS_INSTANCE_APPROVAL_TYPE = 'Approval';
		List<ProcessInstanceWorkitem> listPendingApproval = [
			SELECT
				Id,
				ProcessInstanceId,
				ActorId,
				ProcessInstance.TargetObjectId,
				ProcessInstance.ProcessDefinition.DeveloperName,
				ProcessInstance.ProcessDefinition.Name,
				ProcessInstance.ProcessDefinition.TableEnumOrId
			FROM ProcessInstanceWorkitem
			WHERE
				ActorId = :approverId
				AND ProcessInstance.ProcessDefinition.TableEnumOrId IN :setObjectName
				AND ProcessInstance.ProcessDefinition.Type = :PROCESS_INSTANCE_APPROVAL_TYPE
		];

		return listPendingApproval;
	}

	private static List<ObjectPendingApprovals> splitPendingApprovals(
		List<ProcessInstanceWorkitem> listPendingApproval,
		Map<String, String> mapObjectNameToNameField,
		Map<String, Map<String, String>> mapObjectNameToFieldsInfo
	) {
		List<ObjectPendingApprovals> listObjectPendingApprovals = new List<ObjectPendingApprovals>();
		Map<String, List<ProcessInstanceWorkitem>> mapObjectNameToPendingPIWI = new Map<String, List<ProcessInstanceWorkitem>>();

		Map<String, Set<Id>> mapObjectNameToRecordId = new Map<String, Set<Id>>();

		// Group "Pending Approval Request" by "sObject Name"
		for (ProcessInstanceWorkitem piwi : listPendingApproval) {
			String tableName = piwi.ProcessInstance.ProcessDefinition.TableEnumOrId.toLowerCase();

			if (!mapObjectNameToPendingPIWI.containsKey(tableName)) {
				mapObjectNameToPendingPIWI.put(tableName, new List<ProcessInstanceWorkitem>());
			}
			mapObjectNameToPendingPIWI.get(tableName).add(piwi);

			Set<Id> setRecordId = new Set<Id>();

			if (!mapObjectNameToRecordId.containsKey(tableName)) {
				mapObjectNameToRecordId.put(tableName, new Set<Id>());
			}
			mapObjectNameToRecordId.get(tableName).add(piwi.ProcessInstance.TargetObjectId);
		}

		Map<String, List<SObject>> mapObjectToSObjectRecords = new Map<String, List<SObject>>();
		for (String objectName : mapObjectNameToFieldsInfo.keySet()) {
			if (!mapObjectNameToRecordId.containsKey(objectName)) {
				continue;
			}

			Set<String> setQueryField = new Set<String>();
			for (String fieldName : mapObjectNameToFieldsInfo.get(objectName).keySet()) {
				setQueryField.add(fieldName.toLowerCase());
			}
			setQueryField.add(mapObjectNameToNameField.get(objectName).toLowerCase());
			List<String> listQueryField = new List<String>(setQueryField);

			Set<Id> setRecordId = mapObjectNameToRecordId.get(objectName);
			String[] queryFillers = new List<String>{ String.join(listQueryField, ','), objectName };
			String query = String.format('SELECT {0} FROM {1} WHERE Id IN :setRecordId', queryFillers);
			System.debug('\n query:' + query);

			mapObjectToSObjectRecords.put(objectName, Database.query(query));
		}

		// Convert above map to wrapper class structer
		for (String objectName : mapObjectNameToPendingPIWI.keySet()) {
			Map<String, String> mapFieldNameToLabel = mapObjectNameToFieldsInfo.get(objectName);
			String objectNameField = mapObjectNameToNameField.get(objectName);
			String sObjectLabel = getSObjectLabel(objectName);
			ObjectPendingApprovals newObjectPendingApprovals = new ObjectPendingApprovals(
				objectName,
				sObjectLabel,
				objectNameField,
				mapFieldNameToLabel
			);

			newObjectPendingApprovals.splitPendingApprovalsByApprovalProcess(
				mapObjectNameToPendingPIWI.get(objectName),
				mapObjectToSObjectRecords.get(objectName)
			);
			listObjectPendingApprovals.add(newObjectPendingApprovals);
		}

		return listObjectPendingApprovals;
	}

	private static Map<String, String> getSBPPQuoteFieldNameToLabel() {
		return new Map<String, String>{
			'Name' => 'Quote Name',
			'SBQQ__Account__r.Name' => 'Account Name',
			'SBQQ__Opportunity2__r.Name' => 'Opportunity Name',
			'SBQQ__NetAmount__c' => 'Quote Amount',
			'SBQQ__Introduction__c' => 'Quote Description'
		};
	}

	private static Map<String, String> getBudgetFieldNameToLabel() {
		return new Map<String, String>{
			'Name' => 'Budget Name',
			'Program_Name__c' => 'Program Name',
			'Requestor__r.Name' => 'Requestor Name',
			'Business_Department__c' => 'Business Department',
			'Budget_Amount__c' => 'Budget Amount'
		};
	}

	private static String getSObjectLabel(String sObjectName) {
		String sObjectLabel;
		if (String.isNotBlank(sObjectName)) {
			Map<String, Schema.SObjectType> mapSObjectNameToSObjectType = Schema.getGlobalDescribe();

			if (mapSObjectNameToSObjectType.containsKey(sObjectName)) {
				Schema.DescribeSObjectResult dsr = mapSObjectNameToSObjectType.get(sObjectName)
					.getDescribe();
				sObjectLabel = dsr.label;
			}
		}
		return sObjectLabel;
	}
}