/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public without sharing class x7sIdeasListWrapper {

	// Use the debug mode to display more diagnostic information - Disabled by default
	@AuraEnabled
	public Boolean debugMode {
		get;
		private set;
	}

	// Set the down voting flag in Custom Settings
	// Enabled by default
	@AuraEnabled
	public Boolean allowDownVoting {
		get;
		private set;
	}

	@AuraEnabled
	public List<Idea> ideaList {
		get;
		set;
	}

	@AuraEnabled
	public Integer totalResults {
		get;
		set;
	}

	@AuraEnabled
	public Integer totalPages {
		get;
		set;
	}

	@AuraEnabled
	public Integer pageNumber {
		get;
		set;
	}

	@AuraEnabled
	public Boolean hasPreviousSet {
		get;
		set;
	}

	@AuraEnabled
	public Boolean hasNextSet {
		get;
		set;
	}

	@AuraEnabled
	public Integer listSizeValue {
		get;
		private set;
	}

	@AuraEnabled
	public String dateCMTsetting {
		get;
		set;
	}

	@AuraEnabled
	public Map <String, String> topicNameToId {
		get;
		set;
	}

	@AuraEnabled
	public String sitePath {
		get;
		set;
	}

	private ApexPages.StandardSetController setController {
		get;
		set;
	}

	public x7sIdeasListWrapper(String QUERY, Integer listSizeValue) {
		this(QUERY, listSizeValue, new Set<Id>());
	}

	public x7sIdeasListWrapper(String QUERY, Integer listSizeValue, Set<Id> ideasIds) {
		System.debug('--->>>>IntoQuery' + QUERY);
		System.debug('---- IDs: ' + ideasIds);

		x7sIdeasCommon common = new x7sIdeasCommon('', false);

		this.topicNameToId = new Map<String, String>();
		this.listSizeValue = listSizeValue;

		X7S_Ideas_Setting__mdt setting = X7S_Ideas_Setting__mdt.getInstance('Default');
		if(setting != null) { this.dateCMTsetting = setting.Date_Display_Format__c; }
		else { this.dateCMTsetting = ''; }

		//System.debug('RESULTS: ' + Database.query(QUERY));

		this.setController = new ApexPages.StandardSetController(Database.getQueryLocator(QUERY));
		this.setController.setPageSize(listSizeValue);

		this.sitePath = common.sitePath;
		this.debugMode = common.debugMode;
		this.allowDownVoting = common.allowDownVoting;

		updateControllerAttributes(ideasIds);
	}

	public void nextPage() {
		this.setController.setPageNumber(this.pageNumber + 1 > 0 ? this.pageNumber + 1 : 1);
		updateControllerAttributes(new Set<Id>());
	}

	public void previousPage() {
		this.setController.setPageNumber(this.pageNumber - 1 > 0 ? this.pageNumber - 1 : 1);
		updateControllerAttributes(new Set<Id>());
	}

	public void getPage() {
		this.setController.setPageNumber(this.pageNumber);
		updateControllerAttributes(new Set<Id>());
	}

	@TestVisible
	private void updateControllerAttributes(Set<Id> ideasIds) {
		if (!ideasIds.isEmpty()) {
			this.ideaList = new List<Idea>();
			Map<Id, Idea> tempMap = new Map<Id, Idea>();
			List<Idea> tempList = this.setController.getRecords();

			for (Idea item : tempList) {
				tempMap.put(item.Id, item);
			}

			// keep in returned order
			for (Idea i : tempList) {
				if (tempMap.containsKey(i.Id)) {
					this.ideaList.add(tempMap.get(i.Id));
				}
			}
		}
		else {
			this.ideaList = this.setController.getRecords();
		}

		DumpIdeaList('After', ideaList, false);
		System.debug('    total results ' + this.setController.getResultSize());
		System.debug('    page size     ' + this.setController.getPageSize());
		System.debug('    page number   ' + this.setController.getPageNumber());

		this.totalResults = this.setController.getResultSize();
		this.totalPages = Math.mod(
			this.setController.getResultSize(), this.setController.getPageSize()) == 0
			? this.setController.getResultSize() / this.setController.getPageSize()
			: this.setController.getResultSize() / this.setController.getPageSize() + 1;
		this.pageNumber = this.totalPages > 0 ? this.setController.getPageNumber() : 0;
		this.hasPreviousSet = this.pageNumber > 1;
		this.hasNextSet = this.pageNumber < this.totalPages;

		Set<String> uniqueTopicNames = new Set<String>();

		for (Idea currIdea : this.ideaList) {
			if (!String.isEmpty(currIdea.Related_Topic_Name__c)) {
				uniqueTopicNames.add(currIdea.Related_Topic_Name__c);
			}
		}

		System.debug('topicNames' + uniqueTopicNames);
		List<String> topicNames = new List<String>();
		topicNames.addAll(uniqueTopicNames);

		this.topicNameToId = x7sIdeasTopicController.getTopicMap(topicNames);
		System.debug('----this.topicNameToId' + this.topicNameToId);
	}

	private void DumpIdeaList(String header, List<Idea> ideas, Boolean full) {
		System.debug('Ideas list: ' + header);

		for (Idea i : ideas) {
			if (full) {
				System.debug(i);
			}
			else {
				System.debug(i.Id + ', ' + i.Title);
			}
		}
	}
}