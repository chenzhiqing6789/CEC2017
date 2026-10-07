# RLDSBO CEC2017 复现包

相关算法源码、已有逐次记录、统计脚本和新实验入口。原始框架不变；其他测试集、无关优化器、重复工具及临时文件不进入本包。

## 先使用哪个入口

| MATLAB 命令 | 输出与适用范围 |
|---|---|---|
| `report = reproduce_archived_results;` | 已有5算法×30函数×30次记录的均值、样本标准差、符号秩p值、逐函数均值排名；不重新优化 |
| 生成新的实验记录 | `cfg = cec2017_config; raw = run_cec2017(cfg);` | 默认15算法×30函数×30次；每次上限300000次实际目标函数调用 |
| 对新实验进行统计 | `report = analyze_results(raw,cfg.outputDir,'RLDSBO');` | 完整的均值、标准差、双侧Wilcoxon符号秩检验和Friedman统计 |
| 检查软件运行 | `addpath('tests'); run_validation;` | 小预算真实CEC函数测试、种子重复、非整代预算、断点续跑、数据完整性和历史表格核验 |

在 MATLAB 中先将当前目录切换到本包根目录。需要 **64位 Windows、MATLAB 和 Statistics and Machine Learning Toolbox**；已在 **MATLAB R2022b 9.13.0.2049777** 验证。无需 Excel、Python 或 Parallel Computing Toolbox。基准包含随原框架提供的 Windows MEX 及 D=30 数据，未附 C/C++ 源码，不声明跨平台运行能力。

## 已有数据覆盖范围

`data/archived_5alg_30runs/` 保留未修改的 `original_results.xlsx`，并导出 `raw_final_fitness.csv` 和 `sampled_convergence.csv`。包含 RLDSBO、RLDSBO-Rand50、RL-HPSDE、DSBO、SBO 在 F1–F30 上每函数30次记录，共4500条最终适应度和对应的40点原始采样曲线。`PROVENANCE.json` 记录原工作簿校验值和字段含义。运行历史复现入口还会生成 `archived_raw_results.mat`。

论文表 A1 中300个均值/标准差单元格、表 A2 中120个p值及结论单元格，已按论文显示精度核对一致；见 `validation/paper_table_audit.json`。RLDSBO平均排名为1.500；相对Rand50为6胜/2负/22项不显著，相对RL-HPSDE为29胜/0负/1项不显著。完整统计位于 `results/archived_5alg_statistics/`。



## 重新运行的最小示例

```matlab
cfg = cec2017_config();
cfg.functions = [1 10 11 25]; % 单峰、多峰、混合、组合；直接使用CEC函数编号
cfg.algorithms = {'RLDSBO','SBO','DSBO','EESHHO','GDTSCA','ICPA', ...
    'LNPRO','ABHGS','JADE','LSHADE_cnEpSi','SADE','EBOwithCMAR','MPEDE'};
cfg.runs = 30;
cfg.population = 30;
cfg.maxFEs = 300000;
cfg.outputDir = fullfile(pwd,'results','representative_13alg_30runs');
raw = run_cec2017(cfg);
report = analyze_results(raw,cfg.outputDir,'RLDSBO');
plot_convergence(cfg.outputDir,fullfile(cfg.outputDir,'curves'),cfg.functions);
```

完整函数集用 `cfg.functions = 1:30`。复核原20次协议可设置 `cfg.runs = 30`。快速试运行可设置 `cfg.runs = 2; cfg.maxFEs = 3000` 并指定不同的 `outputDir`；这些小预算结果不能用于替换论文实验。默认全套实验包含13500次独立运行，启动前请确认所选函数、算法和输出目录。

`runs` 可设置2–9999；种群输入N为不小于30的10的倍数，以满足所保留多子群实现的分组及差分索引要求。仅包含 D=30，边界固定为[-100,100]。`maxFEs` 可为非N整数倍，但需至少N+20。每个函数/重复使用 `baseSeed + 10000*functionId + runId`，算法之间使用相同起始种子；不同算法消费随机数的顺序不同。

## 停止、续跑和输出

- 每次运行结束保存独立 `.mat` 检查点，包含种子、随机流状态、最优可行位置、适应度、实际调用次数、耗时和采样轨迹。
- 使用同一配置、同一 MATLAB 版本及同一源码再次执行，可从已有完整检查点续跑；中断中的单次运行会按原种子重跑。
- 配置或源码/基准数据变化时拒绝混入旧结果，请更换输出目录。请勿让多个 MATLAB 进程同时写同一个输出目录。
- `raw_final_fitness.csv` 以17位有效数字导出最终值，`.mat` 保存完整双精度。`raw_partial.csv` 只表示当前进度，不能当作完整数据交给统计脚本。
- 真正的算法错误保存于 `last_failure.mat` 并停止；仅预算终止使用专门的异常标识捕获，不隐藏失败运行。

