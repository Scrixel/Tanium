/*
 * Copyright (c) 2022.  7Summits, an IBM company. All rights reserved.
 */

/**
 * @description Custom field class definition
 */
public without sharing class x7sShrCustomFieldModel implements Comparable {
	@AuraEnabled
	public String id, name, apiName, lookupName, fieldLabel, fieldType, align, info, dataValue, tooltip, placeholder;
	@AuraEnabled
	public String label, labelType, icon;
	@AuraEnabled
	public List<String> dataValues {get; set;}
	@AuraEnabled
	public List<String> picklistValues {get;set;}

	@AuraEnabled
	public Boolean required, valid;

	@AuraEnabled
	public Integer sequence;

	public x7sShrCustomFieldModel() {
		id = '';
		name = '';
		fieldType = 'text';
		sequence = 0;
		required = false;
		valid = true;
		dataValues = new List<String>();
		picklistValues = new List<String>();
	}

	public Integer compareTo(Object param) {
		x7sShrCustomFieldModel field = (x7sShrCustomFieldModel)param;
		return this.sequence == field.sequence ? 0 : this.sequence > field.sequence ? 1 : -1 ;
	}

	public void dump(String title) {
		System.debug('Custom Field Model: ' + title);
		System.debug('name      : ' + name);
		System.debug('API Name  : ' + apiName);
		System.debug('Sequence  : ' + sequence);
		System.debug('Required  : ' + required);
	}
}