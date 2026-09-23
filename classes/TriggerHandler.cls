public virtual class TriggerHandler {
	@TestVisible
	private static final Map<String, Trigger_Handler_Setting__mdt> SETTINGS = Trigger_Handler_Setting__mdt.getAll();
	@TestVisible
	private static final Integer DEFAULT_RECURSION_LIMIT;
	@TestVisible
	private static final String TRIGGER_CONTEXT_ERROR = 'Trigger handler called outside of Trigger execution';
	@TestVisible
	private String handlerName { get; set; }
	@TestVisible
	private static Map<String, RecursionLimit> recursionLimitMap;
	@TestVisible
	private static Set<String> bypassedHandlers;
	@TestVisible
	private TriggerContext context;
	@TestVisible
	private Boolean isTriggerExecuting;

	static {
		DEFAULT_RECURSION_LIMIT = getDefaultLimit();
		recursionLimitMap = new Map<String, RecursionLimit>();
		bypassedHandlers = new Set<String>();
	}

	public TriggerHandler() {
		this.getHandlerName();
		this.setTriggerContext();
		this.getHandlerSetting();
	}

	public TriggerHandler(String handlerName) {
		this.handlerName = handlerName;
		this.setTriggerContext();
		this.getHandlerSetting();
	}

	/***************************************
	 * public instance methods
	 ***************************************/

	// main method that will be called during execution
	public void run() {
		if (isInvalidRun()) {
			return;
		}

		switch on this.context {
			when BEFORE_INSERT {
				this.beforeInsert();
			}
			when BEFORE_UPDATE {
				this.beforeUpdate();
			}
			when BEFORE_DELETE {
				this.beforeDelete();
			}
			when AFTER_INSERT {
				this.afterInsert();
			}
			when AFTER_UPDATE {
				this.afterUpdate();
			}
			when AFTER_DELETE {
				this.afterDelete();
			}
			when AFTER_UNDELETE {
				this.afterUndelete();
			}
		}
	}

	/***************************************
	 * public static methods
	 ***************************************/

	public static void bypass(String handlerName) {
		TriggerHandler.bypassedHandlers.add(handlerName);
	}

	public static void bypass(List<String> handlerNames) {
		TriggerHandler.bypassedHandlers.addAll(handlerNames);
	}

	public static void clearBypass(String handlerName) {
		TriggerHandler.bypassedHandlers.remove(handlerName);
	}

	public static Boolean isBypassed(String handlerName) {
		return TriggerHandler.bypassedHandlers.contains(handlerName);
	}

	public static void clearAllBypasses() {
		TriggerHandler.bypassedHandlers.clear();
	}

	public static Integer getRecursionLimit(String handlerName) {
		Integer recursionLimit = DEFAULT_RECURSION_LIMIT;
		RecursionLimit handlerLimit = TriggerHandler.recursionLimitMap.get(handlerName);

		if (handlerLimit != null) {
			recursionLimit = handlerLimit.getMax();
		}

		return recursionLimit;
	}

	public static Boolean isDisabled(String handlerName) {
		return SETTINGS.get(handlerName)?.Disabled__c == true ||
			Utility.isTaniumCustomTriggerDisabled(handlerName);
	}

	/***************************************
	 * private static methods
	 ***************************************/

	@TestVisible
	private static Integer getDefaultLimit() {
		Integer defaultLimit = 1;

		Trigger_Handler_Setting__mdt defaultSetting = SETTINGS.get('ORG_DEFAULT');

		if (defaultSetting?.Disable_Recursion_Control__c == true) {
			//Disables recursion
			defaultLimit = -1;
		} else if (defaultSetting?.Recursion_Limit__c > 0) {
			defaultLimit = (Integer) defaultSetting.Recursion_Limit__c;
		}

		return defaultLimit;
	}

	@TestVisible
	private static void resetRecursionLimits() {
		TriggerHandler.recursionLimitMap.clear();
	}

	/***************************************
	 * private instancemethods
	 ***************************************/
	@TestVisible
	private String getHandlerName() {
		if (String.isBlank(this.handlerName)) {
			this.handlerName = String.valueOf(this).substring(0, String.valueOf(this).indexOf(':'));
		}
		return this.handlerName;
	}

	@TestVisible
	private void getHandlerSetting() {
		Trigger_Handler_Setting__mdt handlerSetting = SETTINGS.get(this.handlerName);

		if (handlerSetting?.Disable_Recursion_Control__c == true) {
			this.removeRecursionLimit();
		} else if (handlerSetting?.Recursion_Limit__c > 0) {
			this.setRecursionLimit((Integer) handlerSetting.Recursion_Limit__c);
		}
	}

	@TestVisible
	private void setRecursionLimit(Integer max) {
		if (!TriggerHandler.recursionLimitMap.containsKey(this.handlerName)) {
			TriggerHandler.recursionLimitMap.put(this.handlerName, new RecursionLimit(max));
		} else {
			TriggerHandler.recursionLimitMap.get(this.handlerName).setMax(max);
		}
	}

	@TestVisible
	private void removeRecursionLimit() {
		this.setRecursionLimit(-1);
	}

	@TestVisible
	private void setTriggerContext() {
		this.setTriggerContext(null, false);
	}

	@TestVisible
	private void setTriggerContext(String ctx, Boolean testMode) {
		if (!Trigger.isExecuting && !testMode) {
			this.isTriggerExecuting = false;
			return;
		} else {
			this.isTriggerExecuting = true;
		}

		if (
			(Trigger.isExecuting && Trigger.isBefore && Trigger.isInsert) ||
			(ctx != null &&
			ctx == 'before insert')
		) {
			this.context = TriggerContext.BEFORE_INSERT;
		} else if (
			(Trigger.isExecuting && Trigger.isBefore && Trigger.isUpdate) ||
			(ctx != null &&
			ctx == 'before update')
		) {
			this.context = TriggerContext.BEFORE_UPDATE;
		} else if (
			(Trigger.isExecuting && Trigger.isBefore && Trigger.isDelete) ||
			(ctx != null &&
			ctx == 'before delete')
		) {
			this.context = TriggerContext.BEFORE_DELETE;
		} else if (
			(Trigger.isExecuting && Trigger.isAfter && Trigger.isInsert) ||
			(ctx != null &&
			ctx == 'after insert')
		) {
			this.context = TriggerContext.AFTER_INSERT;
		} else if (
			(Trigger.isExecuting && Trigger.isAfter && Trigger.isUpdate) ||
			(ctx != null &&
			ctx == 'after update')
		) {
			this.context = TriggerContext.AFTER_UPDATE;
		} else if (
			(Trigger.isExecuting && Trigger.isAfter && Trigger.isDelete) ||
			(ctx != null &&
			ctx == 'after delete')
		) {
			this.context = TriggerContext.AFTER_DELETE;
		} else if (
			(Trigger.isExecuting && Trigger.isAfter && Trigger.isUndelete) ||
			(ctx != null &&
			ctx == 'after undelete')
		) {
			this.context = TriggerContext.AFTER_UNDELETE;
		}
	}

	@TestVisible
	private Boolean isInvalidRun() {
		if (!this.isTriggerExecuting || this.context == null) {
			throw new TriggerHandlerException(TRIGGER_CONTEXT_ERROR);
		}

		return isDisabled(this.handlerName) ||
			isBypassed(this.handlerName) ||
			isRecursionLimitExceeded();
	}

	@TestVisible
	private Boolean isRecursionLimitExceeded() {
		if (!TriggerHandler.recursionLimitMap.containsKey(this.handlerName)) {
			TriggerHandler.recursionLimitMap.put(this.handlerName, new RecursionLimit());
		}

		RecursionLimit recursionLimit = TriggerHandler.recursionLimitMap.get(this.handlerName);
		recursionLimit.increment(this.context);

		Boolean limitExceeded = recursionLimit.isExceeded(this.context);
		if (limitExceeded) {
			//TODO: Replace Debug with appropriate logging function after Process Builder Tech Debt is resolved
			System.debug('Recursion Limit Exceeded for ' + this.handlerName + ' in ' + this.context);
		}

		return limitExceeded;
	}

	/***************************************
	 * context methods
	 ***************************************/

	@TestVisible
	protected virtual void beforeInsert() {
	}
	@TestVisible
	protected virtual void beforeUpdate() {
	}
	@TestVisible
	protected virtual void beforeDelete() {
	}
	@TestVisible
	protected virtual void afterInsert() {
	}
	@TestVisible
	protected virtual void afterUpdate() {
	}
	@TestVisible
	protected virtual void afterDelete() {
	}
	@TestVisible
	protected virtual void afterUndelete() {
	}

	/***************************************
	 * inner classes
	 ***************************************/

	@TestVisible
	private class RecursionLimit {
		private Map<TriggerContext, Integer> contextCountMap;
		private Integer max;

		public RecursionLimit() {
			this.contextCountMap = new Map<TriggerContext, Integer>();
			this.max = TriggerHandler.DEFAULT_RECURSION_LIMIT;
		}

		public RecursionLimit(Integer max) {
			this.contextCountMap = new Map<TriggerContext, Integer>();
			this.max = max;
		}

		public void increment(TriggerContext context) {
			Integer count = this.contextCountMap.get(context);

			if (count == null) {
				this.contextCountMap.put(context, 1);
			} else {
				count++;
				this.contextCountMap.put(context, count);
			}
		}

		public Boolean isExceeded(TriggerContext context) {
			return this.max > 0 && this.contextCountMap.get(context) > this.max;
		}

		public Integer getMax() {
			return this.max;
		}

		public Integer getCount(TriggerContext context) {
			return this.contextCountMap.get(context);
		}

		public void setMax(Integer max) {
			this.max = max;
		}
	}

	// possible trigger contexts
	@TestVisible
	private enum TriggerContext {
		BEFORE_INSERT,
		BEFORE_UPDATE,
		BEFORE_DELETE,
		AFTER_INSERT,
		AFTER_UPDATE,
		AFTER_DELETE,
		AFTER_UNDELETE
	}

	// exception class
	public class TriggerHandlerException extends Exception {
	}
}