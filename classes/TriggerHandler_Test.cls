@isTest
private class TriggerHandler_Test {
	private static String lastMethodCalled;
	private static TriggerHandler_Test.TestHandler handler;

	static {
		handler = new TriggerHandler_Test.TestHandler();
		handler = new TriggerHandler_Test.TestHandler('TestHandler');
		// override its internal trigger detection
		handler.isTriggerExecuting = true;
	}

	/***************************************
	 * unit tests
	 ***************************************/

	@isTest
	static void testBeforeInsert() {
		beforeInsertMode();
		handler.run();
		System.assertEquals('beforeInsert', lastMethodCalled, 'last method should be beforeInsert');
	}

	@isTest
	static void testBeforeUpdate() {
		beforeUpdateMode();
		handler.run();
		System.assertEquals('beforeUpdate', lastMethodCalled, 'last method should be beforeUpdate');
	}

	@isTest
	static void testBeforeDelete() {
		beforeDeleteMode();
		handler.run();
		System.assertEquals('beforeDelete', lastMethodCalled, 'last method should be beforeDelete');
	}

	@isTest
	static void testAfterInsert() {
		afterInsertMode();
		handler.run();
		System.assertEquals('afterInsert', lastMethodCalled, 'last method should be afterInsert');
	}

	@isTest
	static void testAfterUpdate() {
		afterUpdateMode();
		handler.run();
		System.assertEquals('afterUpdate', lastMethodCalled, 'last method should be afterUpdate');
	}

	@isTest
	static void testAfterDelete() {
		afterDeleteMode();
		handler.run();
		System.assertEquals('afterDelete', lastMethodCalled, 'last method should be afterDelete');
	}

	@isTest
	static void testAfterUndelete() {
		afterUndeleteMode();
		handler.run();
		System.assertEquals('afterUndelete', lastMethodCalled, 'last method should be afterUndelete');
	}

	@isTest
	static void testNonTriggerContext() {
		try {
			handler.run();
			System.assert(false, 'the handler ran but should have thrown');
		} catch (TriggerHandler.TriggerHandlerException te) {
			System.assertEquals(
				TriggerHandler.TRIGGER_CONTEXT_ERROR,
				te.getMessage(),
				'the exception message should match'
			);
		} catch (Exception e) {
			System.assert(
				false,
				'the exception thrown was not expected: ' +
				e.getTypeName() +
				': ' +
				e.getMessage()
			);
		}
	}

	@isTest
	static void testBypassAPI() {
		handler.removeRecursionLimit();
		afterUpdateMode();

		// test a bypass and run handler
		TriggerHandler.bypass('TestHandler');
		handler.run();
		System.assertEquals(null, lastMethodCalled, 'last method should be null when bypassed');
		System.assertEquals(
			true,
			TriggerHandler.isBypassed('TestHandler'),
			'test handler should be bypassed'
		);
		resetTest();

		// clear that bypass and run handler
		TriggerHandler.clearBypass('TestHandler');
		handler.run();
		System.assertEquals(
			'afterUpdate',
			lastMethodCalled,
			'last method called should be afterUpdate'
		);
		System.assertEquals(
			false,
			TriggerHandler.isBypassed('TestHandler'),
			'test handler should be bypassed'
		);
		resetTest();

		// test a re-bypass with a List of Strings and run handler
		TriggerHandler.bypass(new List<String>{ 'TestHandler' });
		handler.run();
		System.assertEquals(null, lastMethodCalled, 'last method should be null when bypassed');
		System.assertEquals(
			true,
			TriggerHandler.isBypassed('TestHandler'),
			'test handler should be bypassed'
		);
		resetTest();

		// clear all bypasses and run handler
		TriggerHandler.clearAllBypasses();
		handler.run();
		System.assertEquals(
			'afterUpdate',
			lastMethodCalled,
			'last method called should be afterUpdate'
		);
		System.assertEquals(
			false,
			TriggerHandler.isBypassed('TestHandler'),
			'test handler should be bypassed'
		);
		resetTest();
	}

	@isTest
	static void testDefaultRecursionLimit() {
		Integer defaultLimit = TriggerHandler.DEFAULT_RECURSION_LIMIT;

		beforeInsertMode();
		handler.run();

		afterInsertMode();
		handler.run();

		beforeUpdateMode();
		//Running the same operation up to the limit
		for (Integer i = 0; i < defaultLimit; i++) {
			handler.run();
		}

		afterUpdateMode();
		handler.run();

		//calling BEFORE_UPDATE again past the limit
		beforeUpdateMode();
		handler.run();

		if (defaultLimit >= 0) {
			System.assertEquals(
				'afterUpdate',
				lastMethodCalled,
				'Default Recursion limit exceeded for BEFORE_UPDATE, last method should be AFTER_UPDATE'
			);
		} else {
			System.assertEquals(
				'beforeUpdate',
				lastMethodCalled,
				'Default Recursion limit is disabled, last method should be BEFORE_UPDATE'
			);
		}
	}

	@isTest
	static void testSetRecursionLimit() {
		handler.setRecursionLimit(2);

		beforeInsertMode();
		handler.run();
		handler.run();

		afterDeleteMode();
		handler.run();

		//Calling BEFORE_INSERT the third time
		beforeInsertMode();
		handler.run();

		System.assertEquals(
			'afterDelete',
			lastMethodCalled,
			'limit exceeded for BEFORE_INSERT, last method should be AFTER_DELETE'
		);
	}

