/*
 * Copyright (c) 2026 Tanium
 *
 * @Business: Class for reactivating external (portal) users, support Catalyst Register Screen Flow
 * @Date: 2026-02-16
 * @Author: Tanium Dev Team
 * RequestId     ModifiedDate     Description
 * SS-13683      2026-09-07       Created the class
 */

public with sharing class CatalystUserReactivation {
	@InvocableMethod(
		label='Reactivate User'
		description='Sets IsActive = true on the given User. No-ops (reports success) if already active. Reports errors (e.g. no available license) instead of throwing. See class comments for a Mixed DML caveat.'
		category='User Management'
	)
	public static List<Response> reactivateUsers(List<Request> requests) {
		Set<Id> userIds = new Set<Id>();
		for (Request request : requests) {
			if (request.userId != null) {
				userIds.add(request.userId);
			}
		}

		Map<Id, User> inactiveUserMap = new Map<Id, User>(
			[
				SELECT Id, IsActive
				FROM User
				WHERE Id IN :userIds AND IsActive = FALSE
			]
		);

		List<User> usersToUpdate = new List<User>();

		for (Id userId : userIds) {
			if (inactiveUserMap.containsKey(userId)) {
				usersToUpdate.add(new User(Id = userId, IsActive = true));
			}
		}

		if (usersToUpdate.isEmpty()) {
			return new List<Response>{ new Response(false, 'No valid user IDs provided.') };
		}

		List<Response> responses = new List<Response>();
		List<Database.SaveResult> saveResults = Database.update(usersToUpdate, false);
		for (Database.SaveResult saveResult : saveResults) {
			if (saveResult.isSuccess()) {
				responses.add(new Response(true));
			} else {
				responses.add(new Response(false, describeErrors(saveResult)));
			}
		}
		return responses;
	}

	@TestVisible
	private static String describeErrors(Database.SaveResult saveResult) {
		if (saveResult == null) {
			return 'Unknown error reactivating user.';
		}
		List<String> errors = new List<String>();
		for (Database.Error error : saveResult.getErrors()) {
			errors.add(error.getStatusCode() + ': ' + error.getMessage());
		}
		return errors.isEmpty() ? 'Unknown error reactivating user.' : String.join(errors, '; ');
	}

	public class Request {
		@InvocableVariable(required=true label='User Id')
		public Id userId;
	}

	public class Response {
		@InvocableVariable
		public Boolean isSuccess;

		@InvocableVariable
		public String errorMessage;

		public Response(Boolean isSuccess) {
			this.isSuccess = isSuccess;
		}

		public Response(Boolean isSuccess, String errorMessage) {
			this.isSuccess = isSuccess;
			this.errorMessage = errorMessage;
		}
	}
}