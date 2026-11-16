旧P0结果复用说明

CSSP_IMPORT_PRIOR(C,K,A,M,regime)仅尝试读取C.priorResultRoots中明确指定的旧P0结果根目录。
空列表表示不从旧目录导入。此函数不写入旧目录、不创建划分、不更改旧模型、不读取probe。

安全复用条件：
1. 旧根目录有source_manifest.mat，其完整.m及frozen/.m文件与当前捆绑P0源码逐一一致。
2. 当前X、污染mask、U0和V0的实际字节哈希与旧metadata、record一致；不信任外部传入的标签。
3. 行列秩、方法参数和算法参数精确一致。仅方法id/name及nbTraceEvery/nbProgressEvery日志字段可忽略。
   所有预算、截止值规则、校准参数、容差、历史记忆、样本权重和时间限制必须相同。
4. metadata.version为v2，record.IsScientificRun为true。旧TC、legacy求解器、pilot和CSV不能替代正式P0模型。
5. 最终基矩阵维数、正交性、数值有限性及终止状态有效；从最终冻结状态重建权重，并复核ESS与拒绝诊断。

同一精确配置有多个旧模型时，只有其端点及最终状态一致才复用；不会根据NRE、ACC或运行时间挑选结果。
timecap、failed_search和budget_exhausted保留真实状态，并不会因未收敛而被改标为稳定。

若旧模型没有中间checkpoint，只附真实初始化及真实终点，EndpointOnlyImported=true。
这可用于初值—终点比较，不能当成拥有完整迭代轨迹的新增实验。
拟合耗时保留原记录TimeSeconds，不能把本次读取缓存的耗时当成算法速度。
重评旧模型不是新增独立训练或独立确认数据。

若任一核查未通过，Found=false，并返回Reason、RejectedRoots及RejectedFiles，供主程序决定重新拟合。
缺少必要凭据时不猜测兼容性。旧源文件或结果不同，仍可由本轮程序在相同冻结输入上重新训练。
