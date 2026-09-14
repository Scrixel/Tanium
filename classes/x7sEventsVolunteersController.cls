/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */
/**
 * @description This class is used to handle event volunteer operations
 */
public with sharing class x7sEventsVolunteersController {
	/**
	 * @description Used to get details of the logged in user
	 * @return User details
	 */
	@AuraEnabled
	public static User getCurrentUser() {
		try {
			return [
				SELECT Id, SmallPhotoUrl, UserType
				FROM User
				WHERE Id = :UserInfo.getUserId()
				WITH SECURITY_ENFORCED
			];
		} catch (Exception e) {
			throw new AurahandledException(e.getMessage());
		}
	}

	/**
	 * @description Get Event volunteer needs, All methods with just event ID to allow for running within current user context
	 * @param eventIdString Event Id
	 * @return List of x7sEventsVolunteerWrapper
	 */
	@AuraEnabled
	public static List<x7sEventsVolunteerWrapper> getEventVolunteerNeeds(String eventIdString) {
		try {
			return getEventVolunteerNeeds(Id.valueOf(eventIdString), UserInfo.getUserId());
		} catch (Exception e) {
			throw new AurahandledException(e.getMessage());
		}
	}

	/**
	 * @description Used to register a volunteer
	 * @param needId Volunteer Need Id
	 * @return Register or not
	 */
	@AuraEnabled
	public static Boolean registerVolunteerSingle(String needId) {
		try {
			return registerVolunteer(Id.valueOf(needId), UserInfo.getUserId());
		} catch (Exception e) {
			throw new AurahandledException(e.getMessage());
		}
	}

	// Hm, why doesn't signature overloading work from Lightning component...
	//had to change this to removeVolunteerSingle even though getEventVolunteerNeeds overload works!
	@AuraEnabled
	public static Boolean removeVolunteerSingle(String needId) {
		try {
			return removeVolunteer(Id.valueOf(needId), UserInfo.getUserId());
		} catch (Exception e) {
			throw new AurahandledException(e.getMessage());
		}
	}

	/**
	 * @description Get volunteer needs and sub-row of registrants for an Event
	 * @param eventId Event Id
	 * @param userId User Id
	 * @return List of x7sEventsVolunteerWrapper
	 */
	@AuraEnabled
	public static List<x7sEventsVolunteerWrapper> getEventVolunteerNeeds(Id eventId, Id userId) {
		// Set up wrapper list
		List<x7sEventsVolunteerWrapper> wrapperList = new List<x7sEventsVolunteerWrapper>();

		try {
			// Query volunteer needs and assign to wrapper
			List<X7S_Events_Volunteer_Need__c> volunteerNeeds = [
				SELECT
					Event__c,
					Event__r.Volunteer_Description__c,
					Criteria__c,
					Id,
					Name,
					Volunteers_Needed__c,
					Volunteers_Registered__c,
					(
						SELECT User__r.Id, User__r.SmallPhotoUrl, User__r.Name
						FROM X7S_Events_Volunteer_Registrations__r
					)
				FROM X7S_Events_Volunteer_Need__c
				WHERE Event__c = :eventId
				WITH SECURITY_ENFORCED
			];

			// For each volunteer need, create wrapper and assign to wrapper list
			for (X7S_Events_Volunteer_Need__c need : volunteerNeeds) {
				// Set up wrapper, assign current need to this wrapper, default registered to false
				x7sEventsVolunteerWrapper wrapper = new x7sEventsVolunteerWrapper();
				wrapper.volunteerNeed = need;
				wrapper.currentUserRegistered = false;

				// Check if user is in list of registrations
				for (
					X7S_Events_Volunteer_Registration__c registration : need.X7S_Events_Volunteer_Registrations__r
				) {
					// User is in the list, break it!
					if (registration.User__r.Id == userId) {
						wrapper.currentUserRegistered = true;
						break;
					}
				}

				wrapperList.add(wrapper);
			}
		} catch (Exception e) {
			System.debug(
				'getEventVolunteerNeeds() : ' +
				e.getMessage() +
				' line number: ' +
				e.getLineNumber()
			);
			throw new AurahandledException(e.getMessage());
		}

		return wrapperList;
	}

	// Register a user for a volunteer need
	@AuraEnabled
	public static Boolean registerVolunteer(Id needId, Id userId) {
		if (!X7S_Events_Volunteer_Registration__c.SObjectType.getDescribe().isCreateable()) {
			System.debug('registerVolunteer(): unable to create X7S_Events_Volunteer_Registration__c');
			return false;
		}

		// Track success
		Boolean success = true;

		// Build registration from need and user IDs
		X7S_Events_Volunteer_Registration__c newRegistration = new X7S_Events_Volunteer_Registration__c(
			Volunteer_Need__c = needId,
			User__c = userId
		);

		try {
			insert newRegistration;
		} catch (Exception e) {
			success = false;
			System.debug(e.getMessage());
			throw new AurahandledException(e.getMessage());
		}

		return success;
	}

	// Register a user for a volunteer need
	@AuraEnabled
	public static Boolean removeVolunteer(Id needId, Id userId) {
		if (!X7S_Events_Volunteer_Registration__c.SObjectType.getDescribe().isDeletable()) {
			System.debug('registerVolunteer(): unable to delete X7S_Events_Volunteer_Registration__c');
			return false;
		}

		// Track success
		Boolean success = true;

		// Find the need in question (in theory there'd only ever be one, but in case multiple were created, remove 'em all!
		List<X7S_Events_Volunteer_Registration__c> registrationsToRemove = [
			SELECT Id
			FROM X7S_Events_Volunteer_Registration__c
			WHERE Volunteer_Need__c = :needId AND User__c = :userId
		];

		try {
			delete registrationsToRemove;
		} catch (Exception e) {
			success = false;
			System.debug(e.getMessage());
			throw new AurahandledException(e.getMessage());
		}

		return success;
	}

	// Create volunteer needs
	@AuraEnabled
	public static List<String> createVolunteerNeeds(
		X7S_Event__c event,
		List<X7S_Events_Volunteer_Need__c> volunteerNeeds,
		List<X7S_Events_Volunteer_Need__c> needsToRemove
	) {
		// Handle errors
		List<String> errors = new List<String>();

		if (
			!X7S_Events_Volunteer_Need__c.SObjectType.getDescribe().isCreateable() ||
			!X7S_Events_Volunteer_Need__c.SObjectType.getDescribe().isUpdateable() ||
			!X7S_Events_Volunteer_Need__c.SObjectType.getDescribe().isDeletable() ||
			!X7S_Event__c.SObjectType.getDescribe().isUpdateable()
		) {
			System.debug(
				'createVolunteerNeeds(): X7S_Events_Volunteer_Need__c access error.  isCreateable: ' +
				X7S_Events_Volunteer_Need__c.SObjectType.getDescribe().isCreateable() +
				' isUpdateable: ' +
				X7S_Events_Volunteer_Need__c.SObjectType.getDescribe().isUpdateable() +
				' isDeletable: ' +
				X7S_Events_Volunteer_Need__c.SObjectType.getDescribe().isDeletable() +
				'Event isUpdateble:' +
				X7S_Event__c.SObjectType.getDescribe().isUpdateable()
			);

			errors.add('Access error.  X7S_Events_Volunteer_Need__c');

			return errors;
		}

		Savepoint savepoint = Database.setSavepoint();

		// Update the event - it already exists, so no upsert. We're only changing it's Volunteer Needs description field
		try {
			update event;
		} catch (Exception e) {
			errors.add(e.getMessage());
			throw new AurahandledException(e.getMessage());
		}

		// Two lists of Volunteer needs - one for insert and one for update since upsert is not available
		List<X7S_Events_Volunteer_Need__c> needsToUpdate = new List<X7S_Events_Volunteer_Need__c>();
		List<X7S_Events_Volunteer_Need__c> needsToInsert = new List<X7S_Events_Volunteer_Need__c>();

		// If Need has an ID, it exists and we should update it. Otherwise it's new and we should insert it
		for (X7S_Events_Volunteer_Need__c volunteerNeed : volunteerNeeds) {
			if (volunteerNeed.Id == null) {
				needsToInsert.add(volunteerNeed);
			} else {
				needsToUpdate.add(volunteerNeed);
			}
		}

		// Now for each individual needs
		try {
			insert needsToInsert;
			update needsToUpdate;
			delete needsToRemove;
		} catch (Exception e) {
			errors.add(e.getMessage());
			// That didn't work.
		}

		// If there were errors, roll back DB
		if (!errors.isEmpty()) {
			Database.rollback(savepoint);
		}

		return errors;
	}

	@AuraEnabled
	public static X7S_Event__c initVolunteerNeeds(String eventIdString) {
		X7S_Event__c eventItem;
		try {
			// Get event(s) and volunteer needs for event Id
			List<X7S_Event__c> events = [
				SELECT
					Id,
					Volunteer_Description__c,
					(SELECT Name, Id, Criteria__c, Volunteers_Needed__c FROM X7S_Events_Volunteer_Needs__r)
				FROM X7S_Event__c
				WHERE Id = :Id.valueOf(eventIdString)
				WITH SECURITY_ENFORCED
			];

			// If it's found
			if (!events.isEmpty()) {
				eventItem = events[0];
			}
		} catch (Exception e) {
			System.debug(
				'initVolunteerNeeds(): ' +
				e.getMessage() +
				' line number: ' +
				e.getLineNumber()
			);
			throw new AurahandledException(e.getMessage());
		}

		// Default to nothing
		return eventItem;
	}
}