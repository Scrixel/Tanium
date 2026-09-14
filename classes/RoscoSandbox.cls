global class RoscoSandbox implements SandboxPostCopy {
	global void runApexClass(SandboxContext context) {
		System.debug('Org ID: ' + context.organizationId());
		System.debug('Sandbox ID: ' + context.sandboxId());
		System.debug('Sandbox Name: ' + context.sandboxName());

		List<String> emails = new List<String>();
		emails.add('jason.johnson@tanium.com.invalid');
		emails.add('roscosandbox@tanium.com.invalid');
		//emails.add('soa@tanium.com.invalid');
		//emails.add('melissa.travers@tanium.com.invalid');
		//emails.add('naureen.hameed@tanium.com.invalid');
		//emails.add('matt.machczynski@tanium.com.invalid');

		// Fix emails
		String soql = 'SELECT Id, Email ' + 'FROM User ' + 'WHERE Email in :emails';

		System.debug('SOQL: ' + soql);
		List<User> users = Database.query(soql);

		if (users.size() != 0) {
			for (User u : users) {
				String validEmail = u.Email.replace('.invalid', '');
				u.Email = validEmail;
				update u;
			}
		}
	}
}