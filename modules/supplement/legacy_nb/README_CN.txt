ESS-Tukey-BPCA 补充实验 V2 FIX2 / 2026-11-09
=====================================

FIX2修复CSV导出时标量结构体的转表问题，运行步骤见FIX2_README_CN.txt。
FIX1修复的依赖缓存问题继续保留，历史说明见FIX1_README_CN.txt。
本版专门修复你上传的pilot日志暴露的准备与诊断问题。
V1的工程自检通过，已完成的合成结果仍保留其原有意义；V2不自动覆盖V1。
本版不把“程序保存了拟合”“数值稳定”“性能有优势”混作一种通过。

一、具体调整
------------
1. 真实任务开始前做依赖预检。缺archiveRoot/coilPath时，默认整窗不启动拟合，
   返回BLOCKED_DEPENDENCIES_NO_FITS_STARTED以及dependency_readiness.csv。
   不再先跑一批合成，再重复几十次同样的缺路径错误。
2. 显式scope='synthetic'或'real'，将输出分为windowA_SYN/windowA_REAL等。
   SYN后可补REAL，汇总程序识别两者；禁止ALL与SYN/REAL重叠写入造成重复统计。
3. NB_SETUP_PATHS使用对话框保存路径到NB_LOCAL_PATHS.mat，不修改.m源码。
   位置字段不进入科学协议哈希；同一V2计划后来补正确路径，可在核验输入和参考
   哈希后复用本版已完成拟合。改变算法/网格/种子/数据内容仍会被校验阻止混写。
4. RA的pilot保留正式lambda网格[.1 1 10]，最多100迭代。
   native pilot仍为3 outer/2 inner、16点ESS网格，仅作流程检查。
   RA记录逐轮权重非零比例、协方差范数与秩、最终诊断。
   真正全零权重/零协方差时保留当前基并标记zero_weight_degenerate；
   非退化递推不变。不把零协方差的任意特征向量当作正常优化输出。
5. RUN_RA_PREFLIGHT只使用独立生成的训练数据检查激活，不使用probe、潜在干净
   目标或测试NRE挑lambda。它不证明RA或本文方法准确率更高。
6. pilot输出增加ReadyForPaper。全部拟合已提交且RA未退化，才满足此执行条件。
   paper默认要求同范围pilot就绪；B/E还要求当前RA激活检查就绪。
   budget_exhausted仍是如实保留的预算退出，不被重新标成收敛。
7. RA退化结果保留在原始数据和逐条件均值里，另报可用/不可用数量。
   退化比较在配对表中保留差值，但不进入“优于有效外部基线”的推断。
8. A/C轨迹每10外层打印一次进度，不在线用probe误差控制训练。

二、安装与已有运行
------------------
完整解压至一个新目录；不要覆盖正在运行的V1，不要复制V1的protocol/fit文件到V2。
V1当前A/D合成任务可继续保留，但没有真实归档时A的真实任务仍无法完成。
正式计时窗口A应单独运行，避免其他实验抢CPU。
本版默认新结果目录为源码目录下results_NB_V2_FIX2_20261109。
V1结果没有被自动导入V2，避免新旧RA预算、退出语义与源码记录混淆。

三、先设置真实数据位置
--------------------
在MATLAB把当前文件夹切换到包含START_HERE.m的V2目录。
运行：
  NB_SETUP_PATHS
对话框中选择：
  archiveRoot：同时包含cache、splits、calibration、jobs的原始TC归档根目录；
  coilPath：COIL20灰度objN__angle.png目录，或MAT顶层X(p,q,n)、labels；
  outputRoot：建议取消选择，采用本版默认新结果子目录；不要选源码根目录。
取消某一项会保留原设置；初次取消表示该数据仍未提供。
也可用非交互形式：
  NB_SETUP_PATHS(struct('archiveRoot','H:\实际原归档根目录', ...
      'coilPath','H:\实际COIL20目录'));
这些示例路径必须换成你的真实路径。
显式空字符串可移除某一已保存覆盖值。

找不到TC归档时：
  candidates=NB_FIND_ARCHIVE('H:\Students\Jiang_haijun\Tukey BPCA');
它只搜索与列出候选，不会随意选择目录或伪造归档。
即使候选StructureReady=true，实际窗口仍需通过deep哈希与重放检查。
如果原归档确实不存在，须恢复旧cache/splits/calibration/jobs；
只有原始图像或CSV不能重建“相同划分和相同污染”的旧实验事实。
可以先做显式纯合成计划，不能将它说成完整真实验证。

四、最先执行的检查
------------------
  START_HERE
  CHECK_READY
  PLAN_ONLY
START_HERE只提交工程数值自检通过记录。CHECK_READY单独报告各窗依赖。
原汇总自检打印53 committed/1 missing是故意缺失夹具，随后PASS才是预期。
CHECK_READY仅basic检查；每个窗口启动前默认再做deep检查。

需要B/E时再执行：
  RUN_RA_PREFLIGHT
检查ra_preflight/activation_diagnostics.csv及输出Ready。
若Ready=false，先查全零权重和尺度诊断，不要根据测试集表现强行改参数。
正式RA候选仍按开发验证NRE选择；所有候选、包括退化候选都被记录。
SelectedGridBoundary记录选择是否位于候选网格边界。激活正常不等于调参充分；
若需扩网格，应只依据开发验证安排，重新冻结配置，不能用probe挑选。
若被选中的候选退化，ReadyForPaper=false，不能当成有效外部比较已就绪。

