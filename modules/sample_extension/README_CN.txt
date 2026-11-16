Tukey-BPCA 样本层增量实验 v1
日期：2026年11月15日

一、直接运行

1. 完整解压本压缩包，保留vendor子目录。
2. 建议打开一个新的MATLAB窗口，将本文件所在目录设为当前文件夹。
3. 在命令窗口输入：

   START_SAMPLE_EXTENSION

也可以打开START_SAMPLE_EXTENSION.m并点击运行。
程序不需要旧归档、YALE/ORL图片或交互选择目录。全部合成数据自动生成。
默认结果保存在本包目录下的 results_sample_extension_v1。

二、默认运行顺序与数量

先执行数据、权重开关、指标、IO自检；这些不算模型拟合。
然后执行8次预检：4种条件 × 1个预检种子 × E/ES两配置。
预检预算为外层6次、内层2次、提案回溯6次、每次30秒软上限。
只有8次预检都产生有效且有限的主要指标，才继续正式实验。
预检不按性能好坏作通过标准，不用于调参，不进入正文统计。

正式实验：4种条件 × 10个配对种子 × E/ES两配置 = 80次拟合。
正式预算：外层60次、内层10次、提案回溯20次、每次180秒软上限。
时间上限是软限制，不是总耗时承诺；初始化、保存与汇总另外计时。
两阶段使用互不重叠的种子，结果分别保存在precheck和formal内。

三、实验内容

训练：240张40×30矩阵，左右秩5和4；背景高斯噪声标准差0.1。
独立评价探针：同一真实左右载荷下新生成240张潜在干净信号矩阵，不加背景噪声，不参与训练、初始化或选参。
信号核心分布、污染幅度定义与原合成设置一致；本包采用独立、分离的随机数流。
固定强度kappa=4，幅度为加污染前Xbase的稳健MAD尺度乘以4。

Clean：无额外人工异常，仍保留0.1背景噪声。
CellOnly：全部训练条目的10%受脉冲污染。
CaseOnly：24/240张矩阵加入整矩阵独立高斯扰动。
Mixed：相同24张矩阵加入相同整矩阵扰动；其余216张矩阵的10%元素受脉冲污染。
Mixed的两个比例是10%整样本污染、非case矩阵内10%元素污染，联合条目覆盖19%，不是总污染10%。
case_labels、局部cell_mask及联合total_mask分别保留。
局部坏元素所在矩阵不自动标为case异常。
四条件共享基础信号、背景噪声和评价探针。
各条件从自己的观测计算稳健初始化；同条件E/ES共享这个初始化。

E：原C3元素校准，关闭元素guard及样本层。
ES：同一C3、同一求解器、同样关闭元素guard，只打开现有合成样本层。
ES保留双侧MAD样本评分、max(3,Q85)阈值、v>=0.20、alpha=0.35。
本轮没有新增样本ESS选参，样本ESS只作为诊断；实际系数a=v^0.35>=0.569325。
cleanGuard=false时原代码会调用样本层，不因元素严重度为0额外旁路；分数尺度退化时原规则回退单位权重。
元素映射与全部原有校准常数冻结；不根据这80次结果改参数或挑污染强度。

四、输出与评价口径

主要指标：ErrSubNorm，沿用原有左右投影矩阵误差定义。
关键次指标：ProbeCleanNRE，独立潜在干净探针的投影损失。
TrainNRE：受污染训练输入投影对全部原潜在信号的误差。
NonCaseNRE：只在未受整样本污染的矩阵上汇总的相应误差。
TrainSignalNRE：估计子空间对训练潜在信号的投影损失。
RetainedPerturbationNRE2：保留的背景噪声与人工污染的归一化平方能量。
误差分解自检使用包含背景噪声的全部扰动，不用旧Absorption列代替。

sample_records.csv中的：
Aused：最近一次有接受更新的外层步骤所使用的样本系数；无接受更新时为共同初始化的单位系数，HadAcceptedUpdate=0。
Dused：上述接受更新锚点的RMS样本残差；无接受更新时为NaN。
Aattempted、Dattempted：最后一次尝试求解的锚点系数和分数。
Afinal、Dfinal、Vfinal：最终基下重新计算的样本系数、RMS残差及原始v权重。
这些字段不能混称为相同的实际拟合权重。
SampleESS、CaseMeanA、NonCaseMeanA等主要样本系数汇总使用Aused。
CombinedESS使用最终重算的元素×样本联合权重，不能与样本ESS混为一谈。
sample_trace.csv记录每个外层尝试锚点的权重诊断，列名均带Attempt前缀。

