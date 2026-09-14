/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sEventsRegList {
	@AuraEnabled
	public List<x7sEventsRegistrationFieldsModal> listItem { get; set; }

	public x7sEventsRegList() {
		this.listItem = new List<x7sEventsRegistrationFieldsModal>();
	}
}