	@isTest
	static void getRecursionLimit_Always_GetsCurrentLimit() {
		Integer expectedLimit = 3;

		handler.setRecursionLimit(3);

		Test.startTest();
		Integer actualLimit = TriggerHandler.getRecursionLimit(handler.handlerName);
		Test.stopTest();

		System.assertEquals(expectedLimit, actualLimit);
	}

	@isTest
	static void testRemoveRecursionLimit() {
		handler.removeRecursionLimit();

		beforeInsertMode();
		handler.run();
		handler.run();
		handler.run();

		afterDeleteMode();
		handler.run();

		//Calling BEFORE_INSERT the fourth time
		beforeInsertMode();
		handler.run();

		System.assertEquals(
			'beforeInsert',
			lastMethodCalled,
			'recursion limit is removed, last method should be BEFORE_INSERT'
		);
	}

	@isTest
	static void shouldResetRecursionLimits() {
		handler.setRecursionLimit(1);

		Test.startTest();
		beforeInsertMode();
		handler.run();

		afterInsertMode();
		handler.run();

		TriggerHandler.resetRecursionLimits();

		beforeInsertMode();
		handler.run();
		Test.stopTest();

		System.assertEquals(
			'beforeInsert',
			lastMethodCalled,
			'recursion limit is reset, last method should be BEFORE_INSERT'
		);
	}

	@isTest
	static void testRecursionLimitClass() {
		afterInsertMode();

		TriggerHandler.RecursionLimit recursionLimit = new TriggerHandler.RecursionLimit();
		System.assertEquals(
			TriggerHandler.DEFAULT_RECURSION_LIMIT,
			recursionLimit.getMax(),
			'max should be Default on init'
		);
		System.assertEquals(
			null,
			recursionLimit.getCount(handler.context),
			'count should be null on init'
		);

		recursionLimit.increment(handler.context);
		System.assertEquals(1, recursionLimit.getCount(handler.context), 'count should be 1');
		System.assertEquals(
			false,
			recursionLimit.isExceeded(handler.context),
			'should not be exceeded with count of 1'
		);

		recursionLimit.setMax(5);

		recursionLimit.increment(handler.context);
		recursionLimit.increment(handler.context);
		recursionLimit.increment(handler.context);
		recursionLimit.increment(handler.context);
		System.assertEquals(5, recursionLimit.getCount(handler.context), 'count should be 5');
		System.assertEquals(
			false,
			recursionLimit.isExceeded(handler.context),
			'should not be exceeded with count of 5'
		);

		System.assertEquals(5, recursionLimit.getMax(), 'should be equal to 5');

		recursionLimit.increment(handler.context);
		System.assertEquals(6, recursionLimit.getCount(handler.context), 'count should be 6');
		System.assertEquals(
			true,
			recursionLimit.isExceeded(handler.context),
			'should not be exceeded with count of 6'
		);
	}

	@isTest
	static void testGetHandlerName() {
		System.assertEquals(
			'TestHandler',
			handler.getHandlerName(),
			'handler name should match class name'
		);
	}

	@isTest
	static void testVirtualMethods() {
		TriggerHandler handler = new TriggerHandler();
		handler.beforeInsert();
		handler.beforeUpdate();
		handler.beforeDelete();
		handler.afterInsert();
		handler.afterUpdate();
		handler.afterDelete();
		handler.afterUndelete();
	}

	/***************************************
	 * testing utilities
	 ***************************************/

	private static void resetTest() {
		lastMethodCalled = null;
	}

	private static void beforeInsertMode() {
		handler.setTriggerContext('before insert', true);
	}

	private static void beforeUpdateMode() {
		handler.setTriggerContext('before update', true);
	}

	private static void beforeDeleteMode() {
		handler.setTriggerContext('before delete', true);
	}

	private static void afterInsertMode() {
		handler.setTriggerContext('after insert', true);
	}

	private static void afterUpdateMode() {
		handler.setTriggerContext('after update', true);
	}

	private static void afterDeleteMode() {
		handler.setTriggerContext('after delete', true);
	}

	private static void afterUndeleteMode() {
		handler.setTriggerContext('after undelete', true);
	}

	private class TestHandler extends TriggerHandler {
		public TestHandler() {
		}

		public TestHandler(String triggerHandlerName) {
			super(triggerHandlerName);
		}

		public override void beforeInsert() {
			TriggerHandler_Test.lastMethodCalled = 'beforeInsert';
		}

		public override void beforeUpdate() {
			TriggerHandler_Test.lastMethodCalled = 'beforeUpdate';
		}

		public override void beforeDelete() {
			TriggerHandler_Test.lastMethodCalled = 'beforeDelete';
		}

		public override void afterInsert() {
			TriggerHandler_Test.lastMethodCalled = 'afterInsert';
		}

		public override void afterUpdate() {
			TriggerHandler_Test.lastMethodCalled = 'afterUpdate';
		}

		public override void afterDelete() {
			TriggerHandler_Test.lastMethodCalled = 'afterDelete';
		}

		public override void afterUndelete() {
			TriggerHandler_Test.lastMethodCalled = 'afterUndelete';
		}
	}
}