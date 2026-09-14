/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

@IsTest
private class x7sEventsRsvpModelListTest {
	@IsTest
	static void testBehavior() {
		x7sEventsRsvpModelList model = new x7sEventsRsvpModelList();
		System.assertNotEquals(null, model.records);
	}

	@IsTest
	static void testGetByEmail() {
		x7sEventsRsvpModelList model = new x7sEventsRsvpModelList();
		x7sEventsRsvpModel item = new x7sEventsRsvpModel('1');
		item.email = 'x7s_test@email.com';
		item.userId = '';
		item.userType = '';
		item.company = '';
		item.joinUrl = '';
		item.lastName = '';
		item.firstName = '';
		item.registrantId = '';
		item.registrationDate = String.valueOfGmt(Datetime.now());
		item.attendeeJoin = String.valueOf(Datetime.now());
		item.attendeeLeave = String.valueOf(Datetime.now().addMinutes(6));
		item.attendeeDuration = '4';
		item.registrationStatus = 'Attending';
		item.eventId = '12345';

		model.addRsvp(item);

		x7sEventsRsvpModel found = model.findByEmail('x7s_test@email.com', item.eventId);
		System.assertNotEquals(null, found, 'Expecting to find the model that was just inserted.');
		model.dump('test');
		System.assertEquals('6', found.attendeeDuration, 'Expecting to get the correct duration');

		item.attendeeJoin = String.valueOf(Datetime.now());
		item.attendeeLeave = String.valueOf(Datetime.now().addMinutes(6));
		model.addRsvp(item);
		found = model.findByEmail('x7s_test@email.com', item.eventId);
		System.assertEquals('12', found.attendeeDuration);
	}

	@IsTest
	static void testGetDurationMinutes() {
		String startString = '2021-04-09 20:52:20';
		String endString = '2021-04-09 20:58:51';

		Long durationMinutes = x7sEventsRsvpModelList.getDurationMinutesRoundedUp(
			startString,
			endString
		);
		System.assertEquals(7, durationMinutes);

		System.assertEquals(7, x7sEventsRsvpModelList.getMinutes(String.valueOf(7 * 60)));
	}
}