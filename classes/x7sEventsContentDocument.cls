/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */
/**
 * @description This class is used to perform operations on contentDocuments like getting related files
 */
public with sharing class x7sEventsContentDocument {
	public static final String FILE_LOCATION = '/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=';

	/**
	 * @description Used to get related contentDocuments for given list of records.
	 * @param listIds List of records Ids
	 * @return List of ContentDocumentLink
	 */
	public static List<ContentDocumentLink> getContentDocumentLinks(List<Id> listIds) {
		String contentQuery =
			'SELECT ContentDocumentLink.LinkedEntityId' +
			', ContentDocument.LatestPublishedVersionId' +
			', ContentDocument.Title' +
			', ContentDocument.FileExtension' +
			' FROM ContentDocumentLink' +
			' WHERE ContentDocument.FileType IN (\'JPG\', \'PNG\', \'GIF\',\'JPEG\') AND LinkedEntityId IN ';

		String temp = ' (';

		for (Id itemId : listIds) {
			temp += '\'' + itemId + '\', ';
		}

		contentQuery += temp.contains(', ') ? temp.substring(0, temp.lastIndexOf(', ')) + ')' : '';
		contentQuery += ' WITH SECURITY_ENFORCED';
		contentQuery += ' ORDER BY ContentDocument.CreatedDate DESC';

		//PMD : False positive, All variables are checked
		return (List<ContentDocumentLink>) Database.query(contentQuery); //NOPMD;
	}

	/**
	 * @description Used to check if searchId is present in the list of ContentDocumentLink
	 * @param documentList ContentDocumentLink list
	 * @param searchId Id to check with
	 * @return list of ContentDocumentLink where given searchId has match
	 */
	public static List<ContentDocumentLink> containsEntityId(
		List<ContentDocumentLink> documentList,
		Id searchId
	) {
		List<ContentDocumentLink> links = new List<ContentDocumentLink>();
		for (ContentDocumentLink link : documentList) {
			if (link.LinkedEntityId == searchId) {
				links.add(link);
			}
		}
		return links;
	}
}