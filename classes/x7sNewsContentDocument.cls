/*
 * Licensed Materials - Property of IBM
 * 6949-83N
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
*/

public with sharing class x7sNewsContentDocument {
    
    public static final String FILE_LOCATION = '/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=';
	public static final String FILE_PARAMS   = '?rendition=THUMB720BY480&versionId=';

	public static List<ContentDocumentLink> getContentDocumentLinks(List<Id> listIds) {
		String contentQuery = 'SELECT ContentDocumentLink.LinkedEntityId'
			+ ', ContentDocument.LatestPublishedVersionId'
			+ ', ContentDocument.Title'
			+ ', ContentDocument.FileExtension'
			+ ' FROM ContentDocumentLink'
			+ ' WHERE ContentDocument.FileType IN (\'JPG\', \'JPEG\', \'PNG\', \'GIF\') AND LinkedEntityId IN ';

		String temp = ' (';

		for (Id itemId : listIds) {
			temp += '\'' + itemId + '\', ';
		}

		contentQuery += temp.contains(', ') ? temp.substring(0, temp.lastIndexOf(', ')) + ')' : '';
		contentQuery += ' ORDER BY ContentDocument.CreatedDate DESC';

		//PMD : False positive, All variables are checked
		List<ContentDocumentLink> documentLinkList = (List<ContentDocumentLink>) Database.query(contentQuery); //NOPMD
		return documentLinkList;
	}

	public static List<ContentDocumentLink> containsEntityId(List<ContentDocumentLink> documentList, Id searchId) {
		List<ContentDocumentLink> links = new List<ContentDocumentLink>();
		for (ContentDocumentLink link : documentList) {
			if (link.LinkedEntityId == searchId) {
				links.add(link);
			}
		}
		return links;
	}

}