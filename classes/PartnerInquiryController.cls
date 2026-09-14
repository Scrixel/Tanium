/**
 * @Business: Controller class for the PartnerInquiry page
 * @Authors: Cumulus Vision, Tanium Dev team
 * RequestId  	ModifiedDate   	Description
 * TAN-855   	2020-03-17     	Initial development
 * SS-7043		2024-02-08		Added method setCaptchaKeyValue
 * SS-9959   	2025-01-11     	Added validation on First Name, Last Name and Address fields
 */
public class PartnerInquiryController {
	public Partner_Inquiry__c newPartnerInquiry { get; set; }
	public Boolean isRecordCreated { get; private set; }
	public String isPrimaryPartnerContact { get; set; }
	public Boolean showPrimaryContactInfo { get; set; }
	public String isOutSourcing { get; set; }
	public Boolean showOutSourcingInfo { get; set; }
	public String isGovTiesDirector { get; set; }
	public Boolean showGovTiesDirector { get; set; }
	public String isGovRelationDirector { get; set; }
	public Boolean showGovRelationDirector { get; set; }
	public String isDisciplinedDirector { get; set; }
	public Boolean showDisciplinedDirector { get; set; }
	public String isCorruptDirector { get; set; }
	public Boolean showCorruptDirector { get; set; }
	public String isConvictedDirector { get; set; }
	public Boolean showConvictedDirector { get; set; }
	public String captchaKeyValue { get; set; }

	public List<SelectOption> yesNoNoneList { get; set; }

	public PartnerInquiryController() {
		isRecordCreated = false;
		showPrimaryContactInfo = false;
		showOutSourcingInfo = false;
		showGovTiesDirector = false;
		showGovRelationDirector = false;
		showDisciplinedDirector = false;
		showCorruptDirector = false;
		showConvictedDirector = false;
		newPartnerInquiry = new Partner_Inquiry__c();
		yesNoNoneList = new List<SelectOption>();
		yesNoNoneList.add(new SelectOption('', '--None--'));
		yesNoNoneList.add(new SelectOption('Yes', 'Yes'));
		yesNoNoneList.add(new SelectOption('No', 'No'));
		setCaptchaKeyValue();
	}

	public PageReference savePartnerInquiry() {
		newPartnerInquiry.Partner_Primary_Point_of_Contact__c = isPrimaryPartnerContact == 'Yes'
			? true
			: false;
		newPartnerInquiry.Partner_Plans_To_Outsource__c = isOutSourcing == 'Yes' ? true : false;
		newPartnerInquiry.Government_Ties_Director__c = isGovTiesDirector == 'Yes' ? true : false;
		newPartnerInquiry.Company_director_has_gov_relation__c = isGovRelationDirector == 'Yes'
			? true
			: false;
		newPartnerInquiry.Director_Disciplined_for_Misconduct__c = isDisciplinedDirector == 'Yes'
			? true
			: false;
		newPartnerInquiry.Director_Bribery_Fraud_Corrupt__c = isCorruptDirector == 'Yes' ? true : false;
		newPartnerInquiry.Director_Convicted_of_Crime__c = isConvictedDirector == 'Yes' ? true : false;
		try {
			if (isNameAndAdressValuesValid(newPartnerInquiry)) {
				insert newPartnerInquiry;
				isRecordCreated = true;
			} else {
				ApexPages.addMessage(
					new ApexPages.Message(
						ApexPages.Severity.Error,
						'The following fields should only contain alphanumeric, comma and period characters: First Name, Last Name, Street Address 1, Street Address 2, Street Address 3, City and State/Province'
					)
				);
			}
		} catch (Exception ex) {
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Error, ex.getMessage()));
		}
		return null;
	}

	public PageReference showEmailValidationError() {
		ApexPages.addMessage(new ApexPages.Message(Apexpages.Severity.ERROR, 'Email is not valid'));
		return null;
	}

	public PageReference renderPrimaryContactInfo() {
		showPrimaryContactInfo = (isPrimaryPartnerContact == 'No') ? true : false;
		return null;
	}

	public PageReference renderOutSourcingInfo() {
		showOutSourcingInfo = (isOutSourcing == 'Yes') ? true : false;
		return null;
	}

	public PageReference renderGovTiesDirectorInfo() {
		showGovTiesDirector = (isGovTiesDirector == 'Yes') ? true : false;
		return null;
	}

	public PageReference renderGovRelationDirectorInfo() {
		showGovRelationDirector = (isGovRelationDirector == 'Yes') ? true : false;
		return null;
	}

	public PageReference renderDisciplinedDirectorInfo() {
		showDisciplinedDirector = (isDisciplinedDirector == 'Yes') ? true : false;
		return null;
	}

	public PageReference renderCorruptDirectorInfo() {
		showCorruptDirector = (isCorruptDirector == 'Yes') ? true : false;
		return null;
	}

	public PageReference renderConvictedDirectorInfo() {
		showConvictedDirector = (isConvictedDirector == 'Yes') ? true : false;
		return null;
	}

	public void setCaptchaKeyValue() {
		Boolean isSandbox = Utility.isSandbox();
		String instance = Utility.getInstance(Url.getOrgDomainURL());
		String captchaKeyValue;

		for (Instance_Setting__mdt instanceSetting : Instance_Setting__mdt.getAll().values()) {
			if (
				instanceSetting.IsActive__c &&
				instanceSetting.Instance__c == instance &&
				instanceSetting.Type__c == 'PartnerInquiryCaptchaKey' &&
				instanceSetting.IsSandbox__c == isSandbox
			) {
				this.captchaKeyValue = instanceSetting.Value__c;
			}
		}
	}

	public static Boolean isNameAndAdressValuesValid(Partner_Inquiry__c partnerInquiry) {
		Boolean isValid = true;
		String alphanumericAndSpecialChars = '^[a-zA-Z0-9., ]+$';
		String urlPattern = '^(https?:\\/\\/|www\\.)[	\\w.-]+';

		if (
			(!Pattern.matches(alphanumericAndSpecialChars, partnerInquiry?.First_Name__c) ||
			Pattern.matches(urlPattern, partnerInquiry?.First_Name__c)) ||
			(!Pattern.matches(alphanumericAndSpecialChars, partnerInquiry?.Last_Name__c) ||
			Pattern.matches(urlPattern, partnerInquiry?.Last_Name__c)) ||
			(!Pattern.matches(alphanumericAndSpecialChars, partnerInquiry?.Street_Address_1__c) ||
			Pattern.matches(urlPattern, partnerInquiry?.Street_Address_1__c)) ||
			(partnerInquiry.Street_Address_2__c != null &&
			(!Pattern.matches(alphanumericAndSpecialChars, partnerInquiry?.Street_Address_2__c) ||
			Pattern.matches(urlPattern, partnerInquiry?.Street_Address_2__c))) ||
			(partnerInquiry.Street_Address_3__c != null &&
			(!Pattern.matches(alphanumericAndSpecialChars, partnerInquiry?.Street_Address_3__c) ||
			Pattern.matches(urlPattern, partnerInquiry?.Street_Address_3__c))) ||
			(partnerInquiry.Province__c != null &&
			(!Pattern.matches(alphanumericAndSpecialChars, partnerInquiry?.Province__c) ||
			Pattern.matches(urlPattern, partnerInquiry?.Province__c))) ||
			(!Pattern.matches(alphanumericAndSpecialChars, partnerInquiry?.City__c) ||
			Pattern.matches(urlPattern, partnerInquiry?.City__c))
		) {
			isValid = false;
		}
		return isValid;
	}
}