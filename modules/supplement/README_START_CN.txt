CSSP Tukey-BPCA 五项补充实验：2026-11-15
========================================

这是基于已找到的2026-10-31 P0数值求解器和2026-11-09 NB FIX2源码整理的补充实验包。
原数值内核保存在legacy_nb/vendor，新增驱动不改写Tukey目标、校准映射或接受准则。
本包是代码，不是已完成的真实数据实验结果，也不保证算法取得正面结果。

一、先了解当前验证边界
1. 制作环境没有MATLAB、Octave或Rscript，未执行原生MATLAB/R实验。
2. MATLAB静态检查和独立Python数学检查见VALIDATION_STATUS.json及tests/。
3. CSSP_SELFTEST.m是要在你的MATLAB执行的真实数值自检；正式入口自动执行。
4. 当前没有可核验的BA2DPCA经典原始实现。保留适配器接口和BLOCKED记录，不用自写近似冒充。
5. ROMPCA已经接入原作者R代码调用，但需先安装R和原作依赖、下载固定版本原源码。
6. 可选RA2DPCA_dev是既有MATLAB移植，单侧特征维数不等同双边r*c，不默认替代经典BA。

二、路径只在CSSP_USER_CONFIG.m中填写，不弹出目录选择框
archiveRoot必须是原始已完成TC实验归档根目录，内含：
  cache/YALE_normalized.mat 与 ORL_normalized.mat
  splits/YALE_r001.mat 等
  calibration/YALE_r001/fold.mat 等
  jobs/*/case.mat
这是冻结的数据、划分、校准和污染注入凭据，不是原始人脸图像目录。
程序会尝试TUKEY_ARCHIVE_ROOT环境变量和已知旧路径：
  H:\Students\Jiang_haijun\Tukey BPCA\results_Tukey_CONFIRM_v1
若找不到，设置例如：
  U.archiveRoot='H:\你的真实归档目录';
  U.outputRoot='H:\Students\Jiang_haijun\Tukey BPCA\results_CSSP_20261115';
若提示缺cache/splits/calibration/jobs，请定位或恢复原归档，不要创建空文件夹绕过检查。
本包不会从重新排序的原始图片生成一个假称相同的旧划分。

三、运行顺序
解压完整文件夹，在MATLAB中进入本README所在目录，然后执行：
  CHECK_CSSP_READY
它只核对数据依赖及任务计划，不拟合模型、不评价probe。

建议先配置ROMPCA，见EXTERNAL_SETUP_CN.txt。已安装R时可执行：
  C=CSSP_SETUP('paper');
  CSSP_SETUP_ROMPCA('download',C);
  CSSP_SETUP_ROMPCA('install',C);
  CSSP_SETUP_ROMPCA('check',C);
安装是显式步骤，主科学实验不下载或安装软件。

然后执行工程试运行：
  RUN_CSSP_PILOT
pilot缩小重复和预算，仅检查管线；数据仍来自冻结归档，不能作论文科学结果。

检查完成后执行正式计划：
  RUN_CSSP_SUPPLEMENT
默认依次执行五个模块。单独重汇总：
  RUN_CSSP_SUMMARY

四、五项计划（正式默认）
01_initialization：两数据集×五条件×十划分，保存INIT与C1-C4的同协议读出。
02_factorial：相同100实例，保存C2/C3/C4/C5；C5就是固定eta=.85且关闭零权重惩罚。
03_external：C1/C3作参照，默认L2、BA2DPCA、ROMPCA；缺原作依赖明确BLOCKED，其余任务继续。
04_yale_selection：YALE五条件十划分；eta六候选、c五候选；先按gallery NRE锁定，再评价probe。
05_b10_budget：两数据集B10十划分C1-C4，B1=50/5/12、B2=100/10/24；无墙钟上限。

C1：固定Tukey尺度倍数；C2：固定ESS目标+零权重项；C3：自适应ESS目标+零权重项；
C4：自适应目标、无零权重项；C5：固定目标、无零权重项；所有核心比较关闭guard与样本层。
旧包C5已存在，本次接通完整100实例计划，没有另造新算法。

如只运行指定模块，可在命令行显式指定：
  CSSP_RUN('paper',struct('modules',{{'01_initialization','02_factorial'}}));
不同科学计划应使用不同outputRoot，程序禁止在已冻结输出根目录静默改变计划。
默认串行运行。不要同时启动共享同一stage的多个MATLAB进程。

五、复用与继续运行
模块共用native_cache，训练身份按实际X/mask/U0/V0、方法、算法参数和数值源码计算。
标签或模块改变不算新的训练；候选eta=.85和c=4.685可与对应CORE模型共用。
已有P0正式结果可在CSSP_USER_CONFIG里设置：
  U.priorResultRoots={'H:\你的旧results_P0_V2_FIX1'};
仅当旧source_manifest和当前源码、数据、初始化、参数、正式标记均严格吻合才导入。
CSV汇总、旧TC求解器、pilot、不同预算或缺初始化凭据不能当作相同模型复用。
旧模型只有终点时，仅提供真实初值/终点两个点，并标记EndpointOnlyImported；不虚构中间轨迹。
再次运行相同入口会核对并跳过已提交结果，失败/缺依赖的任务仍待完成。
REQUEST_STOP.flag会在下个任务开始前停止；当前长拟合中可用MATLAB Ctrl+C中断，已提交缓存保留。
RUNNING.lock只在确认没有对应MATLAB进程运行、且确实为异常残留时才删除。

六、结果在哪里，怎么看
results_CSSP_20261115/paper/<module>/fits/<task>/fit.mat：单项读出与出处。
paper/native_cache：唯一原生训练模型及实际成本，不与独立样本数混同。
paper/selection_locks：候选验证分数和probe评价前的参数锁。
paper/task_status.csv：每一计划项COMMITTED/REUSED/BLOCKED/FAILED。
paper/run_status.json：完整执行状态；存在缺失基线时不会标记全部完成。
paper/summary/：配对差、四格交互、分条件表、五条件等权汇总、图及缺失任务。
初始化任务下mechanism_candidates.csv：同一初始残差的候选校准图数据。
NRE差<0、ACC差>0有利于差值左侧方法；ACC另给百分点。
有限failed_search、timecap和budget_exhausted终点保留，不按不利结果删任务。
未完成与不可用基线另列，不能把只有部分完成的表当作完整方法比较。
真实重复划分重用图像，汇总是配对描述，不声称独立人样本显著性或统计等价。
历史模型训练成本与本次cache读盘耗时分开，不能据cache命中宣称算法加速。

七、目前不随包提供的外部原作
BA2DPCA / L2pSB2DPCA：需要可核验原始代码及适配器，契约见EXTERNAL_SETUP_CN.txt。
ROMPCA：为避免未经确认的第三方再分发，本包提供作者源下载器、SHA256固定值和R桥接，
不把作者R代码伪称为本包原创MATLAB实现。R原作仍须在你的机器上进行pilot。
只删掉未完成方法名称、修改停止标签或降低检查标准，都不等于补全对照实验。

八、写作前需另行完成
结果生成后仍须核对初始化增量、四格交互、外部对照和验证选参的具体方向。
主程序不会自动宣布普遍性能优势、数值收敛、论文可录用或全部实验已支持创新。
需要更新论文时，以完整结果和缺失说明为依据；不要改用probe选择参数或检查点。
