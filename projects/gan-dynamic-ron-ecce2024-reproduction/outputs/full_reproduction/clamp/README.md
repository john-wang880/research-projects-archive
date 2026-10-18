# 图5/6可运行复现入口

先打开 `GaN_Fig5_Clamp_Safe400_Pos5.asc` 或 `GaN_Fig5_Clamp_Safe400_Neg5.asc`。这两份 LTspice 原理图使用实际原厂非线性 MOSFET 模型、TVS 与探头负载；相应 400 V 总线、±5 V 输入的电路已经实际仿真。激励直接保存在源的PWL属性中，修改VBUS/VON可改变输入；两份自带 `.asy` FET符号与 `models/` 应和原理图一起保留。

`GaN_Fig5_Clamp_Analog_State.slx` 是可编辑的4支路 Simulink 夹钳/测量模型；`GaN_Clamp_Wide_Range_Analog_State.slx` 是6支路宽量程模型。它们具有自包含模型工作区，R2022b 已实际运行。降阶模型采用连续 Kirchhoff 电流方程、门极状态、TVS、20 MHz 滤波与12 bit量化；完整 MOSFET 宏模型结果以 LTspice 为准。

- `wide_safe_interlock.png`：最终正确互锁、±5 V传递、400 V保护和危险时序电流对比。
- `clamp_ltspice_comparison.png`：Blocking FET、BTB、驱动敏感性与电流镜机制。
- `fig6_source_digitized.png`：论文原图数字化，只作参照。
- `noise_range_budget.png`：明确满量程假设下的12 bit预算，不是论文实验噪声的复现。
- `metrics.json`：所有结果统一索引；`verification.json`：原生运行终点、SHA256和模型文件检查。
- `MODEL_CARD.md`：完整参数、来源、失败案例与限制。

正确互锁后的6个宽量程案例全部通过本次采样窗口条件：±5 V误差约58.9–103.7 µV，最后一次超出±2%约66.64–68.00 ns。原300 Ω慢门极负向案例在短窗口未恢复；长窗口/DC已单独证明恢复。BTB若在 DUT仍为负压时闭合，可出现体二极管短路，因此这些危险案例也保留在诊断结果里。

精确275/160/120 ns与90.3/525.4/695 µΩ仍是作者硬件实验指标。作者夹钳BOM、布局、门极时序、实际示波器满量程与额外滤波未公开，本次没有把这些数值调成一致后声称独立复现。

重跑分析需原生ASCII RAW与NumPy；运行 `analyze_clamp.py`、`finalize_clamp.py`。MATLAB绘图用 `plot_clamp_results.m`、`plot_wide_range.m`、`plot_final_interlock.m`；两个 `build_*simulink.m` 可以重新生成并实际仿真SLX。每个病例终点由 `verification.json` 给出，不把DC诊断的0.1 µs和长诊断的10 µs误判为未完成。
