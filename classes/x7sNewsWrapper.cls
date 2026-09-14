/*
 * Licensed Materials - Property of IBM
 * 6949-83N
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
*/

/**
* @description	: Wrapper. Apex class used by x7sNewsController Apex class
					   Mainly this class was created for implementing pagination using setcontroller.
*/
global with sharing class x7sNewsWrapper
{

	//List of X7S_News__c object
	@AuraEnabled
	global List<X7S_News__c> newsList { get; set; }

	@AuraEnabled
	global Boolean languageEnable { get; set; }

	@AuraEnabled
	global Boolean isGuestUser { get; set; }

	@AuraEnabled
	global String userLanguage { get; set; }

	@AuraEnabled
	global NetworkMember netMem { get; set; }

	//Map of Topic name to id used to pass name to topicURL component so that it form url for topic detail using topic id from map
	@AuraEnabled
	global Map <String, String> topicNameToId { get; set; }

	// Map of Group id to name for group name
	@AuraEnabled
	global Map<String, String> groupIdToName { get; set; }

	//List of topics associated with news record
	@AuraEnabled
	global List<TopicAssignment> topicsOfRecord { get; set; }

	//Total number of result (records) returned in query
	@AuraEnabled
	global Integer totalResults { get; set; }

	//Total number of pages in pagination as per total results
	@AuraEnabled
	global Integer totalPages { get; set; }

	//Page number for all total number of pages
	@AuraEnabled
	global Integer pageNumber { get; set; }

	//Boolean to check is there previous functionality to show previous button on component
	@AuraEnabled
	global Boolean hasPreviousSet { get; set; }

	//Boolean to check is there nxet functionality to show next button on component
	@AuraEnabled
	global Boolean hasNextSet { get; set; }

	//Integer listSizeValue to define limit in query as per design attributes
	@AuraEnabled
	global Integer listSizeValue { get; private set; }

	//As we have newList and one news can be associated with many topic,map of news id and list of topics associated with it
	@AuraEnabled
	global Map<Id, List<TopicAssignment>> newsToTopicsMap { get; set; }

	@AuraEnabled
	global String strTimeZone { get; set; }

	@AuraEnabled
	global String errorMsg { get; set; }

	@AuraEnabled
	global String field { get; set; }

	@AuraEnabled
	global Map<Id, Integer> newsToCommentCountMap { get; set; }

	@AuraEnabled
	global Set<Id> likedNewsIds { get; set; }

	@AuraEnabled
	global Map<Id,String> newsIdtoimageURLMap { get; set; }

	@AuraEnabled
	global String attachedFileURL { get; set; }

	@AuraEnabled
	public List<x7sNewsContentDocModel> relatedFilesDetails {get; set;}

	private ApexPages.StandardSetController setController { get; set; }

	global x7sNewsWrapper(String field, String errorMsg)
	{
		this.field = field;
		this.errorMsg = errorMsg;
	}

	/**
	@Name		  :  x7sNewsWrapper
	@parameters	  :  QUERY(query string to query records), intLimit is the limit to query ,newsIds to get records of specified news,
					  authorIds to get news records related to authorIds, fromDt and toDt to get news records in between these to dates as per filter applied on component,
					  isFeatured and featuredNewsIds are used featured 1+4 component is called.
	@Description   :  constructor for wrapper
	*/
	global x7sNewsWrapper(
		String QUERY,
		String languageFlag,
		Integer intLimit,
		Set<String> newsIds,
		Set<String> newsIdsByTopic,
		Set<String> authorIds,
		Datetime fromDt,
		Datetime toDt,
		Boolean isFeatured,
		Map<String, String> featuredNewsIds,
		Set<String> LngIds,
		String userType,
		List<String> audienceIds)
	{
		newsIdtoimageURLMap = new Map<Id,String>();

		// this date is used in the QUERY
		Datetime rightNow = Datetime.now();
		System.assertNotEquals(null, rightNow);
		Set<String> multiLngIds = LngIds;
		System.assertEquals(multiLngIds, LngIds);

		strTimeZone = String.valueOf(UserInfo.getTimeZone());
		//Initialise newsList
		this.newsList = new List<X7S_News__c>();

		//set limit to query
		this.listSizeValue = intLimit;

		// language flag check in CMT
		if (String.isNotBlank(languageFlag) && String.isNotEmpty(languageFlag))
		{
			this.languageEnable = true;
			this.userLanguage = languageFlag;
		} else
		{
			this.languageEnable = false;
		}

		this.isGuestUser = (userType == 'Guest') ? true : false;
		this.netMem = new NetworkMember();

		this.setController = new ApexPages.StandardSetController(Database.getQueryLocator(QUERY));

		//setting page size for position based on listSizeValue
		this.setController.setPageSize(listSizeValue);

		//call updateControllerAttributes method
		updateControllerAttributes(isFeatured, featuredNewsIds, intLimit);
		this.dumpWrapper();
	}

	private void dumpWrapper()
	{
		System.debug('Wrapper: ');
		System.debug('  List size         : ' + this.listSizeValue);
		System.debug('  Total records     : ' + this.totalResults);
		System.debug('  Total pages       : ' + this.totalPages);
		System.debug('  Has next          : ' + this.hasNextSet);
		System.debug('  Has prev          : ' + this.hasPreviousSet);
	}

	/**
	   @Name		  :  nextPage
	   @Description   :  used in pagination on click on next button
	   */
	global void nextPage()
	{

		//set page number for next page in pagination
		this.setController.setPageNumber(this.pageNumber + 1);

		//call updateControllerAttributes method
		updateControllerAttributes(false, null, 0);
	}

	/**
	@Name		  :  previousPage
	@Description   :  used in pagination on click on previous button
	*/
	global void previousPage()
	{

		//set page number for previous page in pagination
		this.setController.setPageNumber(this.pageNumber - 1);

		//call updateControllerAttributes method
		updateControllerAttributes(false, null, 0);
	}

	global void currentPage()
	{
		this.setController.setPageNumber(this.pageNumber);
		updateControllerAttributes(false, null, 0);
	}

	/**
	@Name		  :  updateControllerAttributes
	@parameters	:  isFeatured boolean , featuredNewsIds map
	@Description   :  used to set attributes of wrapper so that it can be used on components with proper data
	*/
	private void updateControllerAttributes(Boolean isFeatured, Map<String, String> featuredNewsIds, Integer intLimit)
	{

		/*For featured news, records are to be query in order they are entered in design property of component ,
		so we used map as it store order of ids entered*/

		if (isFeatured == true)
		{
			List<X7S_News__c> templist = this.setController.getRecords();
			Map<Id, X7S_News__c> tempNewsMap = new Map<Id, X7S_News__c>();

			for (X7S_News__c news : templist)
			{
				tempNewsMap.put(news.Id, news);
			}

			for (String str : featuredNewsIds.keySet())
			{
				if (tempNewsMap.containsKey(str))
				{
					this.newsList.add(tempNewsMap.get(str));
				}
			}
		}

		//for all other news list get records for set controller directly
		else
		{
			this.newsList = this.setController.getRecords();

		}

		Id netwrkId = System.Network.getNetworkId();

		if (intLimit == 1 && !this.newsList.isEmpty())
		{
			List<NetworkMember> netMember = new List<NetworkMember>();
			if (this.newsList[0].Author__c != null)
			{
				netMember = [SELECT Id, CreatedDate FROM NetworkMember WHERE MemberId = :this.newsList[0].Author__c AND NetworkId = :netwrkId WITH SECURITY_ENFORCED LIMIT 1];
			} else
			{
				netMember = [SELECT Id, CreatedDate FROM NetworkMember WHERE MemberId = :this.newsList[0].CreatedById AND NetworkId = :netwrkId WITH SECURITY_ENFORCED  LIMIT 1];
			}
			if (!netMember.isEmpty())
			{
				this.netMem = netMember[0];
			}

			//Get related image file URL for edit/Detail news page
			List<Id> listIds = new List<Id>();
			listIds.add(this.newsList[0].Id);
			try {
				List<ContentDocumentLink> documentLinkList = x7sNewsContentDocument.getContentDocumentLinks(listIds);
				String communityURL = x7sNewsBaseController.getCommunityUrl();

				List<ContentDocumentLink> links = x7sNewsContentDocument.containsEntityId(documentLinkList, this.newsList[0].Id);
				List<x7sNewsContentDocModel> contentList = new List<x7sNewsContentDocModel>();
				this.relatedFilesDetails = new List<x7sNewsContentDocModel>();

				for(ContentDocumentLink link : links) {
					x7sNewsContentDocModel content = new x7sNewsContentDocModel();
					content.latestImageVersionId = link.ContentDocument.LatestPublishedVersionId;
					content.imageTitle = link.ContentDocument.Title;
					content.selectedImage = (String) newsList[0].Image_Reference__c == (String) link.ContentDocument.LatestPublishedVersionId;
					contentList.add(content);
				}
				this.relatedFilesDetails.addAll(contentList);
				this.attachedFileURL = communityURL + x7sNewsContentDocument.FILE_LOCATION;
			}
			catch (Exception e) {
				System.debug('updateControllerAttributes():' + e.getMessage() + ' line number: ' + e.getLineNumber());
			}
		}

		this.errorMsg = '';

		this.field = '';

		//set totalResults from query result
		this.totalResults = this.setController.getResultSize();

		//set totalPages as per totalResults and page size
		this.totalPages = Math.mod(this.setController.getResultSize(), this.setController.getPageSize()) == 0 ? this.setController.getResultSize() / this.setController.getPageSize() : this.setController.getResultSize() / this.setController.getPageSize() + 1;

		//set pageNumber as per totalPages
		this.pageNumber = this.totalPages > 0 ? this.setController.getPageNumber() : 0;

		//set hasPreviousSet from getHasPrevious of set controller
		this.hasPreviousSet = this.setController.getHasPrevious();

		//set hasNextSet from getHasNext of set controller
		this.hasNextSet = this.setController.getHasNext();

		//fill set of news id retrived from query to fetch related topics
		Set<Id> newsObjIds = new Set<Id>();
		for (SObject news : this.setController.getRecords())
		{
			newsObjIds.add(news.Id);
		}

		//Initialise topicNameToId map and newsToTopicsMap
		this.topicNameToId = new Map<String, String>();
		newsToTopicsMap = new Map<Id, List<TopicAssignment>>();

		//created temporary list of topics to add it to map and associate with news id
		List<TopicAssignment> topics = new List<TopicAssignment>();

		List<TopicAssignment> topicList = new List<TopicAssignment>();
		if (netwrkId != null)
		{
			String strTopicQuery = x7sNewsBaseController.getQueryString('TopicAssignment') + ' WHERE EntityId IN : newsObjIds' + ' And Topic.NetworkId = \'' + netwrkId + '\'' + ' limit 1000';
			topicList = Database.query(strTopicQuery);
		} else
		{
			String strTopicQuery = x7sNewsBaseController.getQueryString('TopicAssignment');
			strTopicQuery += ' WHERE EntityId IN : newsObjIds';
			strTopicQuery += ' limit 1000';
			topicList = Database.query(strTopicQuery);
		}

		//Iterate on all topics of news ids retrived from query
		for (TopicAssignment t : topicList)
		{

			//fill map of topic name to topic id
			this.topicNameToId.put(t.Topic.Name, t.TopicId);
			topics = new List<TopicAssignment>();

			//fill map of news id to topics associated with it
			if (newsToTopicsMap.containsKey(t.EntityId))
			{
				topics.addAll(newsToTopicsMap.get(t.EntityId));
			}

			topics.add(t);
			if (intLimit == 1)
			{
				newsToTopicsMap.put(t.EntityId, topics);
			} else
			{
				newsToTopicsMap.put(t.EntityId, topics);
			}
		}
		//Getting Image URL for different Image types
		if(!this.newsList.isEmpty()) {
			Map<Id,String> newstoimageURL = new Map<Id,String>();
			newstoimageURL = x7sNewsImageController.getImageURL(this.newsList);
			this.newsIdtoimageURLMap.putAll(newstoimageURL);
		}

		// update group id, name map
		this.groupIdToName = x7sNewsController.getAllGroups();
		this.newsToCommentCountMap = generateNewsToCommentCountMap(newsObjIds);
		this.likedNewsIds = getNewsIdsLikedByUser(newsList);

	}

	private static Map<Id, Integer> generateNewsToCommentCountMap(Set<Id> newsIds)
	{
		Map<Id, Integer> newsIdToCommentCountMap = new Map<Id, Integer>();

		for (Id newsId : newsIds)
		{
			newsIdToCommentCountMap.put(newsId, 0); // Initialize...
		}

		// Sadly doesn't support aggregate queries or sub-counts :( so this is all manual...
		// https://developer.salesforce.com/forums/?id=906F0000000917CIAQ
		for (X7S_News__Feed item : [SELECT ParentId, Id,CommentCount FROM X7S_News__Feed WHERE ParentId = :newsIds])
		{
			// Get the current count
			// Increment by 1 at least (the parent feed item)
			Integer num = newsIdToCommentCountMap.get(item.ParentId) + 1;

			// Add the count of the comments to that first feed item
			newsIdToCommentCountMap.put(item.ParentId, num + item.CommentCount);
		}

		return newsIdToCommentCountMap;
	}

	private static Set<Id> getNewsIdsLikedByUser(List<X7S_News__c> newsList)
	{
		Set<Id> newsIdsLikedByUser = new Set<Id>();
		for (X7S_News_Like__c likeRecord : [SELECT Id, X7S_News__c FROM X7S_News_Like__c WHERE X7S_News__c IN :newsList AND User__c = :UserInfo.getUserId()])
		{
			newsIdsLikedByUser.add(likeRecord.X7S_News__c);
		}
		return newsIdsLikedByUser;
	}
}