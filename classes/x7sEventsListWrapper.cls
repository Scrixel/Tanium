/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sEventsListWrapper {
	@AuraEnabled
	public List<X7S_Event__c> objEventList { get; set; }

	@AuraEnabled
	public String detailsForAddToCalendar { get; set; }

	@AuraEnabled
	public String summaryForAddToCalendar { get; set; }

	@AuraEnabled
	public Boolean isEditable { get; set; }

	@AuraEnabled
	public Map<String, String> topicNameToId { get; set; }

	@AuraEnabled
	public Map<String, String> groupIdToName { get; set; }

	@AuraEnabled
	public List<ConnectApi.Topic> topicLst { get; set; }

	@AuraEnabled
	public Integer intDate { get; set; }

	@AuraEnabled
	public String strMonth { get; set; }

	@AuraEnabled
	public String strDay { get; set; }

	@AuraEnabled
	public String strMinute { get; set; }

	@AuraEnabled
	public Integer daysOfMultiDaysEvent { get; set; }

	@AuraEnabled
	public List<TopicAssignment> topicsOfRecord { get; set; }

	@AuraEnabled
	public String strStartDate { get; set; }

	@AuraEnabled
	public String strEndDate { get; set; }

	/* PAGINATION Variables */
	@AuraEnabled
	public Integer totalResults { get; set; }

	@AuraEnabled
	public Integer totalPages { get; set; }

	@AuraEnabled
	public String dtNow { get; set; }

	@AuraEnabled
	public Integer pageNumber { get; set; }

	@AuraEnabled
	public Boolean hasPreviousSet { get; set; }

	@AuraEnabled
	public Boolean hasNextSet { get; set; }

	@AuraEnabled
	public Integer listSizeValue { get; private set; }

	@AuraEnabled
	public Map<Id, List<TopicAssignment>> eventsToTopicsMap { get; set; }

	@AuraEnabled
	public String strTimeZone { get; set; }

	@AuraEnabled
	public String errorMsg { get; set; }

	@AuraEnabled
	public String field { get; set; }

	@AuraEnabled
	public Boolean languageEnabled { get; set; }

	@AuraEnabled
	public Boolean isGuestUser { get; set; }

	@AuraEnabled
	public String userLanguage { get; set; }

	@AuraEnabled
	public Map<Id, String> eventIdtoimageURLMap { get; set; }

	@AuraEnabled
	public String attachedFileURL { get; set; }

	@AuraEnabled
	public List<x7sEventsContentDocModel> relatedFilesDetails { get; set; }

	@AuraEnabled
	public List<x7sEventsMaterialsWrapper> eventMaterialWrapper { get; set; }

	@AuraEnabled
	public List<x7sEventsSpeakerWrapper> eventSpeakerWrapper { get; set; }

	@AuraEnabled
	public List<x7sEventsSegmentWrapper> eventSegmentWrapper { get; set; }

	private ApexPages.StandardSetController setController { get; set; }

	private static final Id communityId = System.Network.getNetworkId();

	public x7sEventsListWrapper() {
		this.field = '';
		this.errorMsg = '';
		this.intDate = 0;
		this.dtNow = '';
		this.strTimeZone = '';
		this.strDay = '';
		this.strEndDate = '';
		this.strStartDate = '';
		this.strMinute = '';
		this.strMonth = '';
		this.isEditable = false;
		this.listSizeValue = 0;
		this.daysOfMultiDaysEvent = 0;
		this.hasNextSet = false;
		this.hasPreviousSet = false;
		this.pageNumber = 0;
		this.attachedFileURL = '';

		this.topicsOfRecord = new List<TopicAssignment>();
		this.eventsToTopicsMap = new Map<Id, List<TopicAssignment>>();
		this.topicLst = new List<ConnectApi.Topic>();
		this.eventIdtoimageURLMap = new Map<Id, String>();
		this.relatedFilesDetails = new List<x7sEventsContentDocModel>();
		this.eventMaterialWrapper = new List<x7sEventsMaterialsWrapper>();
		this.eventSegmentWrapper = new List<x7sEventsSegmentWrapper>();
		this.eventSpeakerWrapper = new List<x7sEventsSpeakerWrapper>();
	}

	public x7sEventsListWrapper(String field, String errorMsg) {
		this.field = field;
		this.errorMsg = errorMsg;
	}

	public x7sEventsListWrapper(
		String QUERY,
		Set<String> LngIds,
		Integer listSize,
		Datetime fromDt,
		Datetime toDt,
		Date fromDate,
		Date toDate,
		Set<String> eventIds,
		String listViewMode,
		Boolean isFeatured,
		Map<String, String> featurdEventIds,
		String languageFlag,
		String userType
	) {
		this.executeQuery(
			QUERY,
			LngIds,
			listSize,
			fromDt,
			toDt,
			fromDate,
			toDate,
			eventIds,
			listViewMode,
			isFeatured,
			featurdEventIds,
			null,
			languageFlag,
			userType,
			null
		);
	}
	public x7sEventsListWrapper(
		String QUERY,
		Set<String> LngIds,
		Integer listSize,
		Datetime fromDt,
		Datetime toDt,
		Set<String> eventIds,
		String listViewMode,
		Boolean isFeatured,
		Map<String, String> featurdEventIds,
		String languageFlag,
		String userType
	) {
		this.executeQuery(
			QUERY,
			LngIds,
			listSize,
			fromDt,
			toDt,
			null,
			null,
			eventIds,
			listViewMode,
			isFeatured,
			featurdEventIds,
			null,
			languageFlag,
			userType,
			null
		);
	}

	// This function is used by the EventListController
	public x7sEventsListWrapper(
		String QUERY,
		Set<String> LngIds,
		Integer listSize,
		Datetime fromDt,
		Datetime toDt,
		Date fromDate,
		Date toDate,
		Set<String> eventIds,
		String listViewMode,
		Boolean isFeatured,
		Map<String, String> featurdEventIds,
		Set<String> groupEventIds,
		String languageFlag,
		String userType,
		List<String> audienceIds
	) {
		this.executeQuery(
			QUERY,
			LngIds,
			listSize,
			fromDt,
			toDt,
			fromDate,
			toDate,
			eventIds,
			listViewMode,
			isFeatured,
			featurdEventIds,
			groupEventIds,
			languageFlag,
			userType,
			audienceIds
		);
	}

	public x7sEventsListWrapper(
		String QUERY,
		Set<String> LngIds,
		Integer listSize,
		Datetime fromDt,
		Datetime toDt,
		Set<String> eventIds,
		String listViewMode,
		Boolean isFeatured,
		Map<String, String> featurdEventIds,
		Set<String> groupEventIds,
		String languageFlag,
		String userType
	) {
		this.executeQuery(
			QUERY,
			LngIds,
			listSize,
			fromDt,
			toDt,
			null,
			null,
			eventIds,
			listViewMode,
			isFeatured,
			featurdEventIds,
			groupEventIds,
			languageFlag,
			userType,
			null
		);
	}

	public void executeQuery(
		String QUERY,
		Set<String> LngIds,
		Integer listSize,
		Datetime fromDt,
		Datetime toDt,
		Date fromDate,
		Date toDate,
		Set<String> eventIds,
		String listViewMode,
		Boolean isFeatured,
		Map<String, String> featurdEventIds,
		Set<String> groupEventIds,
		String languageFlag,
		String userType,
		List<String> audienceIds
	) {
		//Initialise EventList
		strTimeZone = Auth.CommunitiesUtil.isGuestUser()
			? null
			: String.valueOf(UserInfo.getTimeZone());
		this.objEventList = new List<X7S_Event__c>();
		this.topicNameToId = new Map<String, String>();

		Set<String> multiLngIds = LngIds;
		System.debug(multiLngIds);

		// language flag check in CMT
		if (String.isNotBlank(languageFlag) && String.isNotEmpty(languageFlag)) {
			this.languageEnabled = true;
			this.userLanguage = languageFlag;
		} else {
			this.languageEnabled = false;
		}
		this.isGuestUser = (userType == 'Guest') ? true : false;

		System.debug('Query');
		System.debug(QUERY);
		System.debug('***My Query END***');
		this.setController = new ApexPages.StandardSetController(Database.getQueryLocator(QUERY));

		if (listViewMode == 'CALENDAR') {
			this.listSizeValue = this.setController.getResultSize();
		} else {
			this.listSizeValue = listSize;
		}

		this.setController.setPageSize(listSizeValue);

		//Get related image file URL for edit event page
		if (listSize == 1) {
			List<X7S_Event__c> eventList = this.setController.getRecords();
			if (!eventList.isEmpty()) {
				List<Id> listIds = new List<Id>();
				listIds.add(eventList[0].Id);
				try {
					List<ContentDocumentLink> documentLinkList = x7sEventsContentDocument.getContentDocumentLinks(
						listIds
					);
					String communityURL = x7sEventsBaseController.getCommunityUrl();

					List<ContentDocumentLink> links = x7sEventsContentDocument.containsEntityId(
						documentLinkList,
						eventList[0].Id
					);
					List<x7sEventsContentDocModel> contentList = new List<x7sEventsContentDocModel>();
					this.relatedFilesDetails = new List<x7sEventsContentDocModel>();

					for (ContentDocumentLink link : links) {
						x7sEventsContentDocModel content = new x7sEventsContentDocModel();
						content.latestImageVersionId = link.ContentDocument.LatestPublishedVersionId;
						content.imageTitle = link.ContentDocument.Title;
						content.selectedImage =
							(String) eventList[0].Image_Reference__c ==
							(String) link.ContentDocument.LatestPublishedVersionId;
						contentList.add(content);
					}
					this.relatedFilesDetails.addAll(contentList);
					this.attachedFileURL = communityURL + x7sEventsContentDocument.FILE_LOCATION;

					if (X7S_Event_Material__c.SObjectType.getDescribe().isAccessible()) {
						//Get the Event Material for Edit Event page
						this.eventMaterialWrapper = x7sEventsMaterialsController.getMaterialsForEvent(
							eventList[0].Id
						);
					} else {
						System.debug('Error: Unable to access X7S_Event_Material__c');
					}

					if (X7S_Event_Speakers__c.SObjectType.getDescribe().isAccessible()) {
						//Get the Event Speakers for Edit Event page
						this.eventSpeakerWrapper = x7sEventsSpeakersController.initSpeakers(eventList[0].Id);
					} else {
						System.debug('Error: Unable to access X7S_Event_Speakers__c');
					}

					// Get the Event Segment list for Edit Event Page
					this.eventSegmentWrapper = x7sEventsSegmentController.loadSegments(eventList[0].Id);
				} catch (Exception e) {
					System.debug('executeQuery():' + e.getMessage() + ' line number: ' + e.getLineNumber());
				}
			}
		}

		System.debug('call to update controller attributes');
		updateControllerAttributes(isFeatured, featurdEventIds);
	}

	/*
		 Method Name : nextPage
		 Description : Method for fetching values of next page
	*/
	public void nextPage() {
		this.setController.setPageNumber(this.pageNumber + 1 > 0 ? this.pageNumber + 1 : 1);
		updateControllerAttributes(false, null);
	}

	/*
		 Method Name : previousPage
		 Description : Method for fetching values of previous page
	*/
	public void previousPage() {
		this.setController.setPageNumber(this.pageNumber - 1 > 0 ? this.pageNumber - 1 : 1);
		updateControllerAttributes(false, null);
	}

	/*
		 Method Name : currentPage
		 Description : Method for fetching values of current page
	*/
	public void currentPage() {
		this.setController.setPageNumber(this.pageNumber);
		updateControllerAttributes(false, null);
	}

	/*
		 Method Name : updateControllerAttributes
		 Description : Method for updating values of controlle attributes
	*/
	private void updateControllerAttributes(Boolean isFeatured, Map<String, String> featurdEventIds) {
		this.eventIdtoimageURLMap = new Map<Id, String>();
		if (isFeatured == true) {
			List<X7S_Event__c> templist = this.setController.getRecords();

			Map<Id, X7S_Event__c> tempEventsMap = new Map<Id, X7S_Event__c>();

			for (X7S_Event__c event : templist) {
				tempEventsMap.put(event.Id, event);
			}

			for (String str : featurdEventIds.keySet()) {
				if (tempEventsMap.containsKey(str)) {
					this.objEventList.add(tempEventsMap.get(str));
				}
			}
		} else {
			//for all other objEventList list get records for set controller directly
			this.objEventList = this.setController.getRecords();
			System.debug('list = ' + this.objEventList.size());
		}

		if (this.objEventList.size() > 0) {
			/*if Record is updated with All day event  then it takes value for today's date else will take today's date with time*/
			if (this.objEventList[0].All_Day_Event__c) {
				this.dtNow = String.valueOf(Date.today());
			} else {
				this.dtNow = String.valueOf(Datetime.now());
			}

			//Getting Image URL for different Image types
			Map<Id, String> eventsToimageURL = new Map<Id, String>();
			eventsToimageURL = x7sEventsImageController.getImageURL(this.objEventList);
			this.eventIdtoimageURLMap.putAll(eventsToimageURL);
		}

		this.totalResults = this.setController.getResultSize();
		this.totalPages = Math.mod(
				this.setController.getResultSize(),
				this.setController.getPageSize()
			) == 0
			? this.setController.getResultSize() / this.setController.getPageSize()
			: this.setController.getResultSize() / this.setController.getPageSize() + 1;
		this.pageNumber = this.totalPages > 0 ? this.setController.getPageNumber() : 0;
		this.hasPreviousSet = this.setController.getHasPrevious();
		this.hasNextSet = this.setController.getHasNext();

		Set<String> eventsObjIds = new Set<String>();
		for (SObject events : this.setController.getRecords()) {
			eventsObjIds.add(events.Id);
		}

		eventsToTopicsMap = new Map<Id, List<TopicAssignment>>();
		List<TopicAssignment> topics = new List<TopicAssignment>();

		String topicQuery = 'SELECT Id,EntityId,Topic.Id,Topic.Name FROM TopicAssignment WHERE EntityId IN :eventsObjIds';
		topicQuery += communityId != null ? ' AND NetworkId = :communityId' : ' AND NetworkId = null';

		List<TopicAssignment> assignments = Database.query(String.escapeSingleQuotes(topicQuery));

		for (TopicAssignment t : assignments) {
			this.topicNameToId.put(t.Topic.Name, t.Topic.Id);
			topics = new List<TopicAssignment>();
			if (eventsToTopicsMap.containsKey(t.EntityId)) {
				topics.addAll(eventsToTopicsMap.get(t.EntityId));
			}

			topics.add(t);

			eventsToTopicsMap.put(t.EntityId, topics);
		}

		this.groupIdToName = x7sEventsListController.getAllGroups();
	}
}