五、两种运行方式：只选一种方案，避免重叠
--------------------------------------
方案A：YALE/ORL与COIL20均已准备，按全部范围：
每窗先pilot，再paper：
  RUN_WINDOW_A_TRAJECTORY('pilot');
  RUN_WINDOW_A_TRAJECTORY('paper');
  RUN_WINDOW_B_COMPARISON('pilot');
  RUN_WINDOW_B_COMPARISON('paper');
  RUN_WINDOW_C_FACTORIAL('pilot');
  RUN_WINDOW_C_FACTORIAL('paper');
  RUN_WINDOW_D_TRANSFER('pilot');
  RUN_WINDOW_D_TRANSFER('paper');
  RUN_WINDOW_E_COIL20('pilot');
  RUN_WINDOW_E_COIL20('paper');
上面是各窗口命令列表，不表示要在同一窗口连续运行全部。
A计时先独立完成；B/C/D/E建议先并发两个窗口，根据CPU和内存再增加。

方案B：目前只具备合成数据：
每个MATLAB窗口先定义：
  S=struct('scope','synthetic');
分别运行：
  RUN_WINDOW_A_TRAJECTORY('pilot',S);
  RUN_WINDOW_A_TRAJECTORY('paper',S);
  RUN_WINDOW_B_COMPARISON('pilot',S);
  RUN_WINDOW_B_COMPARISON('paper',S);
  RUN_WINDOW_C_FACTORIAL('pilot',S);
  RUN_WINDOW_C_FACTORIAL('paper',S);
  RUN_WINDOW_D_TRANSFER('pilot',S);
  RUN_WINDOW_D_TRANSFER('paper',S);
B paper前仍需RUN_RA_PREFLIGHT。
E没有合成任务，不能使用scope=synthetic。
之后取得真实数据，运行NB_SETUP_PATHS更新位置，再在对应窗定义：
  R=struct('scope','real');
  RUN_WINDOW_A_TRAJECTORY('pilot',R);
  RUN_WINDOW_A_TRAJECTORY('paper',R);
  RUN_WINDOW_B_COMPARISON('pilot',R);
  RUN_WINDOW_B_COMPARISON('paper',R);
  RUN_WINDOW_C_FACTORIAL('pilot',R);
  RUN_WINDOW_C_FACTORIAL('paper',R);
  RUN_WINDOW_E_COIL20('pilot',R);
  RUN_WINDOW_E_COIL20('paper',R);
D无真实任务，不运行D的real范围。
同一输出目录内做完SYN与REAL后，不再启动同窗ALL范围。

六、各窗内容与预算
------------------
A：4合成诊断条件x5次x4配置 +4真实条件x5次x4配置；
   正式outer上限200，inner/search保持原值，不设wall cap。
   每10外层显示梯度和已接受步数；梯度是冻结准则诊断，不是全算法收敛证明。
B：4合成条件x30配对种子，YALE/ORL各5条件x10划分，原生控制、
   验证选择固定参数、RA-2DPCA与dim1/dim2等特征数比较。
   正式1860条最终记录、约5080次求解调用，额外开发搜索需要时间。
C：C2固定+零项开，C3自动+开，C4自动+关，C5固定+关。
   C5即前面讨论的F0；保留同残差反事实截断选择诊断。
D：冻结现有合成校准映射，sigma=.05/.20，impulse/coherent rate=.10、strength4；
   30种子，不重新拟合映射。污染幅度保留Xbase MAD约定。
E：COIL20每类4训练、3gallery、其余probe，固定rank8；
   冻结合成校准规则跨域，真实probe评价，不借用YALE参考。

七、恢复与结果判断
------------------
同命令重跑会跳过哈希一致的已提交fit.mat；中断的单次拟合从头重跑。
路径改变不修改源码；数据、参考、预算改变仍会触发科学协议/依赖校验。
修改算法、网格、重复数后请新设outputRoot，并重新START_HERE和pilot。
直接编辑NB_USER_CONFIG.m仍会改变源码哈希；路径更新请使用NB_SETUP_PATHS。
不要删除protocol或绕过哈希检查。
运行中的WINDOW_RUNNING.lock保护同一范围；短暂WINDOW_A_SCOPE.lock等保护范围注册。
强制关闭MATLAB留下锁时，确认对应进程退出后再删除锁。
REQUEST_STOP.flag会在当前拟合完成后停止。

查看RUN_STATUS.json：
 AllPlannedCommitted=true：全部预定拟合已保存；不等于收敛。
 UnusableBaselines=0：没有已识别的RA全零退化；不等于基线最优。
 ReadyForPaper=true：执行检查允许进入正式阶段；不表示方法获胜或论文可接受。

所有窗口停止后：
  RUN_ALL_SUMMARIES('paper');
主要结果在paper/summary；A轨迹图在paper/figures。
新增RA_weight_trace.csv、selection_locked.csv、dependency_readiness.csv用于诊断。
汇总记录不遗漏失败、退化或预算退出；不同sigma和模块不随意混合。
真实区间描述重复划分变异，不能当成独立受试者推断。

八、限制与验证范围
------------------
V1在你提供日志中已经实际通过MATLAB R2025a工程自检。
V2 FIX1已在用户MATLAB环境通过工程自检，但实际pilot暴露CSV导出问题。
FIX2已做静态修改范围核对；当前交付环境没有MATLAB/Octave，新增导出检查尚未执行；
请执行新版START_HERE，再跑pilot。不能拿V1的PASS文件替代。
RA是作者R算法的MATLAB移植，不是官方MATLAB。
BA2DPCA仍待可核验源码，本版不冒充已经完成第二个外部基线。
本版不通过改标签、调低外部方法预算或删除失败样本制造优势。