SampleAUROC/AP：两方法统一用最终RMS残差Dfinal作为上尾只读诊断分数；不是拿E的全1系数作为检测分数，也不同于ES双侧加权评分。
Clean/CellOnly没有case阳性时AUROC/AP为NaN（不适用）。
NonCaseDownweight95：非case样本a<0.95的比例，含义是系数降低超过5%的操作性诊断，不等于异常判定或完全拒绝。
合成数据没有类别标签，不报告ACC。

五、统计与结果判读

正式统计单位是10个独立种子块，不是240张矩阵、像素或探针数量。
主要比较预先限定为CaseOnly、Mixed的ES减E子空间误差。
Clean、CellOnly检查可能的代价；保留所有不利结果。
每条件输出配对差、平均差、SD、95%种子bootstrap区间及更低/相同/更高次数。
不将四条件视为40个独立重复，不输出P值或“实验通过/论文可录用”的判断。
有限的timecap、budget_exhausted、failed_search端点仍作为预算内结果保留。
runtime_error和缺失拟合单独计数；完整配对不足10时必须说明证据不完整。
共同预算不等于优化收敛。SampleESS降低或异常权重变小本身不证明任务受益。

六、断点续跑与停止

中断后再次运行START_SAMPLE_EXTENSION。已完成拟合只有在源码、配置、观测和初始化签名一致时才跳过。
每次运行最多重试一次已保存的runtime_error；原失败记录会另存为failed_attempt文件。
若修改科学设置或MATLAB源码，必须更换新的outputRoot，程序会拒绝混用旧结果。
默认已有结果绝不向正在运行的旧P0/NB任务写入。

安全停止：在另一个空闲MATLAB窗口运行本包STOP_SAMPLE_EXTENSION，程序会在当前拟合结束后停下。
恢复前删除results_sample_extension_v1/STOP_SAMPLE.txt，再运行入口。
Ctrl+C也可中断；当前尚未提交的拟合会在下次重跑。
同一个结果目录不能同时启动两个写入进程。若MATLAB异常退出留下.sample_run_lock目录，确认没有本包任务运行后再手动删除该锁目录。
使用过自定义outputRoot时，停止标志也应写到对应结果目录。

七、最重要的结果文件

formal/fit_records.csv：80条计划拟合的逐项结果（结束后应有80条，runtime_error也占一条）。
formal/initialization_records.csv：40个共同初始化评价读出，不是额外拟合。
formal/sample_records.csv：逐矩阵权重与诊断。
formal/summary/completion.csv：各条件/方法的完整、失败、缺失计数。
formal/summary/paired_summary.csv：ES减E及终点减初始化的配对汇总。
formal/summary/main_results.tex：可接入论文的结果表片段；需要graphicx。
formal/summary/sample_extension_diagnostics.png：配对误差、样本ESS及权重分配图。
sample_results_for_review.zip：程序结束或安全暂停后生成的精简核查包，适合回传分析。
完整cases数据、拟合基及优化轨迹仍保存在本地结果目录；精简核查包不是完整复现归档，请保留整个目录。

仅重新汇总（不重新拟合）：
   SMP_RUN('summary')
仅运行/恢复正式阶段（要求预检已完成）：
   SMP_RUN('formal')

八、来源与验证范围

求解器来自你提供的Tukey_CSSP_P0_Experiments_V2_20261004源码快照。
vendor内函数统一增加SMPV_前缀，避免与旧任务同名函数冲突。
优化/接受规则不变；求解器只新增只读样本诊断，并把不可用的真值条件诊断置NaN。
真实污染标签没有传入校准或求解器，全部在SMP_METRICS中评价。
vendor/PROVENANCE.json记录原始及打包源码摘要。

本交付环境没有MATLAB或Octave。已进行静态MATLAB语法检查、接口审查和独立数值规格检查；没有执行原生预检或80次正式拟合。
本包的SMP_SELFTEST及8次预检将在你的MATLAB中实际执行。若预检报错，不会自动进入80次正式实验；请保留完整报错和已生成的结果。
