/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public without sharing class x7sIdeasNewController {
	private static final Integer TOPIC_LOAD_LIMIT = 2000;
	private static final Decimal MAX_UPLOAD_FILE_SIZE = 4248;
	private static final Integer MAX_USERS_LOAD_LIMIT = 7;

	@AuraEnabled (Cacheable=true)
	public static x7sIdeasCommon getCommonSettings(String zoneName) {
		x7sIdeasCommon settings = new x7sIdeasCommon('', false);

		settings.sitePath = getSitePrefix();
		settings.zoneId = getZoneId(zoneName);
		settings.isAuthenticated = isAuthenticated();
		settings.nicknameEnabled = x7sIdeasUtility.isNicknameDisplayEnabled();

		return settings;
	}

	/**
	 * @description Get Idea Model to Create new idea record
	 * 
	 * @param zoneName Idea Zone Name
	 * @param fieldSetName Custom Field Set Name
	 * @param useTopics Whether to include topics or not
	 * @param useCategories Whether to include categories or not
	 * @param useStatus Whether to include status list or not
	 * @param statusList Idea Status List
	 * @return New Idea Model Class
	 */
	@AuraEnabled (Cacheable=true)
	public static x7sIdeasNewModel getIdeasNewModel(String zoneName, String fieldSetName, Boolean useTopics, Boolean useCategories, Boolean useStatus, String statusList) {
		x7sIdeasNewModel model = new x7sIdeasNewModel();

		model.settings = getCommonSettings(zoneName);
		model.themes = getThemeList(zoneName);
		model.topics = useTopics ? getTopicNamesList(true) : null;
		model.categories = useCategories ? x7sIdeasUtility.getIdeaCategoryValues() : null;
		model.statusus = useStatus ? x7sIdeasUtility.getIdeaStatusValues(zoneName) : null;
		model.defaultStatus = getDefaultStatus(zoneName, statusList);

		getMaxFileSize(model);
		return model;
	}

	@TestVisible
	private static void getMaxFileSize(x7sIdeasNewModel model) {
		Decimal maxFileSizeKb = MAX_UPLOAD_FILE_SIZE;
		String allowedExtensions = '.pdf, .jpeg, .png';
		String networkId = Network.getNetworkId();
		List<Network> networkList;
		Network curNetwork;

		if (Test.isRunningTest()) {
			networkId = [SELECT Id FROM Network LIMIT 1][0].Id;
		}

		networkList = (List<Network>) [SELECT Id, MaxFileSizeKb, AllowedExtensions FROM Network WHERE Id = :networkId  ];

		if (networkList != null && networkList.size() > 0) {
			curNetwork = networkList[0];

			if (curNetwork.MaxFileSizeKb != null && curNetwork.MaxFileSizeKb != 0 && curNetwork.MaxFileSizeKb < MAX_UPLOAD_FILE_SIZE) { maxFileSizeKb = curNetwork.MaxFileSizeKb;}

			if (curNetwork.AllowedExtensions != null) { allowedExtensions = curNetwork.AllowedExtensions;}
		}

		model.allowedExtensions = allowedExtensions;
		model.maxFileSizeKb = maxFileSizeKb;
	}

	@AuraEnabled
	public static Boolean isAuthenticated() {
		return !Auth.CommunitiesUtil.isGuestUser();
	}

	@AuraEnabled (Cacheable=true)
	public static String getSitePrefix() {
		return System.Site.getPathPrefix();
	}


	@AuraEnabled (Cacheable=true)
	public static String getZoneId(String nameValue) {
		String zoneId = '';

		if (String.isNotEmpty(nameValue)) {
			List<Community> currCommunity = [SELECT Id FROM Community WHERE Name = :nameValue];

			if (currCommunity != null && currCommunity.size() > 0) {
				zoneId = currCommunity[0].Id;
			}
		}

		return zoneId;
	}

	public class RelatedFiles {
		@AuraEnabled public List<RelatedFile> files;
	}

	public class RelatedFile {
		@AuraEnabled public String name;
		@AuraEnabled public String fileName;
		@AuraEnabled public String dataString;
	}

	/** 
	 * @description This method is used to get the Id of idea records which is going to insert and if any error occurs it passes the error message.
	 *	Visibility: AllUsers.
	 @param zoneName Idea Zone Name
	 @param currIdeaList Idea List
	 @param imageString Image String
	 @param relatedFileString Related file string
	 @param visibility related file visibility
	 @return Created/Updated Idea
	*/
	@AuraEnabled
	public static String createIdeaNew(String zoneName, List<Idea> currIdeaList, String imageString, String relatedFileString, String visibility) {
		List<RelatedFile> relatedFiles = new List<RelatedFile>();

		if (String.isNotBlank(relatedFileString)) {
			RelatedFiles relatedFileItems = (RelatedFiles) JSON.deserialize(relatedFileString, RelatedFiles.class);

			if (relatedFileItems != null) {
				for (RelatedFile entry : relatedFileItems.files) {
					relatedFiles.add(entry);
				}
			}
		}

		String ideaId = null;
		String ideaExtId = null;

		try {
			if (currIdeaList != null && currIdeaList.size() > 0) {				
				if (String.isNotBlank(imageString)) { currIdeaList[0].AttachmentBody = EncodingUtil.base64Decode(imageString);}				
				
				if (currIdeaList[0].Id == null) {
					if (Schema.sObjectType.Idea.isCreateable()) {
						insert currIdeaList;
					} else {
						return 'Error: You do not have permission to submit an idea.';
					}
				} else if (currIdeaList[0].Id != null) {
					if (Schema.sObjectType.Idea.isUpdateable()) {
						update currIdeaList;
					} else {
						return 'Error: You do not have permission to edit an idea.';
					}
				}

				// get the idea details
				Idea createdIdea = currIdeaList[0];
				ideaId = String.valueOf(createdIdea.Id);

				x7sIdeasListWrapper wrapper = x7sIdeasViewController.getIdeaRecord(
					createdIdea.CommunityId, createdIdea.Id, '');
				Idea newIdea = wrapper.ideaList[0];
				ideaExtId = String.valueOf(newIdea.X7S_Ideas_Extension__c);

				// add related files
				if (ideaExtId != null
					&& relatedFiles != null
					&& relatedFiles.size() > 0) {
					
					if(ContentVersion.SObjectType.getDescribe().isCreateable() &&
						Schema.SObjectType.ContentVersion.fields.Title.isCreateable() &&
						Schema.SObjectType.ContentVersion.fields.PathOnClient.isCreateable() &&
						Schema.SObjectType.ContentVersion.fields.ContentLocation.isCreateable() &&
						Schema.SObjectType.ContentVersion.fields.VersionData.isCreateable()) {
						List<ContentVersion> contentVersions = new List<ContentVersion>();

						for (RelatedFile related : relatedFiles) {
							ContentVersion content = new ContentVersion();

							content.Title = related.name;
							content.PathOnClient = related.fileName;
							content.ContentLocation = 'S';
							content.VersionData = EncodingUtil.base64Decode(related.dataString);

							contentVersions.add(content);
						}
						insert contentVersions;

						List<String> contentIds = new List<String>();
						for (ContentVersion content : contentVersions) {
							contentIds.add(content.Id);
						}
						// link to the Idea
						if(ContentDocumentLink.SObjectType.getDescribe().isCreateable() &&
							Schema.SObjectType.ContentDocumentLink.fields.ContentDocumentId.isCreateable() &&
							Schema.SObjectType.ContentDocumentLink.fields.LinkedEntityId.isCreateable() &&
							Schema.SObjectType.ContentDocumentLink.fields.ShareType.isCreateable() &&
							Schema.SObjectType.ContentDocumentLink.fields.Visibility.isCreateable()) {

							List<ContentDocumentLink> relatedLinks = new List<ContentDocumentLink> ();
							List<ContentVersion> insertedContent = [SELECT ContentDocumentId FROM ContentVersion WHERE Id IN :contentIds];

							for (ContentVersion currentVersion : insertedContent) {
								ContentDocumentLink relatedLink = new ContentDocumentLink();

								relatedLink.ContentDocumentId = currentVersion.ContentDocumentId;
								relatedLink.LinkedEntityId = ideaExtId;
								relatedLink.ShareType = 'I';
								relatedLink.Visibility = visibility;

								relatedLinks.add(relatedLink);
							}
							insert relatedLinks;
						}
					}
				}
			}
			return ideaId;
		}
		catch (Exception e) { System.debug('createNewIdea Apex exception: ' + e); throw e;}
	}

	/**
	 * @description Used to get idea record
	 * @param zoneId Idea zone id
	 * @param recordId Idea record id
	 * @param customFields Custom fields
	 * @return Idea List Wrapper
	 */
	@AuraEnabled
	public static x7sIdeasListWrapper getIdeaRecord(String zoneId, String recordId, String customFields) {
		return x7sIdeasViewController.getIdeaRecord(zoneId, recordId, customFields);
	}

	/**
	 * @description Used to delete idea record
	 * @param ideaId Idea record Id
	 * @return True if idea is deleted else false
	 */
	@AuraEnabled
	public static Boolean deleteIdea(String ideaId) {
		Boolean result = true;

		if (!String.isEmpty(ideaId) && Schema.sObjectType.Idea.isDeletable()) {
			try {
				Idea currIdea = new Idea(Id = ideaId);
				delete currIdea;
			}
			catch (Exception e) {
				result = false;
			}
		}

		return result;
	}

	@AuraEnabled
	public static List<Idea> checkDuplicateIdeas(String title, String zoneId, Integer simIdeasLimit, String statusList) {
		Integer simIdeasLimitValue = Integer.valueOf(simIdeasLimit);

		List<Idea> ideasList = new List<Idea>();
		List<Idea> ideasListSOSL = new List<Idea>();

		if (!String.isEmpty(title)) {
			List<String> keywordList = title.replace('%', '').replace('*', '').split(' ');
			Set<String> keywordSet = new Set<String>();
			Set<String> keywordSetSOSL = new Set<String>();

			for (String s : keywordList) {
				if (s.trim().length() > 1) {
					keywordSet.add(s.trim());
					keywordSetSOSL.add('*' + s.trim() + '*');
				}
			}

			if (keywordSet.size() > 0) {
				keywordList = new List<String>(keywordSet);
				String keywordStringSOSL = '("' + String.join(new List<String>(keywordSetSOSL), '") OR ("') + '")';

				if (String.isBlank(statusList)) {
					ideasListSOSL = (List<Idea>) [FIND :keywordStringSOSL RETURNING Idea(Id, Title, VoteTotal WHERE CommunityId = :zoneId) LIMIT :simIdeasLimitValue][0];
				}
				else {
					List<String> statusEntries = statusList.split(',');
					ideasListSOSL = (List<Idea>) [FIND :keywordStringSOSL RETURNING Idea(Id, Title, VoteTotal WHERE CommunityId = :zoneId AND (Status IN :statusEntries)) LIMIT :simIdeasLimitValue][0];
				}
				ideasList = [SELECT Id, Title, VoteTotal FROM Idea WHERE CommunityId = :zoneId AND Title IN :keywordList AND (NOT Id IN :ideasListSOSL) ORDER BY VoteScore DESC LIMIT :simIdeasLimitValue];
				ideasList.addAll(ideasListSOSL);

				if (ideasList.size() > simIdeasLimitValue) {
					List<Idea> tmpIdeasList = new List<Idea>();
					for (Idea currIdea : ideasList) {
						if (tmpIdeasList.size() < simIdeasLimitValue) {
							tmpIdeasList.add(currIdea);
						}
						else {
							break;
						}
					}

					ideasList = tmpIdeasList;
				}

			}
		}

		return ideasList;
	}

	/**
	 * @description Used to get idea theme list based on zone
	 * @param ideaZoneName Idea Zone Name
	 * @return List of themes
	 */
	@AuraEnabled
	public static List<IdeaTheme> getThemeList(String ideaZoneName) {
		try {
			Community c = [SELECT Id FROM Community WHERE Name = :ideaZoneName LIMIT 1];
			return c.Id != null ? [SELECT Id, Title FROM IdeaTheme WHERE CommunityId = :c.Id ORDER BY Title] : null;
		}
		catch (QueryException e) {
			System.debug('cannot load themes for ' + ideaZoneName);
			return new List<IdeaTheme>();
		}
	}

	/**
	 * @description Used to get topic list
	 * @param managedType Whether to include navigational topics or not
	 * @return List of topics
	 */
	@AuraEnabled
	public static List<Topic> getTopicNamesList(Boolean managedType) {
		Id networkId = System.Network.getNetworkId();

		List<Topic> topicList = new List<Topic>();

		if (networkId != null) {
			if (managedType) {
				topicList = [SELECT CreatedById, CreatedDate, Description, Id, Name, NetworkId, TalkingAbout FROM Topic WHERE NetworkId = :networkId AND ManagedTopicType LIKE '%Navigational%' ORDER BY Name LIMIT :TOPIC_LOAD_LIMIT];
			} else {
				topicList = [SELECT CreatedById, CreatedDate, Description, Id, Name, NetworkId, TalkingAbout FROM Topic WHERE NetworkId = :networkId ORDER BY Name LIMIT :TOPIC_LOAD_LIMIT];
			}
		} else {
			topicList = [SELECT CreatedById, CreatedDate, Description, Id, Name, NetworkId, TalkingAbout FROM Topic WHERE NetworkId = NULL ORDER BY Name LIMIT :TOPIC_LOAD_LIMIT];
		}
		return topicList;
	}

	@AuraEnabled
	public static List<String> getStatusValues(String zoneName) {
		return x7sIdeasUtility.getIdeaStatusValues(zoneName);
	}

	@AuraEnabled
	public static List<String> getCategoryValues(String themeName) {
		return String.isBlank(themeName) ? x7sIdeasUtility.getIdeaCategoryValues() : x7sIdeasUtility.getThemeCategories(themeName);
	}

	/**
	 * @description Used to get default idea status value
	 * @param zoneName Idea Zone Name
	 * @param statusList List of Idea Status Values from front end
	 * @return Default Idea Status
	 */
	@TestVisible
	private static String getDefaultStatus(String zoneName, String statusList) {
		String defaultValue = '';

		try {
			Schema.DescribeFieldResult fieldResult = Idea.Status.getDescribe();
			List <Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();

			//Default Value Option 1 : From given Status List
			if(String.isNotBlank(statusList)) {			
				List<String> statuses = new List<String>();
				statuses = statusList.split(x7sIdeasBaseController.STATUS_SEPARATOR);

				if(statuses.size() > 0) {
					for(String status : statuses) {
						for (Schema.PicklistEntry picklistValue : picklistValues) {
							if (picklistValue.active) {
								String statusLabel = picklistValue.getLabel();
								if(statusLabel == status) {
									defaultValue = status;									
									return defaultValue;
								}
							}
						}
					}
				}
			}

			//Default Value Option 2 : From CMT Setting Default Status Field
			if(!String.isEmpty(zoneName)) {
				Boolean isZoneSetting = false;
				String defaultStatusCMT;
				List<String> statusListFromCMT = new List<String>();
	
				List<X7S_Ideas_Zone_Setting__mdt> zoneSettings = X7S_Ideas_Zone_Setting__mdt.getAll().values();
				for(X7S_Ideas_Zone_Setting__mdt setting : zoneSettings) {
					if(setting.Zone_Name__c == zoneName) {
						isZoneSetting = true;
						defaultStatusCMT = setting.Default_Status__c;	
						String statusValues = setting.Statuses__c;
						if(String.isNotBlank(statusValues)) {
							statusListFromCMT = statusValues.split(x7sIdeasBaseController.STATUS_SEPARATOR);			
							break;
						}
					}
				}					

				if(isZoneSetting && picklistValues != null) {

					for (Schema.PicklistEntry picklistValue : picklistValues) {
						if (picklistValue.active) {
							String statusLabel = picklistValue.getLabel();
							if(statusLabel == defaultStatusCMT) {
								defaultValue = statusLabel;								
								return defaultValue;
							}
						}
					}
					
					//Default Value Option 3 : From CMT Setting Status List if no valid value found in Default Status field
					if(String.isBlank(defaultValue) && statusListFromCMT.size() > 0) {
						for(String status : statusListFromCMT) {
							for (Schema.PicklistEntry picklistValue : picklistValues) {
								if (picklistValue.active) {
									String statusLabel = picklistValue.getLabel();
									if(statusLabel == status) {
										defaultValue = statusLabel;
										return defaultValue;
									}
								}
							}
						}
					}
 				}
			}

			//Default Value Option 4 : From Idea Object
			if (picklistValues != null) {
				for (Schema.PicklistEntry picklistValue : picklistValues) {
					if (picklistValue.isDefaultValue()) {
						defaultValue = picklistValue.getValue();
						return defaultValue;
					}
				}
			}

			//Default Value Option 5 : If no default value is set on object, default idea status with 1st picklist value
			if (String.isBlank(defaultValue) && picklistValues != null && picklistValues.size() > 0) {
				defaultValue = picklistValues[0].getValue();
			}
		}
		catch (Exception e) {
			System.debug('getDefaultStatus exception: ' + e.getMessage());
		}
		return defaultValue;
	}

	@AuraEnabled
	public static List<User> fetchUsers(String inputKeyword) {
		Integer userLimit = MAX_USERS_LOAD_LIMIT;
		String userInput = '%' + String.escapeSingleQuotes(inputKeyword) + '%';

		List<User> returnList = [
			SELECT Id, Username, LastName, FirstName, Name, CompanyName, Title
			FROM User
			WHERE Name LIKE :userInput
			LIMIT :userLimit
		];
		Security.stripInaccessible(AccessType.READABLE, returnList);

		return returnList;
	}

	@AuraEnabled
	public static User getRequestedByRecord(String userId) {
		try {
			return [SELECT Id, Name, FirstName, LastName FROM User WHERE Id = :userId];
		} catch (Exception ex) { System.debug('Error :' + ex.getMessage() + ',Line number : ' + ex.getLineNumber());return null;}
	}

	@AuraEnabled
	public static QuestionDetail getQuestionDetail(String recordId) {
		QuestionDetail questionDetail = new QuestionDetail();
		try {
			List<FeedItem> listOfFeedItems = [SELECT Id,ParentId,Body,Title,CreatedById FROM FeedItem WHERE Id = :recordId];

			if (!listOfFeedItems.isEmpty()) {
				questionDetail.Body = String.isEmpty(listOfFeedItems[0].Body) ? '' : listOfFeedItems[0].Body;
				questionDetail.Title = String.isEmpty(listOfFeedItems[0].Title) ? '' : listOfFeedItems[0].Title;

				if (!String.isEmpty(listOfFeedItems[0].ParentId)) {
					List<User> feedUsers = [SELECT Id,Name,FirstName, LastName FROM User WHERE Id = :listOfFeedItems[0].CreatedById];

					if (!feedUsers.isEmpty()) {
						questionDetail.requestedBy = feedUsers[0];
					}
				}
			}
			return questionDetail;

		} catch (Exception ex) { System.debug('getQuestionDetail() - Error :' + ex.getMessage() + ',Line number : ' + ex.getLineNumber());return null;}
	}

	public class QuestionDetail {
		@AuraEnabled public String Body;
		@AuraEnabled public String Title;
		@AuraEnabled public User requestedBy;
	}

	
	/** 
	* @description This method is used to check Edit access of Featured__c field on Idea Object
	* @return true if user has edit access of Featured_c field
	*/
	@AuraEnabled
	public static Boolean hasFeaturedFieldAccess() {
		return Schema.sObjectType.Idea.fields.Featured__c.isUpdateable();
	}
}