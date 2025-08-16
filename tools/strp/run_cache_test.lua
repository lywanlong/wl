--============================================================================
-- STRP 缓存测试运行器
-- 用于运行 STRP 模板引擎的缓存测试
--============================================================================

-- 导入测试模块
local cache_test = require 'wl.tools.strp.test_cache'

-- 运行测试
print("正在启动 STRP 缓存测试...")
cache_test.main()

-- 获取详细测试结果
local results = cache_test.get_test_results()
print(string.format("\n详细统计: %d/%d 测试通过", 
                   results.passed_tests, results.total_tests))
