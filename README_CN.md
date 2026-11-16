# ESS-Tukey-BPCA 完整实验代码整理包

对应稿件：**Weight-Based Cutoff Calibration for Tukey Bilateral PCA:
Properties and Empirical Limits**。整理日期：2026年11月16日。
当前属于研究代码发布准备版，不表示稿件已经录用或发表。

作者：蒋海俊、徐刚刚、蒋芬、王悦、李新宇；通讯邮箱：xinyuli1322@163.com。

## 本包包含什么

| 位置 | 内容 | 当前可复现范围 |
|---|---|---|
| `modules/core` | 主实验、修订与历史求解器、完整辅助函数 | 合成可自行生成；真实结果需原冻结归档 |
| `modules/sample_extension` | 新增样本层E/E+S实验全部源码 | 可独立生成数据，8次预检＋80次正式拟合 |
| `modules/supplement` | INIT、四格、外部比较、YALE选参、B10预算等后续运行器及NB源码 | 有运行程序不等于已完成相应结果 |
| `tools/historical_replay` | 历史初始化/终点识别协议复算工具 | 需原历史模型、检查点和一致源码 |
| `evidence` | 论文分析所用CSV记录 | 可复算导出统计；不包含原图及全部拟合模型 |
| `analysis`、`reproducibility` | 图表、误差分解与来源核验程序 | 从已附CSV重画和重算，不拟合新模型 |
| `reference_figures` | 主文和补充材料参考图 | 用于查看论文所用图件 |
| `provenance` | 保留文件哈希及本次整理范围 | 数值MATLAB源码保持原样 |

没有将论文修改快照、内部查询记录和待完成研究计划PDF混入公开代码。
源码中的少数历史Windows路径属于冻结版本，统一入口通过显式参数覆盖；
请不要为清理历史路径而修改正在续跑的源码。

## MATLAB最先执行的命令

把MATLAB当前文件夹切到本仓库根目录，执行：

```matlab
RUN_EXPERIMENTS('check');
RUN_EXPERIMENTS('selftest');
RUN_EXPERIMENTS('sample_selftest');
```

上述步骤用于目录/依赖检查与原程序自检。不要对整个仓库执行
`addpath(genpath(...))`，因为不同冻结模块包含同名函数。
主要环境为作者使用的MATLAB R2025a，并需要启用JVM。
本次整理没有原生MATLAB运行环境，不能把静态解析通过写成MATLAB已运行通过。

## 运行新增80项样本实验

```matlab
RUN_EXPERIMENTS('sample_all');
```

默认写入`results/sample_extension`。首次运行先做8次预检，再做80次正式拟合。
正式数据完全由程序生成，不需要人脸图片或旧归档。已有相同签名的完成项会复用。
`sample_formal`只用于同一输出目录已经完成预检之后；新目录请用`sample_all`。

原始47个样本模块MATLAB文件全部保留，已与回传正式结果中的47个源码哈希核对。
如需停止，在另一个MATLAB窗口执行`REQUEST_EXPERIMENT_STOP('sample')`；
恢复前删除输出目录中的`STOP_SAMPLE.txt`，再执行同一命令。
自定义输出目录时，停止函数也要传同一个目录。

## 运行主实验

```matlab
RUN_EXPERIMENTS('core_synthetic');
RUN_EXPERIMENTS('budget_synthetic');
RUN_EXPERIMENTS('solver_synthetic');
```

三项分别对应1,760、320、240条计划记录。不同模块可能复用相同数据或模型，
记录数不能全部相加当作独立试验数。上传代码无需重新跑这些已完成的正式任务。

真实实验必须指定包含`cache/splits/calibration/jobs`的完整冻结归档：

```matlab
opts = struct('archiveRoot','D:\TukeyData\frozen_archive');
RUN_EXPERIMENTS('real_preflight',opts);
RUN_EXPERIMENTS('core_real',opts);
```

只下载ORL/YALE图片，或只持有本包的CSV，无法精确重建论文真实数据协议。
输入归档的内容和获取安排见`docs/DATA_SETUP.md`。

## 后续补充实验

```matlab
opts = struct('archiveRoot','D:\TukeyData\frozen_archive');
opts.modules = {'01_initialization'};
RUN_EXPERIMENTS('supp_plan',opts);
% 输入就绪后，依次使用supp_pilot和supp_paper。
```

其余模块为`02_factorial`、`03_external`、`04_yale_selection`、`05_b10_budget`。
默认只安排INIT，避免无意间启动全部长任务。选定任务清单变化时使用新输出目录。
BA2DPCA缺少可核验实现，ROMPCA需另外准备原作者R源码和依赖，不能标成已成功比较。
详见`docs/EXTERNAL_METHODS.md`。

## 不启动拟合，也能核查和重画

在终端中执行：

```bash
python tools/verify_release.py
python -m pip install -r requirements.txt
python analysis/reproduce.py --mode all
```

第一条只依赖Python标准库，核对保留源码和配对记录；后两条安装绘图依赖，
复算误差分解及主要图件。输出位于`generated`和`figures`。
历史轨迹仍需原检查点归档，当前CSV不能重放全部优化过程。

## 上传GitHub

请按`docs/GITHUB_UPLOAD_CN.md`操作，将解压后的仓库内容上传。
建议仓库名`ESS-Tukey-BPCA`。不要将整个ZIP作为唯一仓库内容，否则GitHub无法直接浏览代码。
许可证尚未指定，`THIRD_PARTY_NOTICES.md`已说明各部分来源和状态；未擅自给整个vendor授予MIT。
完成发布后，将实际仓库URL和固定版本号填入稿件Code availability。

基金：云南省教育厅科学研究基金项目，编号2026Y0763。
