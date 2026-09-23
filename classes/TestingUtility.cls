public with sharing class TestingUtility {
	public static void assignCustomPermission(Id userId, String permissionName) {
		PermissionSet permissionSet = new PermissionSet(
			Name = permissionName + '_Enabled',
			Label = permissionName + '_Enabled'
		);
		insert permissionSet;

		SetupEntityAccess setupEntity = new SetupEntityAccess(
			ParentId = permissionSet.Id,
			SetupEntityId = [
				SELECT Id
				FROM CustomPermission
				WHERE DeveloperName = :permissionName
				LIMIT 1
			]
			.Id
		);

		PermissionSetAssignment permissionSetAssignment = new PermissionSetAssignment(
			AssigneeId = userId,
			PermissionSetId = permissionSet.Id
		);

		insert new List<SObject>{ setupEntity, permissionSetAssignment };
	}

	public static void assignPermissionSet(Id userId, String permissionSetName) {
		insert new PermissionSetAssignment(
			AssigneeId = userId,
			PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = :permissionSetName LIMIT 1]
			.Id
		);
	}

	public static void removePermissionSet(Id userId, String permissionSetName) {
		PermissionSetAssignment psa = [
			SELECT Id
			FROM PermissionSetAssignment
			WHERE AssigneeId = :userId AND PermissionSet.Name = :permissionSetName
		];
		delete psa;
	}

	public static void assignPermSetLicense(Id userId, String permissionSetLicenseName) {
		insert new PermissionSetLicenseAssign(
			AssigneeId = userId,
			PermissionSetLicenseId = [
				SELECT Id
				FROM PermissionSetLicense
				WHERE DeveloperName = :permissionSetLicenseName
				LIMIT 1
			]
			.Id
		);
	}

	public static void assignPackageLicense(Id userId, String packageLicenseNamespace) {
		insert new UserPackageLicense(
			UserId = userId,
			PackageLicenseId = [
				SELECT Id
				FROM PackageLicense
				WHERE NamespacePrefix = :packageLicenseNamespace
				LIMIT 1
			]
			.Id
		);
	}

	public static void removePackageLicense(Id userId, String packageLicenseNamespace) {
		UserPackageLicense packageLicense = [
			SELECT Id
			FROM UserPackageLicense
			WHERE PackageLicense.NamespacePrefix = :packageLicenseNamespace AND UserId = :userId
		];
		delete packageLicense;
	}
}