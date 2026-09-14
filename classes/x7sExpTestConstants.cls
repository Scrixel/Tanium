/*
 * Licensed Materials - Property of IBM
 * 6949-82Q
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sExpTestConstants {

    public static final String COMMUNITY_PROFILE = 'System Administrator'; // Update this to whatever your client's profile for most Community Users

    public static final String GUEST_ALIAS = 'x7sGuest';
    public static final String GUEST_USERNAME = 'x7s_guestuser@x7sExp.com';
    public static final String GUEST_EMAIL = 'x7s_guestuser@x7sExp.com';

    public static final String STANDARD_ALIAS = 'x7s_Std';
    public static final String STANDARD_USERNAME = 'x7s_standarduser@x7sExp.com';
    public static final String STANDARD_EMAIL = 'x7s_standarduser@x7sExp.com';

    public static final String LASTNAME = 'x7s_Testing';
    public static final String FIRSTNAME = 'x7s_Name';

    public static final String LOCALE = 'en_US';
    public static final String TIMEZONE = 'America/Los_Angeles';

    public static final String ENCODING = 'utf-8';

    public static final String ACCOUNT_NAME = 'Test Account';

    public static final String TEST_MESSAGE = 'Test message';

    public static final String TEST_URL = 'http://7summitsinc.com';
    public static final String TEST_DESCRIPTION = 'Donec ac dolor nec libero sagittis facilisis quis vel mauris. Curabitur eu dignissim augue. Sed ut consequat purus. Curabitur porta eget leo a molestie.';

    public static final String TEST_GROUPNAME = 'Testing Group';

    public static final String TEST_GALLERYNAME = 'Testing Gallery';
    public static final String TEST_GALLERYENTRYNAME = 'Testing Gallery Entry';
    public static final Decimal TEST_GALLERYENTRYSORT1 = 1;
    public static final Decimal TEST_GALLERYENTRYSORT2 = 2;

    public static final Decimal AMOUNT = 500;
    public static final String STAGE_NAME = 'Sample Stage Name';
    public static final String OPP_NAME = 'Big Sale';

    public static final Date TODAY = System.today();
}