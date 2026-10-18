原理图与手写网表的数值差异核查（2026-10-02）

父目录3份ASC全部由本机LTspice 24.0.12生成NET并实际运行至3 us。
verify_native_schematics.py把XX实例前缀、匿名TVS中点名和无用默认二极管
库规范化后，逐项核实全部元件、连接、参数和仿真指令与对应CIR一致。

测量窗口1.4-1.8 us：基线ASC/CIR均值差最大8.31 nV。
这支持原生原理图的稳态测量功能和连接一致性。
但是基线换流瞬间逐点电压差最大1.2352 V、全轨迹RMS最大25.30 mV。
原10 mV全轨迹判据在两个400 V案例未通过；结果保留为false。

把最大步长200 ps缩小到50 ps，并加严相对/绝对误差后，局部最大差
仍分别约0.2335/0.4975/0.03143 V。再用Gear与reltol1e-7、trtol1，
最大差仍约0.3383/0.4395/0.03235 V。12个验证网表、RAW和LOG都保留。
所有这类复查的测量窗口均值差小于0.14 uV。

结论：连接与测量窗口传递通过；不宣称换流尖峰逐点数值收敛。
这些非线性代表性宏模型包含强非线性、理想激励和寄生近似，日志有
反复Tseed/Heightened Def Con求解提示。元件顺序影响极短瞬间的求解。
本次保留该限制，而未提高原10 mV判据让失败变成通过。
不能把这些尖峰细节用于真实器件SOA或示波器过载恢复的精确预测。

convergence.json：50 ps + reltol1e-6，六个实际任务。
gear_convergence.json：50 ps + Gear + reltol1e-7，六个实际任务。
父目录native_ASC_waveform_verification.json：原始200 ps三组对照。
canonical_native_netlist_identical与measurement_window_pass是独立字段；
pointwise_transient_equivalence_claimed始终为false。
