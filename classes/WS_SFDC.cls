public class WS_SFDC {
	public static String calloutSalesforce(string xmlout, string callouttype, string endpoint) {
		Http h = new Http();
		// Instantiate a new HTTP request, specify the method (GET) as well as the endpoint
		HttpRequest req = new HttpRequest();
		req.setEndpoint(endpoint);
		if (
			callouttype == 'remoteSite' ||
			calloutType == 'apexClass' ||
			callouttype == 'securitySetting' ||
			calloutType == 'post'
		) {
			req.setMethod('POST');
			req.setHeader('Content-Type', 'text/xml; charset=UTF-8');
		} else {
			req.setMethod('GET');
			req.setHeader('Content-Type', 'text/xml; charset=utf-8');
		}
		//set soap action header based on request type
		if (callouttype == 'login') {
			req.setHeader('SOAPAction', 'login');
		} else if (callouttype == 'update') {
			req.setHeader('SOAPAction', 'update');
		} else if (
			callouttype == 'remoteSite' ||
			calloutType == 'apexClass' ||
			callouttype == 'securitySetting' ||
			calloutType == 'get' ||
			calloutType == 'post'
		) {
			/*else if (callouttype == 'logout') {
			req.setHeader('SOAPAction','logout');
		} else if (callouttype == 'setPassword') {
			req.setHeader('SOAPAction','setPassword');
		} */ req.setHeader(
				'SOAPAction',
				'""'
			);
		}
		req.setBody(xmlout);

		// Send the request, and return a response
		HttpResponse res = new HttpResponse();
		string xmlresponse;
		res = h.send(req);
		xmlresponse = res.getBody();

		return xmlresponse;
	}

	public static Map<String, String> loginToSalesforce(
		String username,
		String password,
		String environment
	) {
		String endpoint = environment.equalsIgnoreCase('production')
			? 'https://login.salesforce.com/services/Soap/c/29.0'
			: 'https://test.salesforce.com/services/Soap/c/29.0';

		String requestBody = WS_RequestTemplates.loginsalesforceXML(username, password);
		String reponseBody = calloutsalesforce(requestBody, 'login', endpoint);
		System.debug('\n reponseBody:' + reponseBody);
		Map<String, String> mapAuthenticationDetails = new Map<string, string>();
		Dom.Document responseDoc = new Dom.Document();
		responseDoc.load(reponseBody);
		Dom.XMLNode rootElm = responseDoc.getRootElement();

		if (!rootElm.getChildElements().isEmpty()) {
			Dom.XMLNode bodyElm = rootElm.getChildElements()[0];

			if (!bodyElm.getChildElements().isEmpty()) {
				Dom.XmlNode detailElm = bodyElm.getChildElements()[0];

				if (detailElm.getName() == 'Fault') {
					mapAuthenticationDetails.put('loginStatus', 'Failed');

					for (Dom.XmlNode faultElm : detailElm.getChildElements()) {
						if (faultElm.getName() == 'faultstring') {
							mapAuthenticationDetails.put('error', faultElm.getText());
							System.debug('\n Login Failure: message:' + faultElm.getText());
						}
					}
				} else if (detailElm.getName() == 'loginResponse') {
					mapAuthenticationDetails.put('loginStatus', 'Succcess');
					System.debug('\n Login Successful');

					Dom.XmlNode resultElm = detailElm.getChildElements()[0];
					if (resultElm != null && resultElm.getName() == 'result') {
						for (Dom.XmlNode attrElm : resultElm.getChildElements()) {
							if (attrElm.getName() == 'sessionId') {
								mapAuthenticationDetails.put('sessionId', attrElm.getText());
							} else if (attrElm.getName() == 'serverUrl') {
								mapAuthenticationDetails.put('serverUrl', attrElm.getText());
							} else if (attrElm.getName() == 'userId') {
								mapAuthenticationDetails.put('userId', attrElm.getText());
							}
						}
					}
				}
			}
		}

		System.debug('\n mapAuthenticationDetails: ' + mapAuthenticationDetails);
		return mapAuthenticationDetails;
	}
}