## 两种适应度口径

历史文件保留原工作簿的 **算法报告的最终值**（`historical_reported_final`），并保留CEC偏置，不减去已知最优值。历史曲线的横轴为原始采样序号，未将其冒充精确FE时间戳；历史随机种子未记录。

新入口报告 **预算内所有已评估可行点的最佳目标值**（`best_feasible_evaluated`）。初始化、局部搜索和景观探测均计入实际调用次数；超过预算的下一次调用在执行前被阻止。算法原有的越界候选评估行为保留并计数，但越界点不会被计为可行最优解。正常返回时还保存原始返回值、原生曲线末值和有限个原生采样点；它们与实际FE轨迹分别记录，预算截断未返回时原生输出为空。

**新入口用于透明的新比较，不承诺逐位重现历史优化轨迹。** 差别包括可追踪种子、统一的实际FE上限与结果口径，以及公开记录的两处内部预算同步。`analyze_results` 拒绝混合这两种适应度口径。详见 `docs/MODIFICATIONS.md`。

## 如何对应表格和图形

| 文件/命令 | 对应内容 |
|---|---|
| `mean_std.csv` | 表A1的逐函数/算法均值与样本标准差，使用 `std(x,0)` |
| `wilcoxon_signed_rank.csv`、`win_loss_counts.csv` | 表A2的双侧p值与RLDSBO胜/负/不显著计数，未经多重比较校正，阈值0.05 |
| `ranks_by_function.csv`、`average_ranks.csv` | 对每个函数的最终均值作升序平均秩，再对函数取平均；表A1末行 |
| `friedman_test.csv`、`statistics.mat` | 以函数为区组、各算法逐函数均值为观测的Friedman检验及其平均秩 |
| 历史复现入口生成的 `convergence/F*.png` / `.pdf` | 图3涉及F7、F8、F9、F12、F18、F25的五算法平均采样曲线，纵轴为对数刻度；数据重建图，版式可与原图不同 |
| 重新运行后使用相同统计/绘图入口 | 可生成对应算法组的新表/图；不会自动覆盖表A3–A6 |

Wilcoxon按同一函数的相同run编号配对，沿用MATLAB `signrank(x,y,'tail','both')` 的自动方法；完全相同数据显式返回p=1。与原稿相同，胜/负由p<0.05及均值方向共同确定。历史run编号只是记录中的配对键，不证明历史实验使用了共同随机种子。Friedman不把不同函数的全部运行混成独立区组，也不把独立运行排名平均值误写为逐函数均值排名。重复键、缺失记录、非有限结果均会报错。

## 文件组织和源码出处

- `algorithms/`：审稿人指定13种算法，加上表A1–A2的Rand50、RL-HPSDE，共15种；必要共享函数在 `algorithms/private/`。
- `benchmark/`：原MEX及90个D30输入文件，按原MEX要求设置工作目录并自动恢复。
- `docs/ALGORITHM_PARAMETERS.md`：共同配置和逐算法参数。
- `docs/SOURCE_MANIFEST.csv` / `.json`：原文件路径、原SHA-256、整理后SHA-256和改动。
- `docs/SOURCE_CHANGES.patch`：相对于提供框架的代码差异。
- `docs/THIRD_PARTY_SOURCES.md`：源码中已有的作者、版本/出处线索以及明确的版本识别范围；保留原作者声明，不统一覆盖第三方许可。
- `validation/`：软件验证和论文单元格核对记录；**不是新增论文实验数据**。

## English quick start

This compact Windows MATLAB package supplies all 13 requested optimizers plus Rand50 and RL-HPSDE, CEC2017 D30 data, run-level logging, strict actual-evaluation accounting, statistics and plotting. Run `reproduce_archived_results` to reproduce the supplied five-method A1–A2 statistics from 4,500 historical records, or edit `cec2017_config` and call `run_cec2017` to generate new records. Use `analyze_results` for sample SD, paired two-sided signed-rank tests and function-block Friedman analysis. Archived algorithm-reported fitness and newly evaluated best-feasible fitness are explicitly separated. Historical run-level files for the other ten comparators are unavailable; their source and new-run entry points are provided without claiming those missing experiments have been regenerated. MATLAB R2022b and Statistics and Machine Learning Toolbox were used for validation.
