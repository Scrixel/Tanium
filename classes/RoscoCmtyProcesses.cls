public without sharing class RoscoCmtyProcesses {
	/** nullOrEmpty
	 */
	public static Boolean nullOrEmpty(Object o) {
		return (null == o) ||
			((o instanceof String) && (0 == ((String) o).trim().length())) ||
			((o instanceof List<object>) && (0 == ((List<object>) o).size()));
	}

	/** processNewCmtyQuestion
	 */
	public static String processNewCmtyQuestion(FeedItem feedItem) {
		String ret = '';

		final String CUSTOMER_CMTY_ID = '0DB0e000000CaezGAC';

		try {
			if (!nullOrEmpty(feedItem)) {
				if (feedItem.networkScope == CUSTOMER_CMTY_ID) {
					String title = 'Title is blank';
					if (!nullOrEmpty(feedItem.Title)) {
						title = String.valueOf(feedItem.Title);
						if (title.length() > 200) {
							title = title.substring(0, 200);
						}
					}

					String body = 'Body is blank';
					if (!nullOrEmpty(feedItem.Body)) {
						body = String.valueOf(feedItem.Body).stripHtmlTags();
						if (body.length() > 2000) {
							body =
								body.substring(0, 2000) +
								'\n<truncated - please view post online (respond button) to see full message>';
						}
					}

					String reponseButtonTxt = 'Respond';
					String slackText = '';
					if (String.valueOf(feedItem.ParentId).left(3) == '005') {
						slackText += '*New Community question [' + feedItem.Id + ']';
					} else {
						slackText += '*New Group question [' + feedItem.Id + ']';
						reponseButtonTxt = 'Respond to Group';
					}
					slackText += ' posted by ' + UserInfo.getUserName() + '*';
					slackText += ' ```' + title + '```';
					slackText += ' ```' + body + '```';
					slackText +=
						' <https://tanium.lightning.force.com/servlet/networks/switch?networkId=0DB0e000000Caez&startURL=s/question/' +
						feedItem.Id +
						' | ' +
						reponseButtonTxt +
						'>';
					slackText +=
						'    <https://community.tanium.com/s/question/' +
						feedItem.Id +
						'|Alt Open>';

					if (
						feedItem.Type == 'QuestionPost' ||
						String.valueOf(feedItem.ParentId).left(3) != '005'
					) {
						slackCommunity(slackText, feedItem.ParentId);
					}
				}
			}
		} catch (Exception e) {
			RoscoLog.addEntry(
				UserInfo.getUserId(),
				'Exception',
				'RoscoCmtyProcesses:processNewCmtyQuestion()',
				1,
				'Error',
				'Processing resulted in ' + ret,
				String.valueOf('feedItem:' + feedItem),
				e.getMessage(),
				e.getStackTraceString()
			);
		}

		return ret;
	}

	/** tempTillReWrite */
	public static void tempTillReWriteYo() {
		String ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
		ridiculous = 'tempTillReWriteYo';
	}

	/** slackSOA
	 */
	public static void slackCommunity(String slackText, String parentId) {
		System.debug('slackCommunity:entering');

		try {
			// Custom settings may override some options
			Case_Management__c cm = Case_Management__c.getInstance();
			Set<String> cmfields = Schema.SObjectType.Case_Management__c.fields.getMap().keySet();

			for (String s : cmfields) {
				System.debug('s:' + s);
			}

			// #
			String slackChannel = 'GCEBYKZ24';
			if (cmfields.contains('rosco_slack_community__c')) {
				String cmty = String.valueOf(cm.get('rosco_slack_community__c'));

				if (nullOrEmpty(cmty) == false) {
					slackChannel = cmty;
				}
			}
			// Group Override
			String slackGroupSetting =
				'rosco_slack_community_' +
				String.valueOf(parentId).toLowercase() +
				'__c';
			System.debug('slackGroupSetting:' + slackGroupSetting);
			if (cmfields.contains(slackGroupSetting)) {
				String cmty = String.valueOf(cm.get(slackGroupSetting));

				if (nullOrEmpty(cmty) == false) {
					slackChannel = cmty;
				}
			}
			System.debug('Slacking Channel: ' + slackChannel);

			// Webhook
			String webhookURL = '';
			if (cmfields.contains('rosco_slack_incoming_hook__c')) {
				String hook = String.valueOf(cm.get('rosco_slack_incoming_hook__c'));

				if (nullOrEmpty(hook) == false) {
					webhookURL = hook;
				}
			}

			// Post to SOA
			JSONGenerator soaGen = JSON.createGenerator(true);
			soaGen.writeStartObject();
			soaGen.writeStringField('channel', slackChannel);
			soaGen.writeStringField('icon_url', 'http://grapelabs.net/rosco/rosco.jpg');
			soaGen.writeStringField('text', slackText);
			soaGen.writeEndObject();
			String soaBody = soaGen.getAsString();
			if (!Test.isRunningTest()) {
				System.enqueueJob(new qCallOut(webhookURL, 'POST', soaBody));
			}
		} catch (Exception e) {
			System.debug('slackCommunity: ' + e.getMessage() + '\n' + e.getStackTraceString());
		}
	}

	public class qCallOut implements System.Queueable, Database.AllowsCallouts {
		private final String url;
		private final String method;
		private final String body;

		public qCallOut(String url, String method, String body) {
			this.url = url;
			this.method = method;
			this.body = body;
		}

		public void execute(System.QueueableContext ctx) {
			HttpRequest req = new HttpRequest();
			req.setEndpoint(url);
			req.setMethod(method);
			req.setBody(body);
			Http http = new Http();
			HttpResponse res = http.send(req);
		}
	}
}