/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sEventsSpeakerWrapper {
	@AuraEnabled
	public String Id { get; set; }

	@AuraEnabled
	public String EventId { get; set; }

	@AuraEnabled
	public String Name { get; set; }

	@AuraEnabled
	public String imageType { get; set; }

	@AuraEnabled
	public String user { get; set; }

	@AuraEnabled
	public String userId { get; set; }

	@AuraEnabled
	public String contact { get; set; }

	@AuraEnabled
	public String contactId { get; set; }

	@AuraEnabled
	public String speakerUrl { get; set; }

	@AuraEnabled
	public String speakerUrlLabel { get; set; }

	@AuraEnabled
	public String sessionTitle { get; set; }

	@AuraEnabled
	public String sessionLocation { get; set; }

	@AuraEnabled
	public Datetime sessionStartDate { get; set; }

	@AuraEnabled
	public Datetime sessionEndDate { get; set; }

	@AuraEnabled
	public String externalUrl { get; set; }

	@AuraEnabled
	public String speakerBio { get; set; }

	@AuraEnabled
	public String speakerNumber { get; set; }

	@AuraEnabled
	public fileWrapper file { get; set; }

	@AuraEnabled
	public String imageId { get; set; }

	public class fileWrapper {
		@AuraEnabled
		public String fileName { get; set; }
		@AuraEnabled
		public String fileContent { get; set; }
		@AuraEnabled
		public String imageUrl { get; set; }
		@AuraEnabled
		public String contentDocId { get; set; }
	}

	public x7sEventsSpeakerWrapper() {
		this.file = new fileWrapper();
		this.Id = '';
		this.Name = '';
		this.imageType = '';
		this.user = '';
		this.contact = '';
		this.speakerUrl = '';
		this.speakerUrlLabel = '';
		this.sessionTitle = '';
		this.sessionLocation = '';
		this.sessionStartDate = null;
		this.sessionEndDate = null;
		this.speakerBio = '';
		this.EventId = '';
	}
}