public class WS_RequestTemplates {
	public static String loginsalesforceXML(String username, String password) {
		DOM.Document doc = new DOM.Document();
		String soapNS = 'http://schemas.xmlsoap.org/soap/envelope/';
		String urn = 'urn:enterprise.soap.sforce.com';

		Dom.XmlNode envelope = doc.createRootElement('Envelope', soapNS, 'soapenv');
		envelope.setNamespace('urn', urn);
		//header
		Dom.XmlNode headerElm = envelope.addChildElement('Header', soapNS, null);

		//body
		Dom.XmlNode bodyElm = envelope.addChildElement('Body', soapNS, null);

		//body elements
		Dom.XmlNode loginElm = bodyElm.addChildElement('login', urn, 'urn');
		Dom.XmlNode usernameElm = loginElm.addChildElement('username', urn, 'urn');
		usernameElm.addTextNode(username);

		Dom.XmlNode passwordElm = loginElm.addChildElement('password', urn, 'urn');
		passwordElm.addTextNode(password);

		return doc.toXmlString();
	}

	public static String listMetadataXML(String sessionId, String metadataType) {
		Dom.Document doc = new Dom.Document();

		String soapNS = 'http://schemas.xmlsoap.org/soap/envelope/';
		String urn = 'urn:enterprise.soap.sforce.com';
		String urn1 = 'urn:sobject.enterprise.soap.sforce.com';
		String xsi = 'http://www.w3.org/2001/XMLSchema-instance';
		String xmlns = 'http://soap.sforce.com/2006/04/metadata';

		Dom.XmlNode envelopeNode = doc.createRootElement('Envelope', soapNS, 'env');
		envelopeNode.setNamespace('urn', urn);
		envelopeNode.setNamespace('urn1', urn1);
		envelopeNode.setNamespace('xsi', xsi);

		// Header Node
		Dom.XmlNode headerNode = envelopeNode.addChildElement('Header', soapNS, null);

		// Header Node Elements
		Dom.XmlNode sessionHeaderNode = headerNode.addChildElement('SessionHeader', urn, 'urn');
		sessionHeaderNode.setAttribute('xmlns:urn', xmlns);
		Dom.XmlNode sessionIdNode = sessionHeaderNode.addChildElement('sessionId', urn, 'urn');
		sessionIdNode.addTextNode(sessionId);

		// Body Node
		Dom.XmlNode bodyNode = envelopeNode.addChildElement('Body', soapNS, null);

		// Body Node Elements
		Dom.XmlNode listMetadataNode = bodyNode.addChildElement('listMetadata', null, null);
		listMetadataNode.setAttribute('xmlns', xmlns);
		Dom.XmlNode typesNode = listMetadataNode.addChildElement('types', null, null);
		Dom.XmlNode typeNode = typesNode.addChildElement('type', null, null);
		typeNode.addTextNode(metadataType);

		//system.debug(doc.toXmlString());
		return doc.toXmlString();
	}

	public static String readMetadataXML(
		String sessionId,
		String metadataType,
		String componentAPIName
	) {
		return WS_RequestTemplates.readMetadataXML(
			sessionId,
			metadataType,
			new List<String>{ componentAPIName }
		);
	}

