/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sEventsExternalMeetingSecurity {

    private final static String ALGORITHM = 'hmacSHA256';
    private final static Integer TIME_TO_LIVE = 120;

    public String generateToken(String developerName) {

        String secret = '';
        String apiKey = '';
        X7S_Event_Integration_Setting__mdt integrationSetting = Test.isRunningTest() ? null : X7S_Event_Integration_Setting__mdt.getInstance(developerName);

        apiKey = Test.isRunningTest() ? x7sEventsTestConstants.TEST_API_KEY : integrationSetting.API_Key__c;
        secret = Test.isRunningTest() ? x7sEventsTestConstants.TEST_SECRET : integrationSetting.API_Secret__c;

        // Create the header
        Map<String, Object> header = new Map<String, Object>();
        header.put('alg', 'HS256');
        header.put('typ', 'JWT');

        String headerJson = JSON.serialize(header);

        String headerToken = EncodingUtil.base64Encode(Blob.valueOf(headerJson));

        // Create the body
        Auth.JWT token = new Auth.JWT();
        token.setIss(apiKey);
        token.setValidityLength(TIME_TO_LIVE);
        String bodyToken = EncodingUtil.base64Encode(Blob.valueOf(token.toJSONString()));

        // Create the JWT token
        String jwtToken = headerToken + '.' + bodyToken;

        Blob signature = Crypto.generateMac(ALGORITHM, Blob.valueOf(jwtToken), Blob.valueOf(secret));

        String output = EncodingUtil.base64Encode(signature);

        jwtToken += '.' + output;

        return jwtToken;
    }
}