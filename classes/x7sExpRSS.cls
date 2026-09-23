/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sExpRSS {
    public class RSSWrapper {
        @AuraEnabled
        public String title { get; set; }
        @AuraEnabled
        public String link { get; set; }
        @AuraEnabled
        public String description { get; set; }
        @AuraEnabled
        public String publishDate { get; set; }
        @AuraEnabled
        public String guid { get; set; }
        @AuraEnabled
        public String dcDate { get; set; }
        @AuraEnabled
        public String author { get; set; }

        public RSSWrapper() {
            title = '';
            link = '';
            description = '';
            publishDate = '';
            guid = '';
            dcDate = '';
            author = '';
        }
    }

    @AuraEnabled
    public static List<RSSWrapper> getRSSFeedList(String rssFeedEndpoint, String recordsToShow) {
        try{
			List<RSSWrapper> feedWrappers = getRSSFeed(String.escapeSingleQuotes(rssFeedEndpoint),String.escapeSingleQuotes(recordsToShow));
            return feedWrappers;
		}catch(Exception e){throw new AuraHandledException(e.getMessage());}
    }

    public static List<RSSWrapper> getRSSFeed(String URL, String recordsToShow) {
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        // url that returns the XML in the response body

        req.setEndpoint(URL);
        req.setMethod('GET');
        HttpResponse res = h.send(req);
        Dom.Document doc = res.getBodyDocument();

        // Parse CData
        doc = removeCData(res.getBody());

        Dom.XmlNode rss = doc.getRootElement();

        List<RSSWrapper> rssWrapperList = new List<RSSWrapper>();
        for (Dom.XmlNode child : rss.getChildren()) {
            for (Dom.XmlNode item : child.getChildren()) {

                if (item.getName() == 'item') {
                    RSSWrapper wrapper = new RSSWrapper();
                    for (Dom.XmlNode parameter : item.getChildren()) {
                        String text = parameter.getText();
                        if (parameter.getName() == 'title') {
                            wrapper.title = text;
                        } else if (parameter.getName() == 'link') {
                            wrapper.link = text;
                        } else if (parameter.getName() == 'description' || parameter.getName() == 'encoded') {
                            wrapper.description = text;
                        } else if (parameter.getName() == 'pubDate') {
                            wrapper.publishDate = text;
                        } else if (parameter.getName() == 'guid') {
                            wrapper.guid = text;
                        } else if (parameter.getName() == 'date') {
                            wrapper.dcDate = text;
                        } else if (parameter.getName() == 'creator') { // wp creator
                            wrapper.author = text;
                        } else {
                            System.debug(parameter.getName());
                        }
                    }
                    rssWrapperList.add(wrapper);
                }
            }
        }
        if (recordsToShow != null && recordsToShow != '') {
            Integer listSize = Integer.valueOf(recordsToShow);
            if (listSize >= 1) {
                List<RSSWrapper> wrapperList = new List<RSSWrapper>();
                for (Integer i = 0; i < listSize && i < rssWrapperList.size(); ++i) {
                    wrapperList.add(rssWrapperList.get(i));
                }
                return wrapperList;
            } else {
                return new List<RSSWrapper>();
            }
        }

        return rssWrapperList;
    }

    /*
        Deal with pesky CDATA
        https://douglascayers.com/2017/04/26/how-to-parse-cdata-with-xmlnode-in-apex/
     */
    public static Dom.Document removeCData(String sourceDocumentString) {

        // replace CDATA sections with parseable tokens
        String documentString = sourceDocumentString.replaceAll('<!\\[CDATA\\[', 'XML_CDATA_START').replaceAll(']]>', 'XML_CDATA_END');

        // we will build up a map of original text and replacement text
        Map<String, String> replacementMap = new Map<String, String>();

        // regular expression to match sections we want to replace
        Pattern myPattern = Pattern.compile('(XML_CDATA_START)(.*?)(XML_CDATA_END)');
        Matcher myMatcher = myPattern.matcher(documentString);

        while (myMatcher.find()) {
            // the regex was too complicated for Matcher.replaceFirst(..)
            // so have to do it manually so just put in this map the
            // original text and the replacement text, we do replacing later
            replacementMap.put(myMatcher.group(), myMatcher.group(2).escapeXml());
        }

        // replace in the xml each CDATA section with the escaped XML of its inner content
        String newDocumentString = documentString;
        for (String key : replacementMap.keySet()) {
            newDocumentString = documentString.replace(key, replacementMap.get(key));
        }

        // parse the xml like normal
        Dom.Document formattedDocument = new Dom.Document();
        formattedDocument.load(newDocumentString);

        return formattedDocument;
    }
}