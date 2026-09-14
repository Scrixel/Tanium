/**
 * Copyright (c) 2026 Tanium
 *
 * @Business: Dynamic-Apex bridge to seed Ruby (Nue) test settings without a compile-time dependency on the Ruby namespace
 * @Date: 2026-08-12
 * @Author: Tanium Dev Team
 * RequestId  ModifiedDate  Description
 * SS-13646   2026-08-12    Initial development
 */
@IsTest
public class Ruby_TestHelper implements Callable {
	public Object call(String action, Map<String, Object> args) {
		if (action == 'seed') {
			Ruby.RubySettingService.globalSeedSystemSettings();
			Ruby.RubySettingService.globalSeedObjectMappings();
		}
		return null;
	}
}