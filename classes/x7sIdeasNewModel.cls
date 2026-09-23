/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public without sharing class x7sIdeasNewModel {
	@AuraEnabled
	public List<IdeaTheme> themes { get; set; }

	@AuraEnabled
	public List<Topic> topics { get; set; }

	@AuraEnabled
	public List<String> categories { get; set; }

	// This is the US plural of status
	@AuraEnabled
	public List<String> statusus { get; set; }

	@AuraEnabled
	public String defaultStatus { get; set; }

	@AuraEnabled
	public Decimal maxFileSizeKb { get; set; }

	@AuraEnabled
	public String allowedExtensions { get; set; }

	@AuraEnabled
	public x7sIdeasCommon settings { get; set; }
}