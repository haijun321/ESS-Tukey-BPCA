# 上传GitHub的具体步骤

建议仓库名：`ESS-Tukey-BPCA`。本包已经包含README、中英文运行说明、
统一MATLAB入口、Python依赖、引用信息和忽略规则。

## 1. 解压并确认目录

解压后，进入同时包含`README.md`、`RUN_EXPERIMENTS.m`、`modules`和`evidence`
的文件夹。该文件夹就是仓库根目录。不要上传旧稿件完整工作包，也不要只把ZIP
作为仓库的唯一文件；应上传本包解压后的目录内容。

## 2. 创建空仓库

登录GitHub，点击New repository，填写仓库名和说明。
说明可写：`Research code for weight-based cutoff calibration in Tukey bilateral PCA.`
选择所需可见性。使用下面Git命令导入时，不勾选初始化README或.gitignore，
避免与已有文件冲突。许可证请在确认发布范围后选择，本包未擅自指定。

## 3. 推荐用Git推送整个目录

Windows上安装Git后，在解压文件夹内打开Git Bash。
将下面URL中的`YOUR_USERNAME`替换为你的GitHub用户名；仓库名按实际名称调整：

```bash
git init -b main
git add .
git commit -m "Add Tukey BPCA research code and reproducibility materials"
git remote add origin https://github.com/YOUR_USERNAME/ESS-Tukey-BPCA.git
git push -u origin main
```

首次提交若Git要求姓名/邮箱，按Git提示设置你自己的提交身份；推送时按GitHub
提供的登录流程认证。不要将认证信息写入代码文件。

如果你是在已有仓库工作，请先克隆或同步那个仓库，再复制本包内容并提交，
不要在已有仓库中重复执行初始化或覆盖已有remote。

本包的`.gitattributes`用于保持源码和CSV的原始字节，避免Windows自动换行转换
破坏续跑哈希。不要为了上传而批量格式化冻结MATLAB源码。

## 4. 网页上传的替代方法

在空仓库中点击Add file → Upload files，上传解压后的内容。
GitHub当前网页上传每个文件限制25 MiB，每次最多100个文件；本包文件较多，
建议使用Git或GitHub Desktop，网页方式需要分批上传。
各层目录结构必须完整，尤其是`modules/core/frozen`、
`modules/sample_extension/vendor`及`modules/supplement/legacy_nb`。

## 5. 上传后查看与固定版本

确认GitHub首页显示README，`modules`中能直接浏览`.m`文件，并能打开
`docs/EXPERIMENT_MAP.md`。可在本地执行：

```bash
python tools/verify_release.py
```

发布确定后，可以创建与当前软件版本对应的`v0.1.0`标签/Release。
把实际仓库URL、版本号和访问安排写入稿件Code availability，若将来生成DOI再补入。
不要把准备好的仓库文件误称为已经上传、已经获得DOI或已经完成所有待跑实验。

## 6. 哪些内容保持在仓库之外

原始ORL/YALE图片、冻结cache/splits/calibration/jobs、完整模型和长轨迹结果
保留在外部数据归档中。忽略规则已覆盖常用输出目录和本机配置；若自定义输出到
仓库内其他位置，需要相应更新忽略规则。附带的`evidence`是已有结果CSV，
不是完整原图和模型档案。

本包未包含可核验的BA2DPCA原作实现，ROMPCA需另外准备R环境和固定源码。
这不会影响主合成或新增样本实验，但影响相应外部对照任务。

参考GitHub官方说明（核查日期2026年11月16日）：

- https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository
- https://docs.github.com/en/repositories/working-with-files/managing-files/adding-a-file-to-a-repository
