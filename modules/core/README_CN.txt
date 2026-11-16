ESS-Tukey 双边 PCA：CSSP P0 补充实验代码 V2 FIX1（2026-10-04）

FIX1：P0_SELFTEST 的旧版真实求解器工程回放补齐 severityMemoryMode='max'。
正式实验算法/默认参数和 frozen 源码未修改。已有旧版结果目录请保留，
修复后建议使用 results_P0_V2_FIX1；详细替换步骤见 FIX1_README_CN.txt。

这份代码针对当前 ESS-calibrated Tukey bilateral PCA 稿件。
它不属于另一个 L1-RBPCA、RAR 或 HCL-TRPCA 项目。

1. 先看清本包提供什么

提供修订求解器、冻结旧版对照、原 44 条件合成网格、ORL/YALE 归档接口、
CORE 消融、完整配置重评估、guard/样本加权对照、共同预算敏感性、
ORL 验证选择后测试的 TUNE、配对统计、CSV/图与精简结果打包。

本包尚未在作者的真实 MATLAB 和原始实验归档上完成运行。
交付环境没有 MATLAB/Octave。validation 中的检查是 Python 独立数学复核与
MATLAB 源文件词法/块结构检查，不是 MATLAB 编译证明，也不是论文模型结果。
请先运行 selftest 和 quick，再启动正式实验。

EXPERIMENT_TO_MANUSCRIPT_MAP_CN.txt 给出实验的必要性、应呈现的指标及对应正文位置。
VALIDATION_NOTES_CN.txt 区分本环境已经完成的检查与作者环境尚需执行的检查。

建议 MATLAB R2018b 或更新版本、通常带 JVM 的桌面/命令行环境。
合成部分不需要图像数据、Statistics Toolbox 或 Parallel Computing Toolbox。
读取真实数据使用原缓存，不重新读取图片、不重新划分样本。
默认串行运行，保存紧凑数值轨迹；不保存每轮完整三维权重历史。

2. 第一次运行：不需要改动原实验代码

将 ZIP 解压。进入包含 START_TUKEY_CSSP_P0_V2.m 的那一层目录。
不要进入 frozen 子目录，也不要覆盖原来的代码目录。

在 MATLAB 命令窗口执行（替换 codeDir 为实际解压路径）：

codeDir = 'H:\Students\Jiang_haijun\Tukey BPCA\Tukey_CSSP_P0_Experiments_V2_20261004';
cd(codeDir);
addpath(codeDir, fullfile(codeDir,'frozen'), '-begin');
opts = struct();
opts.archiveRoot = 'H:\Students\Jiang_haijun\Tukey BPCA\results_Tukey_CONFIRM_v1';
opts.outputRoot = fullfile(codeDir,'results_P0_V2');
START_TUKEY_CSSP_P0_V2('selftest',opts);
START_TUKEY_CSSP_P0_V2('quick',opts);

selftest 应返回 Pass = 1。这是工程检查（检查公式与程序），不判断论文创新性。
quick 运行 40 个小规模拟合：4 条件、1 次、旧/新求解器及 CORE。
quick 使用 n=24、12x10、秩 3x2 和较短预算，明确 IsScientificRun=false。
quick 的数值不能填入正文的 240 个 40x30 矩阵实验表。

建议一直用同一个 opts 运行后面的命令；不要中途修改 .m 文件。
若修改算法、配置、种子或重复次数，请选择新的 outputRoot。
现有已提交 fit.mat 不会被覆盖；相同命令可验证签名后续跑。

3. 合成实验：正式运行顺序

START_TUKEY_CSSP_P0_V2('solver_synthetic',opts);
START_TUKEY_CSSP_P0_V2('core_synthetic',opts);
START_TUKEY_CSSP_P0_V2('main_synthetic',opts);

也可一次运行以上三个模块（顺序为 solver、main、core）：
START_TUKEY_CSSP_P0_V2('paper_synthetic',opts);

