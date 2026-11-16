V2 FIX1：selftest 的 severityMemoryMode 缺失修复

原因：自检先创建合成参数 A，再复制成真实旧求解器工程回放参数 Ar。
Ar.useSeverityMemory=true 后，冻结旧求解器会读取 Ar.severityMemoryMode。
旧包未赋值该字段；因此在 P0_SELFTEST 约第 83 行报错。
这是自检配置遗漏，不是人脸数据读取失败，也不是正式恢复实验的性能结果。

唯一 MATLAB 源码修改：
P0_SELFTEST.m 中，在下述代码之后：
Ar=A;Ar.useSeverityMemory=true;Ar.realTailReferenceEnabled=false;
插入：
Ar.severityMemoryMode='max';

'max' 来自冻结 V1.7 配置，表示历史最大 severity：
h_memory = max(h_memory, h_current)。
无需修改 frozen/SU_FROZEN.m、P0_ALG.m 或正式 fold 参数。
仍执行旧版与仪器化求解器的子空间一致性检查，不绕过 selftest。

推荐操作：
1. 若命令提示符为 K>>，先输入 dbquit，回到普通 >>。
2. 将修订 P0_SELFTEST.m 覆盖到包含 START_TUKEY_CSSP_P0_V2.m 的那一层目录。
   不要放入 frozen，也不要只在命令行给临时变量赋值。
3. 在 MATLAB 执行 clear P0_SELFTEST; rehash;。
4. 建议使用新的输出目录 results_P0_V2_FIX1，保留旧目录，避免源文件签名冲突。
5. 先单独运行 selftest。看到 Pass=1 后再运行 quick。
6. quick 正常完成后再运行 real_preflight、real_pilot。

可复制的 MATLAB 命令（保持 codeDir 为你的实际解压路径）：

cd(codeDir);
clear P0_SELFTEST;
rehash;
opts = struct();
opts.archiveRoot = 'H:\Students\Jiang_haijun\Tukey BPCA\results_Tukey_CONFIRM_v1';
opts.outputRoot = fullfile(codeDir,'results_P0_V2_FIX1');
which P0_SELFTEST -all
report = START_TUKEY_CSSP_P0_V2('selftest',opts);
assert(report.Pass,'Selftest failed');

确认自检完成后再执行：
START_TUKEY_CSSP_P0_V2('quick',opts);
START_TUKEY_CSSP_P0_V2('real_preflight',opts);
START_TUKEY_CSSP_P0_V2('real_pilot',opts);

函数启动横幅仍显示 CSSP-Tukey-P0-V2-20261004：FIX1 没有改变算法版本字符串。
使用 which 确认文件路径；也可用下面命令确认模式赋值已存在：
assert(contains(fileread(which('P0_SELFTEST')), "Ar.severityMemoryMode='max'"));

交付环境没有 MATLAB/Octave。FIX1 已完成配置字段静态回归检查、
原有独立数学复核、MATLAB 词法/块结构检查和冻结依赖哈希核查。
这里未宣称作者环境中的完整 MATLAB selftest 或正式实验已经通过。
