/*
 * Licensed Materials - Property of IBM
 * 6949-82Z
 * © Copyright IBM Corp. 2022 All Rights Reserved
 *
 * US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
 */

public without sharing class x7sIdeasBaseController {
	
	final public static String STATUS_SEPARATOR = ',';

	public x7sIdeasBaseController() {
	}

	@AuraEnabled(Cacheable=true)
	public static BaseModel getModel() {
		return new BaseModel();
	}

	public with sharing class BaseModel {
		@AuraEnabled
		public String namespacePrefix { get; set; }

		@AuraEnabled
		public Boolean lexMode { get; set; }

		public BaseModel() {
			this.namespacePrefix = [SELECT NamespacePrefix FROM ApexClass WHERE Name = 'x7sIdeasBaseController' LIMIT 1].NamespacePrefix;
			this.lexMode = System.Network.getNetworkId() == null;
		}
	}
}