	public static String readMetadataXML(
		String sessionId,
		String metadataType,
		String[] listComponentsAPIName
	) {
		Dom.Document doc = new Dom.Document();

		String soapNS = 'http://schemas.xmlsoap.org/soap/envelope/';
		String urn = 'urn:enterprise.soap.sforce.com';
		String urn1 = 'urn:sobject.enterprise.soap.sforce.com';
		String xsi = 'http://www.w3.org/2001/XMLSchema';
		String xsd = 'http://www.w3.org/2001/XMLSchema-instance';
		String xmlns = 'http://soap.sforce.com/2006/04/metadata';

		Dom.XmlNode envelopeNode = doc.createRootElement('Envelope', soapNS, 'env');
		envelopeNode.setNamespace('xsi', xsi);
		envelopeNode.setNamespace('xsd', xsd);

		// Header Node
		Dom.XmlNode headerNode = envelopeNode.addChildElement('Header', soapNS, null);

		// Header elements
		Dom.XmlNode sessionHeaderNode = headerNode.addChildElement('SessionHeader', null, null);
		sessionHeaderNode.setAttribute('xmlns', xmlns);

		Dom.XmlNode sessionIdNode = sessionHeaderNode.addChildElement('sessionId', null, null);
		sessionIdNode.addTextNode(sessionId);

		// Body Node
		Dom.XmlNode bodyNode = envelopeNode.addChildElement('Body', soapNS, null);

		//body elements
		Dom.XmlNode readMetadataNode = bodyNode.addChildElement('readMetadata', null, null);
		readMetadataNode.setAttribute('xmlns', xmlns);

		Dom.XmlNode typeNode = readMetadataNode.addChildElement('type', null, null);
		typeNode.addTextNode(metadataType);

		for (String componentName : listComponentsAPIName) {
			Dom.XmlNode fullName = readMetadataNode.addChildElement('fullName', null, null);
			fullName.addTextNode(componentName);
		}

		System.debug(doc.toXmlString());
		return doc.toXmlString();
	}
	/*
    public static String updateMetadataXML(String sessionId, String metadataType, String componentAPIName, 
    		String strUpdateWhat, String strUpdate){
		Dom.Document doc = new Dom.Document();

		String soapNS = 'http://schemas.xmlsoap.org/soap/envelope/';
		String urn = 'urn:enterprise.soap.sforce.com';
		String urn1 = 'urn:sobject.enterprise.soap.sforce.com';
		String xsi = 'http://www.w3.org/2001/XMLSchema';
		String xsd = 'http://www.w3.org/2001/XMLSchema-instance';
		String xmlns = 'http://soap.sforce.com/2006/04/metadata';

		Dom.XmlNode envelopeNode = doc.createRootElement('Envelope', soapNS, 'env');
		envelopeNode.setNamespace('xsi', xsi);
		envelopeNode.setNamespace('xsd', xsd);
                
		// Header Node
		Dom.XmlNode headerNode = envelopeNode.addChildElement('Header', soapNS, null);

		// Header Node Elements
		Dom.XmlNode sessionHeaderNode = headerNode.addChildElement('SessionHeader', null, null);
        sessionHeaderNode.setAttribute('xmlns', xmlns);
        Dom.XmlNode sessionIdNode = sessionHeaderNode.addChildElement('sessionId', null, null);
        sessionIdNode.addTextNode(sessionId);
				
		// Body Node
		Dom.XmlNode bodyNode = envelopeNode.addChildElement('Body', soapNS, null);

		// Body Node Elements
		Dom.XmlNode updateMetadataNode = bodyNode.addChildElement('updateMetadata', null, null);
		updateMetadataNode.setAttribute('xmlns', xmlns);
        Dom.XmlNode typeNode = updateMetadataNode.addChildElement('type', null, null);
        typeNode.addTextNode(metadataType);
        Dom.XmlNode fullNameNode = updateMetadataNode.addChildElement('fullName', null, null);
        fullNameNode.addTextNode(componentAPIName);
        Dom.XmlNode updateWhat = updateMetadataNode.addChildElement(strUpdateWhat, null, null);
        fullNameNode.addTextNode(strUpdate);

		system.debug('\n Update Metadata XML:' + doc.toXmlString()); 
		return doc.toXmlString();
	}*/

