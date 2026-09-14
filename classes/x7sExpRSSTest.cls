/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
public with sharing class x7sExpRSSTest {
	private class mockCallout implements HttpCalloutMock {
		public HttpResponse respond(HttpRequest req) {
			HttpResponse res = new HttpResponse();
			res.setStatus('OK');
			res.setStatusCode(200);
			String body = '<?xml version="1.0" encoding="UTF-8" ?> <rss version="2.0"> <channel> <title>Title</title> <link>http://www.google.com</link> <description>Description</description> <item> <title>Title</title> <link>http://www.google.com/xml/xml_rss.asp</link> <author>Test Author</author> <creator>Test Creator</creator> <category> Dublin, Ireland </category> <pubdate> 8/5/2017 </pubdate> <date> 8/5/2017 </date> <description>Description</description> <guid>1234</guid> </item> </channel> </rss>';
			res.setBody(body);
			return res;
		}
	}

	@IsTest
	static void testGetRSSFeedList() {
		Test.setMock(HttpCalloutMock.class, new mockCallout());
		Test.startTest();
		List<x7sExpRSS.RSSWrapper> wrapper = x7sExpRSS.getRSSFeedList('TestURL', '10');
		System.assertNotEquals(null, wrapper);
		Test.stopTest();
	}

	@IsTest
	static void testGetRSSFeedList_WhenErrorOccured_ReturnsException() {
		Boolean exceptionThrown = false;
		Test.startTest();
		try {
			Test.setMock(HttpCalloutMock.class, new mockCallout());
			List<x7sExpRSS.RSSWrapper> wrapper = x7sExpRSS.getRSSFeedList('TestURL', '2147483650');
		} catch (Exception e) {
			exceptionThrown = true;
		}
		Test.stopTest();

		System.assertEquals(true, exceptionThrown, 'Exception should be thrown.');
	}
}