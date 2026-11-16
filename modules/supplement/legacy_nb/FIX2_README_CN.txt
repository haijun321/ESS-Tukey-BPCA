ESS-Tukey-BPCA V2 FIX2 / 2026-11-09
================================

一、修复原因
NB_RUN导出saved.record时，记录内BaselineIssue=''等空文本有0行，
数值指标有1行。struct2table对标量结构体的默认解释会因此报错。
修复为struct2table(...,'AsArray',true)，明确每个结构体对应一条记录。

二、修改文件
NB_RUN.m：8处结构体转表调用，包含record、选择、权重与轨迹导出。
NB_SUMMARIZE.m：汇总结构体列表显式采用一结构体一行。
RUN_RA_PREFLIGHT.m：激活检查导出显式采用一结构体一行。
NB_PIPELINE_SELFTEST.m：增加真实拟合记录的CSV写入/读回检查，覆盖
  空文本、单条/多条选择记录、权重与A窗口轨迹诊断。
NB_CONFIG.m：默认输出改为results_NB_V2_FIX2_20261109。
NB_FIT.m：仅更新记录中的CodeVersion为FIX2，不改变求解与指标逻辑。
vendor、instrumented、external内的代码保持原字节内容。

三、推荐运行方式
将完整包解压到新目录。在MATLAB中进入含START_HERE.m的文件夹，
然后依次执行以下命令。确认其他窗口未在使用待替换的代码。

  clear functions
  rehash
  codeDir=pwd;
  assert(isfile(fullfile(codeDir,'START_HERE.m')),'请先进入新代码目录。');
  addpath(codeDir,'-begin');
  NB_SETUP_PATHS(struct( ...
      'archiveRoot','H:\Students\Jiang_haijun\Tukey BPCA\results_Tukey_CONFIRM_v1', ...
      'outputRoot',fullfile(codeDir,'results_NB_V2_FIX2_20261109')));
  validation=START_HERE();
  assert(validation.Pass&&validation.Pipeline.CSVExportRoundtrip, ...
      '新版自检及CSV导出检查尚未通过。');
  O=struct('scope','all');
  A_pilot=RUN_WINDOW_A_TRAJECTORY('pilot',O);
  disp(A_pilot);

只有A_pilot.ReadyForPaper为1时，再执行：
  A_paper=RUN_WINDOW_A_TRAJECTORY('paper',O);

四、已有结果与哈希
这次日志在首条记录的CSV导出时失败，尚未执行该条fit.mat的提交。
FIX2需要重新START_HERE。原pilot/windowA/protocol.mat包含旧SourceHash，
因此应采用上述新的输出目录，保留原目录用于追溯。
源码与科学参数哈希检查继续生效，不手工改写旧协议或PASS文件。

五、检查修复后的实际运行
A pilot预计32条记录。查看结尾的AllPlannedCommitted、FailedOrBlocked、
ReadyForPaper，并检查fits子目录中的fit.mat及record.csv是否实际生成。
pilot就绪只代表执行检查通过，不代表方法具有性能优势。
B/E正式运行仍要求RUN_RA_PREFLIGHT；E仍需要真实COIL20的coilPath。

六、验证范围
本交付完成修改范围、导出调用和压缩包完整性的静态核对。
当前环境没有MATLAB/Octave，未实际执行新增的原生回归检查。
请以本机START_HERE及随后A pilot的实际输出为运行验证依据。
官方接口说明：https://www.mathworks.com/help/matlab/ref/struct2table.html
