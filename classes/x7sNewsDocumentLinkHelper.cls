/*
 * Licensed Materials - Property of IBM
 * 6949-83N
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
*/
public with sharing class x7sNewsDocumentLinkHelper
{
	public static void onBeforeInsert(List<ContentDocumentLink> listOfContentDocLinks)
	{
		SObjectType newsObjectType =  X7S_News__c.getSObjectType();
		for (ContentDocumentLink cdl : listOfContentDocLinks) {
			if (cdl.LinkedEntityId.getSobjectType() == newsObjectType) { cdl.Visibility = 'AllUsers';}
		}
	}
}