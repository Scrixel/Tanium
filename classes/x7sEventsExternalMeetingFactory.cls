/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sEventsExternalMeetingFactory {
	public static x7sEventsIExternalMeeting getExternalMeeting(X7S_Event__c event) {
		x7sEventsIExternalMeeting externalMeeting = null;

		X7S_Event_Integration_Setting__mdt integrationSetting = X7S_Event_Integration_Setting__mdt.getInstance(
			event.Event_Format__c
		);

		if (
			integrationSetting != null &&
			integrationSetting.Virtual_Platform__c == x7sEventsExternalMeetingConstants.ZOOM
		) {
			externalMeeting = new x7sEventsExternalMeetingZoom();
		} else {
			System.debug('Defaulting to Default External Meeting Interface.');
			externalMeeting = new x7sEventsExternalMeetingDefault();
		}

		return externalMeeting;
	}
}