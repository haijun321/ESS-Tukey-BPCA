配对汇总与机制图说明

1. 汇总入口
   CSSP_SUMMARIZE(C)
   C.outputRoot 指向本轮结果根目录；汇总只读取 paper/*/fits/*/fit.mat。
   pilot 不作为科学结果合并。C.makePlots=false 可关闭图形导出。

2. 结果读取
   all_fit_records.csv：各模块已经提交的拟合记录。
   completion.csv：与各模块 expected_manifest.csv 对照后的存在/缺失状态。
   execution_status_records.csv：各模块 status.csv 的合并，保留被阻塞任务。
   failures_and_blocked.csv：FAILED_OR_BLOCKED.txt 的文字记录。
   unreadable_records.csv：无法按约定读取的提交文件。
   duplicate_committed_keys.csv：同模块、数据集、条件、重复、方法、预算重复时硬停止。
   优先使用paper根的完整expected_manifest.csv；只有缺失时才回退到分模块清单。
   优先读取paper根task_status.csv，避免丢失没有fit.mat的被阻塞任务。
   stop_status_counts.csv另行列出实际终止标签及次数。

3. 指标方向
   NRE 越低越好；ACC 存储为0到1之间比例，越高越好。
   paired_differences.csv 的 Difference 始终等于左方法减右方法。
   对NRE，负差有利于左方法；对ACC，正差有利于左方法。
   ACC另提供 DifferencePercentagePoints=100*Difference。
   外部比较表采用“外部方法 minus C3”，请不要误读方向。
   预算比较采用同方法“B2 minus B1”。

4. 配对有效性
   原生组件比较要求 CaseHash 和 InitHash 同时一致。
   外部方法允许采用其原生初始化，因此只要求案例匹配，同时明确记录 InitMatched。
   FeatureMatched 说明实际特征维数是否相同；相同特征维数不代表模型参数数目相同。
   不可用基线、非有限指标、哈希不匹配、缺失/歧义参照均保留并标识。
   paired_summary.csv 只汇总 PairValid=true 的有限差值，并报告无效配对数。
   不能只看均值而忽略缺失任务或不可用基线。
   failed_search若保留了通过数值契约的有限终点，同timecap及budget_exhausted一样进入主比较。
   不按停止标签或结果表现删除这些算法输出；缺模型、非有限、契约违规或BaselineUsable=false另外报告。

5. 四格消融
   C2：固定ESS目标、有零权重惩罚。
   C3：自适应ESS目标、有零权重惩罚。
   C4：自适应ESS目标、无零权重惩罚。
   C5：固定ESS目标、无零权重惩罚。
   factorial_interactions.csv 的交互为 (C3-C2)-(C4-C5)。
   交互为零不代表统计等价；交互非零也不是普遍协同定理。
   C2固定的是ESS目标，其拒绝偏好仍按共同严重度规则变化。

6. 整体均值
   overall_repeat_means.csv 先在每个重复内，对应有条件等权平均。
   overall_summary.csv 再对完整重复块求均值和样本标准差。
   标准模块要求 Clean/I10/I30/B10/B30；B10预算模块仅要求B10。
   记录 CompleteBlock、NFiniteConditions 及不完整重复数，不把缺失条件悄悄删掉。
   当前汇总面向本轮真实数据方案，不把合成/真实结果合并为一个总体指标。

7. 冻结残差机制
   CSSP_MECHANISM(K,A,C) 只读取训练数据、共同初始子空间和固定配置。
   不读取probe指标，也不向校准函数提供污染掩码。
   默认memory=0；可显式传入K.MechanismMemory审计预先确定的历史状态。
   四种评分读取完全相同的残差、严重度/历史输入和候选集合。
   程序核验重建候选分数选出的tau与原生P0_STATE一致；不一致即报错。
   R0Operational使用|e|>tau；R0Exact计实际Tukey权重恰好为零的条目。
   两者在边界和数值下溢时可能不同，因此均保留。
   候选图使用操作统计量，不能把图解释为重新拟合后的NRE或ACC改善。
   固定残差时两个统计量都由同一个tau产生，不能声称两项可独立指定。

8. 绘图与解释
   机制图选每个数据集/条件最小重复编号作为预先固定的代表，不按结果挑图。
   配对图为平均差与样本标准差，未绘制“独立受试者置信区间”。
   图形导出失败写入plot_warnings.csv，数值结果仍保留。
   真实划分重复使用图像，本汇总不输出独立个体层面的显著性检验。
   数值检查次数、候选数、跨模块复用记录均不能作为独立样本量。
   完成拟合或达到预算均不等于收敛或方法优越。

9. 自检
   CSSP_SUMMARY_SELFTEST 使用临时人工结果检查配对和汇总规则，不使用研究数据。
   只有在MATLAB实际执行并返回Pass=true时，才表示这些工程检查已经通过。
   该自检不证明真实实验数据正确，也不证明方法具有统计优势。
