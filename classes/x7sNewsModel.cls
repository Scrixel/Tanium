/*
 * Licensed Materials - Property of IBM
 * 6949-83N
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
*/

public with sharing class x7sNewsModel {
    
    @AuraEnabled
	public String id, author, name, details, groupId,
				  language, networkId, featuredImageType, featuredImageReference;

	@AuraEnabled
    public Boolean audienceAssigned,showAuthor,privateGroup;
	
	@AuraEnabled
    public Datetime publishDate,archiveDate;

    @AuraEnabled
    public List<String> communityIds;
    
    @AuraEnabled
	public List<String> translations;

	public x7sNewsModel()
	{
		id = null;
		author = null;
		name = '';
		details = '';
		groupId = '';
		language = '';
		networkId = '';
		audienceAssigned = false;
		showAuthor = false;
		privateGroup = false;
		publishDate = null;
		archiveDate = null;
		communityIds = null;
		translations = null;
	}
}