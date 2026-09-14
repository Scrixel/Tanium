/*
 *    Name        :   CustomAssetEdit
 *    Date        :   22 May, 2015
 *    Author      :   Sochettra
 *    Description :   Change 'Add New Asset to 'Edit Assets'
 *					 Change Save Functionality as follows:
 *        				For every checkbox selected, lookup all assets with related name, update quantity to new quantity and insert new assets
 *        			which names don't exist matching the Checkbox product name = Asset.Name.
 *
 */

public class CustomAssetEdit {
	public string accountId = Apexpages.currentPage().getParameters().get('retURL').replace('/', '');

	public List<ProductWrapper> lstProductWrapper { get; set; }
	public Boolean isSelectedChkbx { get; set; }
	public String strQty { get; set; }
	public String isAuthorized { get; set; }
	public String accID { get; set; }

	// creste set for store contains Asset Name
	private Set<String> assetName = new Set<String>();
	private final Asset a;

	// The extension constructor initializes the private member
	// variable mysObject by using the getRecord method from the standard
	// controller.
	public CustomAssetEdit(ApexPages.StandardController stdController) {
		system.debug('>>>> isAuthorized' + isAuthorized());
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
		} else {
			//show error message + redirect to Account Page
		}
	}

	public Boolean isAuthorized() {
		String profileName = [SELECT Profile.Name FROM User WHERE id = :UserInfo.getUserId()]
		.Profile.Name;

		List<ObjectPermissions> objPermission = [
			SELECT Id, SObjectType, PermissionsRead, PermissionsCreate
			FROM ObjectPermissions
			WHERE
				parentid IN (SELECT id FROM permissionset WHERE PermissionSet.Profile.Name = :profileName)
				AND SObjectType = 'Asset'
		];
		if (objPermission != null) {
			for (ObjectPermissions objP : objPermission) {
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

	// method for update quantity old Asset.
	private List<Asset> oldAsset(String acId) {
		List<Asset> lsAsset = new List<Asset>();
		for (Asset s : [SELECT Id, Name, Quantity__c, AccountId FROM Asset WHERE AccountId = :acId]) {
			s.Quantity__c = decimal.valueOf(strQty);
			lsAsset.add(s);
			assetName.add(s.Name);
		}
		return lsAsset;
	}

	private void upsertAssets(List<ProductWrapper> insertProductAssetRecords) {
		system.debug('Quantity: ' + strQty);
		system.debug('Quantity: ' + decimal.ValueOf(strQty));

		List<Asset> lstAllAsset = new List<Asset>();
		List<Asset> lstNewAssets = new List<Asset>();

		if (String.isNotBlank(accountId)) {
			lstAllAsset.addAll(oldAsset(accountId));
		}

		for (ProductWrapper x : insertProductAssetRecords) {
			if (!assetName.contains(x.theProduct.Name)) {
				Asset newAsset = new Asset();
				newAsset.AccountId = accountId;
				newAsset.Name = x.theProduct.Name;
				//newAsset.Quantity = decimal.ValueOf(strQty);
				newAsset.Quantity__c = decimal.ValueOf(strQty);
				lstNewAssets.add(newAsset);
			}
		}

		if (!lstNewAssets.isEmpty()) {
			lstAllAsset.addAll(lstNewAssets);
		}
		if (!lstAllAsset.isEmpty()) {
			upsert lstAllAsset;
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
					upsertAssets(insertProductAssetRecords);
					isSelectedChkbx = true;
				} else {
					// update quantity old Asset
					List<Asset> lstUpsertAsset = new List<Asset>();
					lstUpsertAsset = oldAsset(accountId);
					isSelectedChkbx = false;
					upsert lstUpsertAsset;
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