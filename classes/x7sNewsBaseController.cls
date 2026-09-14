/*
 * Licensed Materials - Property of IBM
 * 6949-83N
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
*/

public with sharing class x7sNewsBaseController
{
	public static final String TOPIC_ASSIGNMENT_OBJ = 'TopicAssignment';
	public static final String NETWORK_MEMBER_OBJ = 'NetworkMember';
	
	public static BaseModel getModel()
	{
		return new BaseModel();
	}

	public class BaseModel
	{
		@AuraEnabled
		public String namespacePrefix { get; set; }

		@AuraEnabled
		public Boolean lexMode { get; set; }

		public BaseModel()
		{
			// Uncomment for managed package
			//this.namespacePrefix = [SELECT NamespacePrefix FROM ApexClass WHERE Name = 'x7sNewsBaseController' LIMIT 1].NamespacePrefix;
			this.namespacePrefix = '';
			this.lexMode         = System.Network.getNetworkId() == null;
		}
	}

	public static String getCommunityUrl()
	{
		String baseUrl = System.Url.getSalesforceBaseUrl().toExternalForm();

		try
		{
			String url = Network.getLoginUrl(Network.getNetworkId());
			String communityUrl = url.substring(0, url.lastIndexOf('/s/'));
			return communityUrl;
		} catch (Exception e)
		{
			System.debug('No community found');
			return baseUrl;
		}
	}

	/*
	* @description   :  Method to generate dynamic query for objects used in process.
					  this method is generating query for TopicAssignment,Topic as per our requirement
	*/
	public static String getQueryString(String strObj) {

		List<String> objectAccessFields = getAccessibleFields(strObj);

		if (objectAccessFields != null && !objectAccessFields.isEmpty()) {
			String query = '';

			if (strObj == TOPIC_ASSIGNMENT_OBJ) {
				objectAccessFields.add(String.escapeSingleQuotes('Topic.Name'));
			}

			if (strObj == NETWORK_MEMBER_OBJ) {
				objectAccessFields.add(String.escapeSingleQuotes('member.CommunityNickname'));
				objectAccessFields.add(String.escapeSingleQuotes('member.Name'));
			}

			query += 'SELECT ';
			query += String.join(objectAccessFields, ',');

			query += ' FROM ';
			query += strObj;

			return query;
		}
		else {
			return null;
		}
	}

	/*	
	* @description   :  Method to check all fields used in query are accessible
	*/
	public static List<String> getAccessibleFields(String strObj) {

		Set<String> NewsAccessFields = new Set<String>{
			'Id',
			'Name',
			'Archive_DateTime__c',
			'Audience_Selected__c',
			'Author__c',
			'Details__c',
			'GroupId__c',
			'Language__c',
			'Like_Count__c',
			'NetworkId__c',
			'Private_Group__c',
			'Publish_DateTime__c',
			'Show_Author__c',
			'Show_Internal__c',
			'Image_Type__c',
			'Image_Reference__c',
			'x7s_Featured_Formula__c',
			'OwnerId',
			'RecordTypeId'
		};

		Set<String> NewsTranslationAccessFields = new Set<String>{
			'Id',
			'Name',
			'Language__c',
			'Detail__c',
			'Parent_X7S_News__c',
			'Title__c'
		};
		Set<String> TopicAssignmentAccessFields = new Set<String>{
			'entityid',
			'topicid'
		};
		Set<String> TopicAccessFields = new Set<String>{
			'Id',
			'Name'
		};
		Set<String> AttachmentAccessFields = new Set<String>{
			'Id',
			'Name'
		};
		Set<String> NetworkMemberAccessFields = new Set<String>{
			'NetworkId'
		};

		List<String> objectAccessFields = null;

		switch on strObj {
			when 'X7S_News__c' {
				objectAccessFields = new List<String>(NewsAccessFields);
			}
			when 'X7S_News_Translation__c' {
				objectAccessFields = new List<String>(NewsTranslationAccessFields);
			}
			when 'TopicAssignment' {
				objectAccessFields = new List<String>(TopicAssignmentAccessFields);
			}
			when 'Topic' {
				objectAccessFields = new List<String>(TopicAccessFields);
			}
			when 'Attachment' {
				objectAccessFields = new List<String>(AttachmentAccessFields);
			}
			when 'NetworkMember' {
				objectAccessFields = new List<String>(NetworkMemberAccessFields);
			}
			when else {
				System.debug('getAccessibleFields - Unknown object request (' + strObj + ')');
			}
		}
		return objectAccessFields;
	}

	public static Boolean permissionSetMember(String userId, String permissionSetList) {
		Boolean isMember = false;

		if (String.isNotBlank(permissionSetList)) {
			List<String> permissionSets = permissionSetList.split(',\\s*');

			isMember = [SELECT COUNT() FROM PermissionSetAssignment WHERE AssigneeId = :userId AND PermissionSet.Name IN :permissionSets] > 0;
		}

		return isMember;
	}
}