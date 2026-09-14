/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sExpJSONFeedController {

    public static final String FEED_TYPE_TEST = 'Test';

    /*
        Generic wrapper for http response
     */
    public class ResponseWrapper {
        @AuraEnabled
        public Integer responseCode { get; set; }

        @AuraEnabled
        public String responseStatus { get; set; }

        @AuraEnabled
        public String errorMessage { get; set; }

        @AuraEnabled
        public String responseBody { get; set; }
    }


    /*
        Get the JSON Feed, unwrap it, and return it
     */
    @AuraEnabled
    public static ResponseWrapper getJSONFeed(String endpointUrl, String feedType) {
        try{
			ResponseWrapper responseWrapper = new ResponseWrapper();
        // If we're in test mode, just get a x7sExpContent Object
        if (feedType == FEED_TYPE_TEST) {
            responseWrapper.responseCode = 200;

            // Temp content object!
            x7sExpContentObject testContentObject = new x7sExpContentObject();
            testContentObject.title = 'Title of Content';
            testContentObject.dateTimeField = Datetime.newInstance(System.today(), Time.newInstance(3, 3, 3, 0));
            testContentObject.description = 'Milwaukee, WI';
            testContentObject.fullDescription = '7Summits Headquarters';
            testContentObject.url = 'http://7summitsinc.com';

            // Serialize it!
            responseWrapper.responseBody = JSON.serialize(testContentObject);
        } else {
            // When not in test mode, get the actual response
            // Set it up

            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpointUrl);
            request.setMethod('GET');

            try {
                // Get that request
                HttpResponse response = http.send(request);

                // Process it
                responseWrapper.responseCode = response.getStatusCode();
                responseWrapper.responseStatus = response.getStatus();
                responseWrapper.responseBody = response.getBody();
            } catch (Exception e) {
                responseWrapper.errorMessage = e.getMessage();
            }
        }
        return responseWrapper;
		}catch(Exception e){throw new AuraHandledException(e.getMessage());}
    }
}