public class CustomAssetNew {
	public string accountId = Apexpages.currentPage().getParameters().get('acc_id');

	public List<ProductWrapper> lstProductWrapper { get; set; }
	public Boolean isSelectedChkbx { get; set; }
	public String strQty { get; set; }
	public String isAuthorized { get; set; }
	public String accID { get; set; }
	private final Asset a;

	// The extension constructor initializes the private member
	// variable mysObject by using the getRecord method from the standard
	// controller.
	public CustomAssetNew(ApexPages.StandardController stdController) {
		accID = accountId;
		if (isAuthorized()) {
			a = (Asset) stdController.getRecord();
			List<Product_Type__c> listProductTypes = new List<Product_Type__c>();
			listProductTypes = Product_Type__c.getAll().values();
			listProductTypes.sort();
			system.debug('listProductTypes ::: ' + listProductTypes);

			ProductWrapper tempProductWrapper;
			lstProductWrapper = new List<ProductWrapper>();

			for (Product_Type__c loopVarProducts : listProductTypes) {
				tempProductWrapper = new ProductWrapper(loopVarProducts);
				lstProductWrapper.add(tempProductWrapper);
			}
			system.debug('lstProductWrapper ::: ' + lstProductWrapper);
			//lstProductWrapper.sort();
			system.debug('After sort lstProductWrapper ::: ' + lstProductWrapper);
		}
	}

	public Boolean isAuthorized() {
		//getting profileName from user.
		String profileName = [SELECT Profile.Name FROM User WHERE id = :UserInfo.getUserId()]
		.Profile.Name;
		//getting the permission which profile has on object asset
		List<ObjectPermissions> objPermission = [
			SELECT Id, SObjectType, PermissionsRead, PermissionsCreate
			FROM ObjectPermissions
			WHERE
				parentid IN (SELECT id FROM permissionset WHERE PermissionSet.Profile.Name = :profileName)
				AND SObjectType = 'Asset'
		];
		if (objPermission != null) {
			for (ObjectPermissions objP : objPermission) {
				//if user has permission to create on asset=>user is authorized.
				if (objP.PermissionsCreate == true) {
					isAuthorized = 'True';
					return true;
				}
			}
			isAuthorized = 'False';
			return false;
		} else {
			isAuthorized = 'False';
			return false;
		}
	}
	public String getRecordName() {
		return 'Hello ' + (String) a.get('name') + ' (' + (Id) a.get('Id') + ')';
	}

	private void insertAssets(List<ProductWrapper> insertProductAssetRecords) {
		system.debug('Quantity: ' + strQty);
		system.debug('Quantity: ' + decimal.ValueOf(strQty));
		List<Asset> lstNewAssets = new List<Asset>();

		for (ProductWrapper x : insertProductAssetRecords) {
			Asset newAsset = new Asset();
			newAsset.AccountId = accountId;
			newAsset.Name = x.theProduct.Name;
			//newAsset.Quantity = decimal.ValueOf(strQty);
			newAsset.Quantity__c = decimal.ValueOf(strQty);
			lstNewAssets.add(newAsset);
		}
		if (!lstNewAssets.isEmpty()) {
			insert lstNewAssets;
		}
	}

	public PageReference save() {
		if (String.isNotBlank(strQty) && Integer.valueOf(strQty) > 0) {
			//string ex = 'You must input a quantity in order to add new assets.';
			if (accountId != null) {
				List<ProductWrapper> insertProductAssetRecords = new List<ProductWrapper>();
				isSelectedChkbx = false;
				// List of records selected on page
				for (ProductWrapper loopVarProducts : lstProductWrapper) {
					if (loopVarProducts.selected == true) {
						insertProductAssetRecords.add(loopVarProducts);
						isSelectedChkbx = true;
					}
				}
				system.debug('insertProductAssetRecords ' + insertProductAssetRecords);
				if (insertProductAssetRecords != null && !insertProductAssetRecords.isEmpty()) {
					insertAssets(insertProductAssetRecords);
					isSelectedChkbx = true;
				} else {
					isSelectedChkbx = false;
					//no asset selected=>present error message
					ApexPages.addMessage(
						new ApexPages.Message(ApexPages.severity.ERROR, 'Please Select At Least One Asset.')
					);
					return null;
				}
				System.debug('isSelectedChkbx ::: ' + isSelectedChkbx);
			}
		} else {
			ApexPages.addMessage(
				new ApexPages.Message(
					ApexPages.severity.ERROR,
					'You must input a quantity in order to add new assets.'
				)
			);
			return null;
		}
		return new PageReference('/' + accountId);
	}

	public class ProductWrapper {
		public Product_Type__c theProduct { get; set; }
		public Boolean selected { get; set; }

		public ProductWrapper(Product_Type__c theProduct) {
			this.theProduct = theProduct;
			this.selected = false;
		}
	}
}