默认规模：
- solver_synthetic：4 个预先指定诊断条件 x 10 次 x 3 配置 x 2 求解器 = 240 拟合。
- core_synthetic：44 条件 x 10 次 x 4 配置 = 1760 拟合。
- main_synthetic：44 条件 x 10 次 x 6 配置 = 2640 拟合。
- paper_synthetic：合计 4640 拟合。没有预先声称这些拟合支持 Auto 的优势。

默认原网格：sample、impulse、block_random 的率 0/.02/.05/.10/.15/.20；
block_coherent 的率 0/.02/.05/.10；强度 2/4；10 次；噪声标准差 .10。
零污染有 8 个不同种子元组；它们代表相同的无注入污染机制。
合成几何、生成器、阈值候选规则及已有开发映射被冻结；不重新用测试真值调图。
seed = 100000 + 强度序号*20000 + 类型序号*3000 + 率序号*100 + repeat。
例如 sample/0/强度2/repeat1 的 seed 为 123101，与归档原表相符。

所有合成主比较共享 [60 外层,10 内层,20 候选回溯] 和 180 秒软时间上限。
时间检查在完整操作之间执行，昂贵的一次权重计算/线性代数操作可能越过上限。
不是强行中断的精确墙钟限制。训练时间与含初始化、诊断/指标的时间分开导出。
初始化沿用冻结规则：稳健比较共有 MAD 裁剪 BPCA 初始化；L2 用未裁剪初始化。
MAIN 比较的是完整配置。CORE 的所有配置共享稳健初始化、无样本加权、无 guard。
MAIN 六个配置在本包修订优化框架下重新评估，不等同于导入旧表作为新结果。

4. CORE 中每一对究竟检验什么

C1 = FixedTukey-noSW-noGuard，c=4.685。
C2 = ESS-fixedEta-matched-noSW-noGuard，eta=.85。
C3 = ESS-auto-matched-noSW-noGuard，eta(h)。
C4 = C3 去掉零权重偏好惩罚；其余相同。

C2 和 C3 在给定同一个残差 E 时使用同一 h 计算/记忆规则、同一候选网格、
同一 z*=clip(h,0,.4)、同一 [.45z*,1.80z*] 软偏好与惩罚 .8/.5。
固定 eta 的 CORE 分支与归档固定 eta 的 1-eta 分支不同，是新的匹配控制。
各方法的残差轨迹不同，运行中的 h 当然可以不同；匹配的是规则和初始输入。
guard 被关掉时 h=0 的 Auto 仍使用有限阈值和 eta=.99，不自动赋元素权重为一。

主要对照：C2-C1 = 固定目标 ESS 校准整体；C3-C2 = 目标自适应；
C3-C4 = 零权重校准。C2-C1 的差异不能全部归因于 ESS 匹配项本身。

若要再拆开 ESS 匹配与零权重惩罚，运行前设：
opts.includeFixedEtaNoZero = true;
opts.outputRoot = fullfile(codeDir,'results_P0_V2_core5');
START_TUKEY_CSSP_P0_V2('core_synthetic',opts);
此时 C5 为固定 eta、无零权重惩罚，共 2200 拟合，新增 C5-C1、C2-C5。
这个扩展比较族必须在拟合前确定。不要将旧的四配置目录直接改成五配置。

5. 真实数据接口与运行

archiveRoot 必须指向原 results_Tukey_CONFIRM_v1 完整归档，至少包含：
cache/ORL_normalized.mat、cache/YALE_normalized.mat；
splits/ORL_r001.mat ...、YALE_r001.mat ...；
calibration/ORL_r001/fold.mat ...、YALE_r001/fold.mat ...；
jobs/<原任务目录>/case.mat。

