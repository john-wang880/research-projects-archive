# Reproduction of “High-Speed and Responsivity 4H-SiC 8 × 8 p-i-n Ultraviolet Photodiode Arrays With Micro-Hole Structure”

本仓库提供 Fu 等人 2023 年 4H-SiC 微孔紫外 PIN 光电二极管论文的 Figure 3、Figure 4 复现研究源工程，包括 SDE 几何与网格、SDevice 光谱和瞬态模型、Workbench 参数树、原生 SCW 校准与结果提取代码。

论文：[High-Speed and Responsivity 4H-SiC 8 × 8 p-i-n Ultraviolet Photodiode Arrays With Micro-Hole Structure](https://doi.org/10.1109/TED.2023.3286379)，IEEE Transactions on Electron Devices，2023。

这是二维截面建模与等效读出校准基线。Figure 3 尚有定量和谱形差距；Figure 4 的总响应时间得到拟合，但上升沿、下降沿分配没有同时贴合论文。不能据此宣称三维器件或本征响应机制已定量复现。

## 公开范围

仓库只发布自有源代码与必要的 Workbench 工程元数据。按要求，所有材料参数文件与光学材料表均已剔除，包括 `sdevice.par`、展开的 `.par`、`variant.par` 和 `sic_uv_nk*.txt`；没有将材料数据嵌回代码。网格与状态二进制、原生 PLT、运行日志、论文 PDF、论文原图及论文曲线数字化数据也不发布。

因此，本公开包可以审阅建模和求解流程，但不能在缺少材料输入时独立运行，也不能单凭此包保证重现此前数值。源文件保留对本地材料卡和光学表的输入引用；用户须自行提供合法数据，并确认名称和路径。

## 目录

| 目录 | 用途 |
|---|---|
| `templates/figure3` | 初始 Figure 3 Workbench 工程，0 / 4 / 8 µm 结构与 5 / 10 / 15 / 20 V 光谱扫描 |
| `templates/figure3_finite_lifetime` | 十二个光谱校准算例的展开命令；共用材料输入不公开 |
| `templates/figure4_baseline` | 直接 50 Ω 读出的未加等效串阻基线 |
| `templates/figure4_calibrated` | 等效串阻、读出电容与脉冲能量校准后的六脉冲工程 |
| `templates/figure4_calibrated/scw_native/parent` | SCW 调用的原生 SDevice 单脉冲工程与 Python 提取节点 |
| `templates/figure4_calibrated/scw_native/optimizer` | 原生 SCW 优化脚本与最终拟合参数 |
| `tools/prepare_local.py` | 将模板复制到新目录，替换工程路径占位符；不运行仿真 |

## 本地准备与运行顺序

原验证环境为 Linux 上的 Sentaurus **X-2025.06**。运行需要合法安装及对应工具许可证；Python 路径准备工具可先在 Windows 或 Linux 使用。

1. 在仓库根目录执行路径准备。目标目录必须不存在；工具拒绝覆盖已有目录。

   ```text
   python3 tools/prepare_local.py --prepare-only --output-root /path/to/new/fu2023_projects
   ```

   Windows 也可使用 `python` 和 Windows 绝对路径。工具把模板内容复制到新目录下的 `figure3`、`figure3_finite_lifetime`、`figure4_baseline` 和 `figure4_calibrated`，替换四种 `__FIGURE...PROJECT__` 占位符，写入准备记录。原始模板保持不变。此操作不会提供材料卡、光学表、网格、暗态，也不会启动 SDevice。若最终在 Linux 中仿真，应在 Linux 的目标目录执行准备，避免将 Windows 路径带入求解命令。

2. 自行提供合法材料输入。Workbench 工程需要 `sdevice.par` 与相应 `sic_uv_nk.txt`；光谱校准算例需要对应 `variant.par` 和光学表。核对材料卡中的光学 `NumericalTable` 等引用，并按本地目录修正。SCW 的 `files_to_copy` 引用材料文件，要求在父工程中本地补齐。

3. 在 Workbench 打开准备后的 `figure3`，先运行 SDE 生成三个结构的网格，再运行相应 SDevice 暗态和光谱节点。Figure 4 所引用的 20 V 暗态需先完成并保存；光谱校准命令也使用这些暗态作为热启动。不要用不匹配的结构、材料或网格状态替代。

4. 准备 `figure4_baseline` 或 `figure4_calibrated` 的 SDE 网格，可重新生成，或复用经过结构、源文件与网格哈希核对的对应网格。确认 SDevice 的 `Grid` 和 `Load` 分别指向正确网格及新生成的 Figure 3 暗态。按本地 Workbench 预处理结果确认节点对应关系，不把历史节点编号视为跨版本保证。

5. 若运行 SCW，先核对父工程的网格与暗态输入。优化脚本按其本地文件位置确定 `parent` 与新建的 `child_local`。父工程的 SDevice 输出经 Python `extract` 节点提取 DOE 指标；`#setdep @node|sdevice@` 保证提取依赖求解节点。原环境在单 SCW 节点的优化器工程中使用如下入口：

   ```text
   scw -node1 --threads3 --max_threads3 scw_scw.py
   ```

   这需要处于正确的 Workbench 节点上下文，并在本地 Sentaurus 环境中执行。普通 Python 不能替代原生 SCW 启动。原生 SCW 会调用父工程的 SDevice 和提取节点，最终选择保存的拟合参数；最新子工程参数不一定就是最终胜者。

6. 完成求解后仍需审核端点和真实结果。正常退出不等于波形、谱点、偏压、光生输入或电流守恒均正确。Figure 3 应覆盖 200–400 nm、每 5 nm 一个点，共 41 点；Figure 4 生产求解覆盖 6 µs 的六个真实脉冲。

## 建模与已审核结果的含义

几何使用二维槽截面近似圆形微孔。材料与界面使用校准假设，光学采用波长相关复折射率、单色光源与原生光线追踪，载流子采用 Poisson 与电子/空穴输运耦合。二维面积换算、材料输入和理想化界面会影响定量结果；这些假设不等同于作者的完整实测参数。

Figure 4 的光源为 266 nm、10 ps FWHM 高斯脉冲、1 MHz。论文未指定脉冲形状与脉宽定义，本模型将 10 ps 解释为高斯脉冲的 FWHM，这是光源假设。论文未给出完整脉冲能量与读出参数。本次保持 **50 Ω 负载**，额外 **5 pF** 读出电容为假设；共有脉冲能量及结构相关串阻由 SCW 拟合。没有对输出波形乘经验因子，也没有改变输出时间轴来匹配论文。

| 参数 | 本次值 | 来源 |
|---|---:|---|
| 负载 | 50 Ω | 经用户同意采用的假设 |
| 额外读出电容 | 5 pF | 假设 |
| 每脉冲能量 | 76.228449 pJ | 共用拟合输入 |
| 无孔串阻 | 567.53594 Ω | 等效读出拟合参数 |
| 4 µm 串阻 | 279.68363 Ω | 等效读出拟合参数 |
| 8 µm 串阻 | 583.397 Ω | 等效读出拟合参数 |

串阻是等效参数，不能直接认定为器件实测片阻。供电为 20 V，强光脉冲时器件实际反向偏压随阳极电压变化。SCW 独立拟合三个总时间，并以较低权重使用从论文图估读的 4 µm 峰值约 330 mV；该峰值不是作者提供的原始测量数据，Tr 和 Tf 未作为独立拟合目标。

下面数值来自**剔除材料文件之前**原生 SDevice 结果的审核；它们记录研究进展，不是本公开包在任何材料输入下均能重现的保证。

| 结构 | 论文总响应时间 | 本次总响应时间 | 本次上升时间 Tr | 本次下降时间 Tf |
|---|---:|---:|---:|---:|
| 无孔 | 5.4 ns | 5.404 ns | 0.311 ns | 5.093 ns |
| 4 µm | 2.2 ns | 2.204 ns | 0.221 ns | 1.983 ns |
| 8 µm | 2.9 ns | 2.876 ns | 0.272 ns | 2.604 ns |

总响应时间为 Tr + Tf，分别按上升沿 10%–90% 和下降沿 90%–10% 定义。论文对应 Tr / Tf 为无孔 2.5 / 2.9 ns、4 µm 0.6 / 1.6 ns、8 µm 0.8 / 2.1 ns。本次上升沿明显偏快，等效读出校准主要改善总时间，尚不能认定单脉冲形状或真实收集机制一致。

Figure 3 的峰位、峰值、偏压趋势和谱尾仍有差距。Figure 4(d) 的探测率仅作为条件估算：

```text
R = abs(I_light - I_dark) / 5.67e-9 W
EQE = R * h*c / (q*lambda)
D* = R * sqrt(S / (2*q*I_dark_assumed))
S = 4e-4 cm^2
I_dark_assumed = 1e-14 A
```

这里用于 D* 的暗电流是条件假设，并非本模型可靠预测的噪声电流。该估算不包含新增串阻热噪声、仪器噪声或完整读出噪声，短波与长波谱尾也尚未吻合论文。

## 授权与引用

MIT 授权仅覆盖本仓库中的自有代码；不授权 Sentaurus 软件、材料数据库、厂商文档或原论文。Workbench 生成元数据中的原有 notice 保留。使用本工程请引用原论文，并注明二维近似、材料输入未公开及等效读出校准的限制。
