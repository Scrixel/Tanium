/*
 * Copyright (c) 2021. 7Summits, an IBM Company. All rights reserved.
 */

public without sharing class x7sIdeasCustomField implements Comparable {
	@AuraEnabled
	public String id, name, apiName, label, fieldLabel, fieldType, align, info, dataValue;

	@AuraEnabled
	public List<String> dataValues;

	@AuraEnabled
	public Boolean required;

	@AuraEnabled
	public Decimal sequence;

	public x7sIdeasCustomField(X7S_Ideas_Custom_Field__mdt field, Decimal position) {
		id = field.Id;
		name = field.DeveloperName;
		label = field.Label;
		fieldLabel = String.isNotBlank(field.Field_Label__c) ? field.Field_Label__c : field.Label;
		apiName = field.API_Name__c;
		info = field.Info__c;
		fieldType = field.Type__c;
		dataValue = field.Data__c;
		align = field.Alignment__c;
		required = field.Required__c;
		sequence = position;

		if (fieldType == 'Picklist') {
			dataValues = new List<String>();
			dataValues.addAll(dataValue.trim().split('\\s*,\\s*'));
		}
	}

	public void dumpModel(String title) {
		System.debug('Dump Match_Field model   : ' + title);
		System.debug('  id          : ' + this.id);
		System.debug('  name        : ' + this.name);
		System.debug('  label       : ' + this.label);
		System.debug('  field label : ' + this.fieldLabel);
		System.debug('  apiName     : ' + this.apiName);
		System.debug('  info        : ' + this.info);
		System.debug('  type        : ' + this.fieldType);
		System.debug('  data        : ' + this.dataValue);
		System.debug('  align       : ' + this.align);
		System.debug('  sequence    : ' + this.sequence);
		System.debug('  required    : ' + this.required);
	}

	public Integer compareTo(Object param1) {
		x7sIdeasCustomField field = (x7sIdeasCustomField) param1;

		return field.sequence == this.sequence ? 0 : field.sequence > this.sequence ? -1 : 1;
	}
}