这是结果归档根目录，不是 B2DLDA1111 原图片目录，也不是 Supplement 的代码目录。
本包需要原标准化缓存、划分、干净开发校准和污染计划记录；第三方图片不附带。
缺文件会停止并显示具体位置，避免自动重划分后与旧表混用。

START_TUKEY_CSSP_P0_V2('real_preflight',opts);
START_TUKEY_CSSP_P0_V2('real_pilot',opts);
START_TUKEY_CSSP_P0_V2('solver_real',opts);
START_TUKEY_CSSP_P0_V2('core_real',opts);
START_TUKEY_CSSP_P0_V2('extension_real',opts);
START_TUKEY_CSSP_P0_V2('main_real',opts);
START_TUKEY_CSSP_P0_V2('tune_real',opts);

real_preflight 验证数据、划分/校准哈希、probe 排除、训练/gallery/probe 的 ID 和污染案例。
real_pilot 默认 YALE+ORL、各第一个 split、Clean/I10/B30、7 配置，共 42 拟合；
它是接口试运行，IsScientificRun=false，不与正式结果混合。

正式默认规模：
- solver_real：YALE/ORL 干净条件、10 split、3 配置、旧/新 = 120 拟合。
  包含此前 ORL split 1/2/8/10 的完整 Auto 配置。
- core_real：2 数据集、5 条件、10 split、4 CORE 配置 = 400 拟合。
- extension_real：同案例、C3/R5/R6/R7 = 400 拟合。
  R5-C3 检验 guard；R6-R5 检验样本加权；R5-R7 检验有 guard 时的零权重校准。
  原 YALE B30 的 guard 是否旁路选择，需要结合每条 Guard/HistoricalSeverity 看。
- main_real：ORL 原七条件、10 split、6 本地 BPCA 配置 = 420 拟合。
  七条件为 Clean/I10/I20/I30/B10/B20/B30，避免只重跑五条件却沿用旧七列表。
- tune_real：ORL Clean/I10/B10、10 split、12 候选 = 360 拟合；
  再做 150 次已保存模型的 probe 评估，不把它们算成额外训练。

一次运行所有正式真实模块：
START_TUKEY_CSSP_P0_V2('paper_real',opts);
默认合计 1700 新拟合 + 150 保存模型的测试评估。
原外部 L1-RBPCA、RA/G2DPCA 依赖没有重新实现或冒名代替；若保留相应正文表，
需按其原实现和输入协议核对/重现，不把本包本地六配置称为全部外部基线。

本包的真实预算默认 [50,5,12]；时间上限保留各 fold 原参数，对同一案例的方法一致。
冻结秩与干净开发参考从原 fold 读取，不在 probe 上重新选择。

