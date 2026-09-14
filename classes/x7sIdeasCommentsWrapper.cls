/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public without sharing class x7sIdeasCommentsWrapper {
	public class CommentsModel {
		@AuraEnabled
		public String newStatus;

		@AuraEnabled
		public String changedBy;

		@AuraEnabled
		public Date changedDate;

		@AuraEnabled
		public String commentText;

		@AuraEnabled
		public String changedById;

		public CommentsModel() {

		}
	}
}