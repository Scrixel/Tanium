/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public without sharing class x7sIdeasCommentModel {
	@AuraEnabled
	public String id, ideaId, zoneId, commentBody, creatorId, creatorName, nickName, fullPhotoUrl, smallPhotoUrl;

	@AuraEnabled
	public Datetime createdDate;

	@AuraEnabled
	public Boolean isHtml, likedByUser;

	// Votes
	@AuraEnabled
	public Integer upVotes;

	@AuraEnabled
	public String voteId;

	public x7sIdeasCommentModel() {
		id = '';
		ideaId = '';
		zoneId = '';
		commentBody = '';
		creatorId = '';
		creatorName = '';
		nickName = '';
		fullPhotoUrl = '';
		smallPhotoUrl = '';
		isHtml = false;
		upVotes = 0;
		voteId = '';
	}
}