TUNE 全部关闭样本加权和元素 guard，固定/自动 eta 共用 severity/零权重规则。
eta 网格 .82/.85/.88/.91/.94/.97；c 网格 2.5/3.5/4.685/6/8。
先仅向候选拟合/指标函数提供 clean gallery，删除 probe/probeLabels 字段；
按 gallery NRE 选固定 eta/c，升序精确平局保留第一个。
全部 case 的 selections/*.mat 锁定后，才评估 clean probe。
五条测试程序为 Auto、eta=.85、验证最佳 eta、c=4.685、验证最佳 c。
这是一组新版的匹配选择结果，不能直接替换旧表数字却沿用旧版 guard 描述。
所有候选成本导出，不主张未计开发校准成本的端到端加速。

6. 共同预算敏感性与新种子确认

START_TUKEY_CSSP_P0_V2('budget_synthetic',opts);
START_TUKEY_CSSP_P0_V2('budget_real',opts);

合成：4 预定诊断条件、10 次、4 CORE 配置、共同 1x/2x 预算 = 320 拟合。
真实：YALE/ORL、Clean/I30/B30、10 split、4 配置、共同 1x/2x = 480 拟合。
2x 同时放宽外层、内层、候选/梯度回溯和软时间上限，对全部比较方法一致。
paired_statistics 中 LeftBudget=2、RightBudget=1；NRE 差值负表示增加预算后误差下降。
预算检查不能替代搜索规则修复，也不等于全局收敛证明。

原 44 条件重新拟合是匹配重评估。若还要独立新种子验证（推荐条件允许时做）：
newOpts=opts;
newOpts.syntheticSeedOffset=70000000;
newOpts.outputRoot=fullfile(codeDir,'results_P0_V2_newSeeds');
START_TUKEY_CSSP_P0_V2('core_synthetic',newOpts);
仍是 1760 拟合；开发映射不重调。先冻结代码/配置，再看新种子结果。

7. 求解器的修改边界

冻结旧源码在 frozen 中，未改变其字节；FROZEN_SOURCE_PROVENANCE.json 给出 SHA256。
legacy 由原 SU_SOLVER 复现冻结旧路径，保留两种原停止分支；它不提供一阶证书。
自检将该路径与冻结真实/合成引擎的小矩阵结果比较。
合成旧版对照是在本包锁定参数下配对重新拟合，不自动等于历史每条原拟合的位级重现。

v2 固定外层 cutoff/sample coefficients/element tangent weights，接受依据为 Qcode。
非加权 L 只做诊断；guard 的条件 F 是加权二次目标，F=Qcode/2。
候选基先 Procrustes 对齐后 QR 回缩；不降 Q 时回退到 Qcode 的切向负梯度与 Armijo。
gradient 是 Qcode 的梯度，包含论文 Q 梯度的 2 倍因子。
只有满足冻结二次梯度条件，内层才返回 surrogate_stationary。
外层同时检查实际投影变化、条件 F 变化、校准状态变化和新锚点梯度。
缩小的 alpha*candidateMove 不作驻点证书；failed_search/timecap/budget_exhausted 分别保存。
全部返回点保留，不按误差或终止状态过滤。
没有全局收敛/高崩溃点/所有污染机制都占优的承诺。

8. 怎样读输出，判断是否值得写进正文

每个正式模块的 summary：
completion.csv：计划记录/已完成/缺失；Complete 只表示记录数量齐，不表示论文已通过审稿。
numerical_checks.csv：新版适用 trial 数、条件上界/接受违反数、未验证 stable 标签数。
fit_records.csv：每次拟合的完整指标、状态、接受次数、梯度、预算、哈希等。
condition_summary.csv：逐条件均值、SD、NRecords 与 NDefined。
paired_case_differences.csv：案例级配对差值。
paired_statistics.csv：配对差值、区间、胜/平/负、比较范围与推断范围。
stop_summary.csv：完整已执行模块的终止状态分布。

所有差值都是 Left-Right。误差指标中负值支持 Left。
GridMean 合成对照先将同一 repeat 的 44 条件差值平均，再用 10 个 repeat 向量做 bootstrap。
SDRepeatBlocks 是这 10 个平均差值的 SD，不把 2640 条方法记录当独立样本。
主要合成 GridMean 使用对称配对差值零假设下的精确 sign-flip 检验（<=20 repeat），
在该模块/数据集的预定义总体比较族内做 Holm；CORE 默认为 3 对照x2指标=6 项。
这个检验假定零假设下差值符号可交换；它不是无条件的分布无关保证。
默认 bootstrap 为 10000，若正文旧版使用 50000/Wilcoxon，应同步写明新协议，或在运行前
明确把 bootstrapResamples 设为 50000 并选新目录；不得将两份协议混写。
逐条件区间是点区间，不是同时置信带；没有事后逐条件显著性挑选。
真实 split 复用图片，区间只描述重复划分变异；PValueSignFlip/HolmP 为 NaN，不作独立受试者推断。
未完成的比较不给正式均值差推断；需要 Complete=1 后解释主结论。

合成额外视图 PositiveRateGrid（36 元组）、CleanZeroRateGrid（8 元组）、
WithoutDominantCondition（去掉预定 coherent/强度4/率.10）是敏感性视图，保留全网格为主要分析。
看 C3-C2 是否稳定改善，可判断自动目标的额外贡献；C3-C4 看零权重校准的实际收益。
若差异主要来自一个条件，应同时报告它和其余条件；负面结果及失败拟合不删除。

TPR0/FPR0/Precision0 基于元素权重恰为零：Z=(We==0)。
ZeroNear 基于 We<=zeroTol；ZeroOperational 是严格 |E|>tau 的归档打分约定。
边界 |E|=tau 可能两者不同，BoundaryCount 显式保存；阈值边界解释主要用于 Tukey。
无污染时 TPR0=NaN；无零权重时 Precision0=NaN；不要改写为 0。
原代码验证 ZeroExact = actualRate*TPR0 + (1-actualRate)*FPR0（两类均存在时）。
mask 仅用于诊断与评估，未传入 cutoff/severity/proposal/acceptance 规则。
模型保存 lastUsedDiagnostics/lastUsedState 与终点重算 finalDiagnostics/finalState。
LastFrozenGradRelative 与 FinalRecomputedGradRelative 对应不同权重状态，不能混用。
新条件检查覆盖所有有限 trial/分支；旧条件检查仅覆盖接受的非 guard Tukey trial，
ConditionalCheckScope 给出分母范围，零次检查不能解释为充分验证。

fits/<案例+方法+版本+预算>/：fit.mat、record.csv、inner_trace.csv、outer_trace.csv。
新版轨迹采用紧凑数值码，字典在模块 trace_codes.csv；旧轨迹在 legacy_inner_trace.csv。
PathCode=1 对齐候选，2 梯度回退。QTrial/QBefore 查看接受；LWouldVeto 只是旧规则的反事实诊断。
数值审计通过并不表示恢复效果一定优于对照；仍需结合主误差、归因与预算结果。
ACC 沿用原函数的 0--1 比例；正文百分数需要乘 100。

9. 停止、续跑和导出给下一轮分析

可在 outputRoot 新建 REQUEST_STOP.flag，程序会在下一次拟合前停止。
Ctrl+C 中断后，已提交 fit.mat 保留；正在运行且未提交的那次会重跑。
删除 REQUEST_STOP.flag，使用相同 opts/命令续跑。
若出现 P0:ChangedSource / ChangedProtocol / Resume，请不要删除签名绕过，改用新 outputRoot。

START_TUKEY_CSSP_P0_V2('summary',opts);
START_TUKEY_CSSP_P0_V2('export_review',opts);

export_review 输出 P0_REVIEW_时间.zip：所有汇总与协议、PDF、TUNE 锁定记录，
以及 ORL 四个已知案例的 Auto 新旧轨迹和强 coherent 的代表拟合。
它不包含原缓存图片；选中轨迹仅为诊断示例，不是全部记录审计的分母。
这个精简包适合回传分析，比压缩全部 fit.mat 更小。

10. 正文更新范围

完成新实验后同步 §3.5.3 接受/搜索、§3.6 停止、Algorithm 1、§4.2 条件下降解释、
§5.1 主恢复表/CORE、§5.2 真实主结果/消融/TUNE/审计、摘要与结论。
新版表现必须由真实输出决定。工程 selftest/quick、旧表和选定救援记录不能替代新主表。
利益冲突真实声明仍须完成；本包实验代码不代为确认作者声明。

原始方法/生成器来源：2026-10-03 最终稿配套冻结 MATLAB 包。
本包只改新 P0_*.m 与新入口；frozen 以原文件 SHA256 保存来源。
标准流形梯度/回缩参考：https://www.nicolasboumal.net/book/
MATLAB 本地函数：https://www.mathworks.com/help/matlab/matlab_prog/local-functions.html
MATLAB Code Analyzer：https://www.mathworks.com/help/matlab/ref/checkcode.html
