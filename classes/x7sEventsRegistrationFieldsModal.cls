/*
 * Licensed Materials - Property of IBM
 * 6949-82P
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public with sharing class x7sEventsRegistrationFieldsModal {
	@AuraEnabled
	public String apiName { get; set; }

	@AuraEnabled
	public String label { get; set; }

	@AuraEnabled
	public String fieldType { get; set; }

	@AuraEnabled
	public String fieldToolTip { get; set; }

	@AuraEnabled
	public Boolean fieldRequired { get; set; }

	@AuraEnabled
	public List<String> pickValues { get; set; }

	public x7sEventsRegistrationFieldsModal() {
		this.apiName = '';
		this.label = '';
		this.fieldType = 'text';
		this.fieldToolTip = '';
		this.pickValues = new List<String>();
		this.fieldRequired = false;
	}

	public x7sEventsRegistrationFieldsModal(
		String apiName,
		String label,
		String fieldType,
		String fieldToolTip,
		Boolean fieldRequired,
		List<String> pickValues
	) {
		this.apiName = String.isNotBlank(apiName) ? apiName : '';
		this.label = String.isNotBlank(label) ? label : '';
		this.fieldType = String.isNotBlank(fieldType) ? fieldType : '';
		this.fieldToolTip = String.isNotBlank(fieldToolTip) ? fieldToolTip : '';
		this.fieldRequired = fieldRequired;
		if (!pickValues.isEmpty()) {
			this.pickValues = pickValues;
		}
	}

	public void dumpModel(String title) {
		System.debug('Dump View_Field model     : ' + title);
		System.debug('  apiName                 : ' + this.apiName);
		System.debug('  label                   : ' + this.label);
		System.debug('  fieldToolTip            : ' + this.fieldToolTip);
		System.debug('  type                    : ' + this.fieldType);
		System.debug('  fieldRequired           : ' + this.fieldRequired);
	}
}