	public static String generateUpdateReportTypeMetadataXML(
		String sessionId,
		List<MetadataTypes.ReportType> listReportTypes
	) {
		Dom.Document doc = new Dom.Document();

		String soapNS = 'http://schemas.xmlsoap.org/soap/envelope/';
		String urn = 'urn:enterprise.soap.sforce.com';
		String urn1 = 'urn:sobject.enterprise.soap.sforce.com';
		String xsd = 'http://www.w3.org/2001/XMLSchema';
		String xsi = 'http://www.w3.org/2001/XMLSchema-instance';
		String xmlns = 'http://soap.sforce.com/2006/04/metadata';

		Dom.XmlNode envelopeNode = doc.createRootElement('Envelope', soapNS, 'env');
		envelopeNode.setNamespace('xsi', xsi);
		envelopeNode.setNamespace('xsd', xsd);

		// Header Node
		Dom.XmlNode headerNode = envelopeNode.addChildElement('Header', soapNS, null);

		// Header Node Elements
		Dom.XmlNode sessionHeaderNode = headerNode.addChildElement('SessionHeader', null, null);
		sessionHeaderNode.setAttribute('xmlns', xmlns);
		Dom.XmlNode sessionIdNode = sessionHeaderNode.addChildElement('sessionId', null, null);
		sessionIdNode.addTextNode(sessionId);

		// Body Node
		Dom.XmlNode bodyNode = envelopeNode.addChildElement('Body', soapNS, null);

		// Body Node Elements
		Dom.XmlNode updateMetadataNode = bodyNode.addChildElement('updateMetadata', null, null);
		updateMetadataNode.setAttribute('xmlns', xmlns);

		for (MetadataTypes.ReportType reportType : listReportTypes) {
			Dom.XmlNode metadataNode = updateMetadataNode.addChildElement('metadata', null, null);
			metadataNode.setAttribute('xsi:type', 'ReportType');

			metadataNode.addChildElement('fullName', null, null).addTextNode(reportType.fullName);
			metadataNode.addChildElement('baseObject', null, null).addTextNode(reportType.baseObject);
			metadataNode.addChildElement('category', null, null).addTextNode(reportType.category);
			metadataNode.addChildElement('deployed', null, null).addTextNode(reportType.deployed);
			metadataNode.addChildElement('label', null, null).addTextNode(reportType.label);

			// Add join object information
			MetadataTypes.ObjectRelationShip objRelationship = reportType.joinRelationship;
			Dom.XmlNode objRelationshipNode = metadataNode;
			while (true) {
				if (objRelationship == null) {
					break;
				}

				Dom.XmlNode joinNode = objRelationshipNode.addChildElement('join', null, null);
				Dom.XmlNode realtionshipNode = joinNode.addChildElement('relationship', null, null);
				realtionshipNode.addTextNode(objRelationship.relationship);

				Dom.XmlNode outerJoinNode = joinNode.addChildElement('outerJoin', null, null);
				outerJoinNode.addTextNode(String.valueOf(objRelationship.outerJoin));

				objRelationship = objRelationship.joinRelationship;
				objRelationshipNode = joinNode;
			}

			for (MetadataTypes.ReportTypeSection rtSection : reportType.sections) {
				Dom.XmlNode sectionNode = metadataNode.addChildElement('sections', null, null);
				sectionNode.addChildElement('masterLabel', null, null).addTextNode(rtSection.masterLabel);

				for (MetadataTypes.ReportTypeSectionField rtsField : rtSection.columns) {
					//System.debug('Report Type Section Field :' + reportType.fullName + '|' + rtSection.masterLabel + '|'  + rtsField);
					Dom.XmlNode columnNode = sectionNode.addChildElement('columns', null, null);
					columnNode.addChildElement('field', null, null).addTextNode(rtsField.field);
					columnNode.addChildElement('table', null, null).addTextNode(rtsField.table);
					columnNode.addChildElement('checkedByDefault', null, null)
						.addTextNode(String.valueOf(rtsField.checkedByDefault));
				}
			}
		}

		System.debug('\n XML for updating ReportType Metadata:' + doc.toXmlString());
		return doc.toXmlString();
	}
}