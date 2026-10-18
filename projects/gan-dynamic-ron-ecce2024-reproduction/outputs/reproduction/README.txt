GaN 动态导通电阻测试电路 图13和图14复现
2026-10-01

先读 GaN_Fig13_14_复现报告.pdf。

本次已完成
1. LTspice 原生传统/改进测试电路的电流路径验证，串行运行并核对日志。
2. MATLAB 真正的四级 Cauer 热网络及原生 FIG、MAT、CSV 结果。
3. 原 PDF 图线矢量提取、独立 RK4 和 ode15s 交叉验证。

关键结果
图14的50A模板：峰值温升6.123/3.632 K；完整33.5-38.5 us窗口
平均温升5.237/2.527 K，下降51.74%。原图矢量曲线积分也约51.75%。
这与论文文字标注4.7/1.8 K、62%不一致，作者平均实现未公开。
本次没有改变窗口或参数迎合论文标注。
实际电路导出的负载导通电流：平均温升5.712/2.717 K，下降52.42%。

原生工程
ltspice/conventional.asc、ltspice/proposed.asc：在LTspice打开并分别运行。
common.inc：电路参数、功能模型、反向路径和固定Coss假设。
各个gates.inc：门控时序。
同名NET由LTspice从ASC生成，实际仿真RAW/LOG随包保留。

重新运行顺序
1. PowerShell执行 run_ltspice.ps1，默认程序D:\LTspice\LTspice.exe。
   可通过-LtspiceExe参数修改路径；只管理本次启动的进程。
2. Python执行 export_waveforms.py 和 verify_circuit.py。
   需要NumPy；本机已用Codex内置Python执行通过。
3. MATLAB进入matlab目录，执行：
   validate_cauer
   run_figure14_reconstruction
   run_ltspice_thermal
   plot_circuit

结果文件
data/：原始电路CSV、导通近似CSV、电流路径指标和独立审查。
figures/：电路图线对比和模型开通尖峰诊断；均有原生FIG和SVG。
matlab/figure14_input_reconstruction/：论文50A简化输入的热曲线重建。
matlab/ltspice_conduction_case/：负载电流按DUT导通状态门控的热计算。
matlab/ltspice_channel_sensitivity/：原始沟道电流敏感性计算。
reference/：论文绘图曲线、坐标标定、提取和独立验证脚本。
models/：官方同型号电气模型查找记录；未用其他器件冒充GS66508B。

数据定义和限制
CSV的dut_current_A是零伏探针测得的内部沟道电流。
dut_terminal_current_A是分流器电压除以10mOhm，包含端子位移电流。
dut_load_conduction_A是DUT控制电压>3V时的电感电流，供导通热近似使用。
ls1_current_A、ls2_current_A以漏到源为正，与LTspice开关RAW参考方向相反。
主电路时间整体偏移2us；测量名义窗口35.5-40.5us。
TD=20ns是边界两侧各退让，实际阈值死区40ns、测量导通约4.960us。
辅助管Ron80mOhm、Coss200pF和反向二极管为本地假设。
约1.9kA极短模型尖峰不是实际GS66508B开通电流，已单独做能量敏感性分析。
主模型固定80mOhm；未验证TableI实验电阻、分钟尺度陷阱效应、
夹钳噪声、真实驱动动态和器件开关损耗。
reference数据是公开PDF绘图曲线重建，不是作者原始实验数据。
extract_plot_traces.py可将原论文PDF绝对路径作为第一个参数。

公开来源
论文：https://publikationen.bibliothek.kit.edu/1000176527
出版DOI：10.1109/ECCEEurope62508.2024.10751914
器件数据手册：https://www.infineon.com/assets/row/public/documents/24/49/infineon-gs66508b-datasheet-en.pdf
源PDF SHA256：0df6d7ddf4b4bbde241b4690f0f73ed644e232a0214c3041e4f1ca166e694e3c
