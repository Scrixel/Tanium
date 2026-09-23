/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sEventsTestConstants {
	// These profiles are assumed to have full access to the 7S X7S_Event__c and related objects
	public static final String CUSTOMER_COMMUNITY_USER = 'Customer Community User';
	public static final String CUSTOMER_COMMUNITY_USER_CLONE = 'Customer Community User Clone';

	public static final String TEST_EVENT_NAME = 'x7s Test Event';

	public static final String TEST_HTTP_BODY = '{"foo":"bar"}';
	public final static String TEST_API_KEY = 'sampleKey';
	public final static String TEST_SECRET = 'sampleSecret';

	public final static String TEST_CMS_ID_1 = '20Y4x000TY04icCEAQ';
	public final static String TEST_CMS_ID_2 = '20Y4x000TY04icCEAP';
	public final static String TEST_COMMUNITY_ID = '0DB0e000000CaezGAC';
}