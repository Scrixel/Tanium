global class ConstellantAppPlugin extends Auth.ConnectedAppPlugin {
	@TestVisible
	private static final Id PARTNER_RECORD_TYPE_ID = Utility.getRecordTypeIdByAPIName(
		'Account',
		'Partner'
	);
	@TestVisible
	private static final List<String> CUSTOMER_ACCOUNT_TYPES = new List<String>{ 'Customer' };
	@TestVisible
	private static final String USER_WITHOUT_CONTACT = 'User does not have an associated Contact Id';
	@TestVisible
	private static final String ACCOUNT_NOT_PARTNER_OR_CUSTOMER = 'User account is neither Customer nor Partner';

	global override Map<String, String> customAttributes(
		Id userId,
		Id connectedAppId,
		Map<String, String> formulaDefinedAttributes,
		Auth.InvocationContext context
	) {
		User currentUser = [
			SELECT
				FirstName,
				LastName,
				CommunityNickname,
				ContactId,
				Contact.Account.Name,
				Contact.Account.Description,
				Contact.Account.BillingCity,
				Contact.Account.BillingCountry,
				Contact.Account.BillingPostalCode,
				Contact.Account.BillingState,
				Contact.Account.BillingStreet,
				Contact.Account.RecordTypeId,
				Contact.Account.Type,
				Contact.Account.Website
			FROM User
			WHERE Id = :userId
		];

		if (currentUser.ContactId == null) {
			throw new SObjectException(USER_WITHOUT_CONTACT);
		}

		String nickName = currentUser.CommunityNickname.replaceAll('[\\\\+%?\\s]', '');

		Map<String, String> requiredAttributes = new Map<String, String>{
			'firstName' => currentUser.FirstName,
			'lastName' => currentUser.LastName,
			'nickname' => (nickName.length() < 8)
				? Utility.truncateString(nickName + '00000000', 8)
				: Utility.truncateString(nickName, 30),
			'companyName' => Utility.safeString(currentUser.Contact.Account.Name),
			'companyDescription' => Utility.safeString(currentUser.Contact.Account.Description),
			'companyURL' => Utility.addProtocolToURL(currentUser.Contact.Account.Website),
			'companyAddress' => Utility.safeString(currentUser.Contact.Account.BillingStreet),
			'companyCity' => Utility.safeString(currentUser.Contact.Account.BillingCity),
			'companyState' => Utility.safeString(currentUser.Contact.Account.BillingState),
			'companyZip' => Utility.safeString(currentUser.Contact.Account.BillingPostalCode),
			'companyCountry' => Utility.safeString(currentUser.Contact.Account.BillingCountry)
		};

		if (currentUser.Contact.Account.RecordTypeId == PARTNER_RECORD_TYPE_ID) {
			requiredAttributes.put('accountType', 'Partner');
		} else if (CUSTOMER_ACCOUNT_TYPES.contains(currentUser.Contact.Account.Type)) {
			requiredAttributes.put('accountType', 'Customer');
		} else {
			throw new SObjectException(ACCOUNT_NOT_PARTNER_OR_CUSTOMER);
		}
		return requiredAttributes;
	}
}