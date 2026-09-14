/*
 * Copyright (c) 2026 Tanium
 *
 * @Business: Class for creaeting external (portal) users, support Catalyst Register Screen Flow
 * @Date: 2026-02-16
 * @Author: Tanium Dev Team
 * RequestId     ModifiedDate     Description
 * SS-13683      2026-09-07       Created the class
 */
public with sharing class CatalystExternalUserRegistration {
	private static final Integer NICKNAME_MAX_LENGTH = 40;

	@InvocableMethod(
		label='Create External (Portal) User'
		description='Creates an Experience Cloud user via Site.createExternalUser and sets the password in one step. Must be invoked from a flow exposed on a Force.com/Experience Cloud Site (e.g., a self-registration page).'
		category='User Management'
	)
	public static List<Response> createExternalUser(List<Request> requests) {
		List<Response> responses = new List<Response>();
		Response response;
		Savepoint savePoint;

		for (Request request : requests) {
			response = new Response();
			savePoint = Database.setSavepoint();

			User user = new User(
				FirstName = request.firstName,
				LastName = request.lastName,
				Email = request.email,
				Username = request.username,
				CommunityNickname = generateUniqueCommunityNickname(
					request.firstName,
					request.lastName,
					new Set<String>()
				),
				ProfileId = request.profileId,
				ContactId = request.contactId,
				Alias = generateAlias(request.firstName, request.lastName),
				TimeZoneSidKey = UserInfo.getTimeZone().getID(),
				LocaleSidKey = UserInfo.getLocale(),
				EmailEncodingKey = 'UTF-8',
				LanguageLocaleKey = UserInfo.getLocale()
			);

			if (request.contactId != null) {
				user.ContactId = request.contactId;
			}

			Boolean sendConfirmation = request.sendEmailConfirmation ?? request.sendEmailConfirmation;

			try {
				Id newUserId = Site.createExternalUser(
					user,
					request.accountId,
					request.password,
					sendConfirmation
				);

				response.userId = newUserId;
				response.isSuccess = (newUserId != null);
				if (newUserId == null) {
					response.errorMessage = 'Site.createExternalUser returned no Id. Confirm this flow is running in the context of a Force.com/Experience Cloud Site.';
				}
			} catch (Site.ExternalUserCreateException e) {
				Database.rollback(savePoint);
				response.isSuccess = false;
				response.errorMessage = String.join(e.getDisplayMessages(), '; ');
			} catch (Exception e) {
				Database.rollback(savePoint);
				response.isSuccess = false;
				response.errorMessage = e.getMessage();
			}
			responses.add(response);
		}
		return responses;
	}

	@TestVisible
	private static String generateAlias(String firstName, String lastName) {
		String base = ((firstName ?? '') + (lastName ?? '')).replaceAll('[^a-zA-Z0-9]', '');
		return base.length() > 8 ? base.substring(0, 8) : base;
	}

	@TestVisible
	private static String generateUniqueCommunityNickname(
		String firstName,
		String lastName,
		Set<String> reservedNicknames
	) {
		String base = buildNicknameBase(firstName, lastName);
		String likePattern = base + '%';
		Set<String> takenNicknames = new NicknameLookup().getTakenNicknames(likePattern);
		if (reservedNicknames != null) {
			takenNicknames.addAll(reservedNicknames);
		}
		String candidate = base;
		Integer suffix = 1;
		while (takenNicknames.contains(candidate.toLowerCase())) {
			String suffixString = String.valueOf(suffix);
			Integer allowedBaseLength = NICKNAME_MAX_LENGTH - suffixString.length();
			String truncatedBase = base.length() > allowedBaseLength
				? base.substring(0, allowedBaseLength)
				: base;
			candidate = truncatedBase + suffixString;
			suffix++;
		}
		return candidate;
	}

	@TestVisible
	private static String buildNicknameBase(String firstName, String lastName) {
		String raw =
			(String.isBlank(firstName) ? '' : firstName) + (String.isBlank(lastName) ? '' : lastName);
		String sanitized = raw.replaceAll('[^a-zA-Z0-9]', '').toLowerCase();
		if (String.isBlank(sanitized)) {
			sanitized = 'user';
		}
		return sanitized.length() > NICKNAME_MAX_LENGTH
			? sanitized.substring(0, NICKNAME_MAX_LENGTH)
			: sanitized;
	}

	private without sharing class NicknameLookup {
		private Set<String> getTakenNicknames(String likePattern) {
			Set<String> takenNicknames = new Set<String>();
			for (User user : [
				SELECT CommunityNickname
				FROM User
				WHERE CommunityNickname LIKE :likePattern
				LIMIT 2000
			]) {
				if (user.CommunityNickname != null) {
					takenNicknames.add(user.CommunityNickname.toLowerCase());
				}
			}
			return takenNicknames;
		}
	}

	public class Request {
		@InvocableVariable(required=true label='First Name')
		public String firstName;

		@InvocableVariable(required=true label='Last Name')
		public String lastName;

		@InvocableVariable(required=true label='Email')
		public String email;

		@InvocableVariable(required=true label='Username')
		public String username;

		@InvocableVariable(required=true label='Profile Id')
		public Id profileId;

		@InvocableVariable(required=true label='Account Id')
		public Id accountId;

		@InvocableVariable(
			label='Contact Id (optional; leave blank to let Salesforce match/create a Contact by email under Account Id)'
		)
		public Id contactId;

		@InvocableVariable(required=true label='Password')
		public String password;

		@InvocableVariable(label='Send New User Confirmation Email (default false)')
		public Boolean sendEmailConfirmation;

		@InvocableVariable(label='Alias (optional, auto-generated if blank)')
		public String alias;
	}

	public class Response {
		@InvocableVariable
		public Id userId;

		@InvocableVariable
		public Boolean isSuccess;

		@InvocableVariable
		public String errorMessage;
	}
}