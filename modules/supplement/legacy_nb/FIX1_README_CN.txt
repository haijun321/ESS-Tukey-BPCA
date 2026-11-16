V2 FIX1 / 2026-11-06
====================

修复用户MATLAB R2025a实际报错：NB_PREFLIGHT在向results缓存写入时出现
“在不同结构体之间进行下标赋值”。

原因：results和coilResults以无字段struct([])初始化，后续整体写入具有
Ready、Reason字段的记录。FIX1用同一statusTemplate创建有字段的零行列缓存，
临时result/cr也来自同一模板，插入时使用(end+1,1)。两处缓存一并修正。

只修改两份MATLAB源码：
  NB_PREFLIGHT.m
  NB_PREFLIGHT_SELFTEST.m
补充有效COIL工程夹具的深度缓存复用检查，以及空任务数组检查。
不改变拟合算法、校准规则、种子、数据划分、评价指标或正式预算。

更新方法：
  完整包解压后，也可只把上述两个.m复制覆盖到正在使用的V2代码根目录。
  不修改vendor，不删除旧结果，不手工编辑已冻结protocol.mat。

用户已找到结构完整候选归档：
  H:\Students\Jiang_haijun\Tukey BPCA\results_Tukey_CONFIRM_v1
目录结构已满足基本检查；数据与参考哈希仍由deep预检核实。

在更新后的V2目录中执行：
  clear NB_PREFLIGHT NB_PREFLIGHT_SELFTEST START_HERE
  NB_SETUP_PATHS(struct('archiveRoot', ...
      'H:\Students\Jiang_haijun\Tukey BPCA\results_Tukey_CONFIRM_v1'));
  C=NB_BOOTSTRAP();
  NB_PREFLIGHT_SELFTEST
  START_HERE
  CHECK_READY

如果V2尚未完成工程自检，直接修复并重跑即可。
如某些V2输出已有冻结协议，源码更新后应采用新outputRoot并重跑对应pilot；
保留旧输出，不绕过哈希检查混写。路径设置继续使用NB_SETUP_PATHS。

NB_PREFLIGHT_SELFTEST应输出PASS、Checks=7。
原汇总夹具的53 committed/1 missing是故意缺失测试，不是真实实验缺失。
工程自检中的RA lambda=.1全零提示是已识别的候选退化，不是本次结构体错误。
START_HERE完整通过之后，再执行RUN_RA_PREFLIGHT与相应pilot；暂不直接启动paper。

验证范围：已通过静态MATLAB语法检查；此环境没有MATLAB/Octave，
仍需在用户R2025a执行上述回归测试。不能将静态检查称作MATLAB运行通过。
