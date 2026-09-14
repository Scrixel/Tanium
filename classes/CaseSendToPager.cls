public with sharing class CaseSendToPager {
	public static Boolean nullOrEmpty(Object o) {
		return (null == o) ||
			((o instanceof String) && (0 == ((String) o).trim().length())) ||
			((o instanceof List<object>) && (0 == ((List<object>) o).size()));
	}

	@InvocableMethod(label='Send Case to Pager')
	public static void sendToPager(List<Case> cases) {
		//stubbed out
	}
}