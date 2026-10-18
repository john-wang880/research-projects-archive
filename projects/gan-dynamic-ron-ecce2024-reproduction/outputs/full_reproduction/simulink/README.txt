Simulink 原生全桥与四级 Cauer 模型
MATLAB R2022b，Simulink、Simscape Electrical 已在本机实际调用和仿真。

打开与重跑
1. 在 MATLAB 中进入本文件夹，运行 build_and_run_simulink。
2. GaN_Full_Bridge_SPS.slx 是真实电气连接的 Simscape Electrical
   Specialized Power Systems 模型。可以直接打开模型，运行并查看 Scope。
3. GaN_Cauer_Figure14.slx 是由四个热容积分器、四个热阻流量和节点热平衡
   构成的原生 Simulink 模型。电流由 Clock 与明确时序公式生成，不回放CSV。
4. 模型均将必要参数存储在 Model Workspace，基本运行不依赖 base workspace。
5. 参数化调用示例
   r = run_bridge_snapshot(struct('Rdut',0.09,'Raux',0.08, ...
       'VDC',150,'targetCurrent_A',30));

主桥参数与机制
初始 DC-link 电容电压150V、电容500uF、电感90uH；电源为有限储能电容，
不是固定电压源。DUT 默认80mOhm，辅助开关默认80mOhm，DUT分流器10mOhm。
电感串联电阻显式取1mOhm，对应原LTspice文件未写Rser时的实际默认值，
已从其RAW文件的电感KVL拟合验证。论文未给出此串联电阻。
模型参数 p.Rdut 与 p.Raux 可以独立设置。
正向：HS2+LS1充电、HS1+HS2上续流、DUT+LS2测量。
负向：HS1+LS2充电、DUT+LS2测量。负向测试这里为同步开通态；未声称
复现随负栅压变化的自换流反向导通器件特性。
测量后：上续流令DUT保持近VDC应力；下续流在电感放电后令DUT近0V。
传统对照充电由DUT代替LS1，暴露DUT额外导通功耗。
目标电流由tcharge=L*abs(I)/VDC估算，包含实际导通压降和电容压降后
测量电流略低于理想目标，实测数值完整写入electrical_metrics.json。

边界与校核
原生拓扑采用固定Ron双向开关、1GOhm关断泄漏路径和同时门控切换。
没有引入未公开的GaN厂家紧凑模型、Coss、死区、驱动或陷阱物理。
±10/30/50A共六种程序、上下idle与传统/改进基线共十个电气case实际运行。
接受的ode45求解器，5ns与2.5ns步长的充电电流最大差6.35mA；解析RLC
充电终点误差小于8mA。最初ode23tb/ode15s的SPS结果未满足KVL核验，
已经弃用；诊断信息见solver_convergence.json。
与原LTspice基线的测量平台电流RMS差约0.168%，残差主要来自本模型省略
的40ns死区与电容/反向换流。ltspice_difference_audit.json保留端口电压
积分误差预算。audit_ltspice_difference.py可在完整原工程目录结构中重跑。
上下idle运行至5ms；上态DUT与Vbus误差、下态DUT绝对电压均约0.582mV，
残余电感电流约7.27mA。CSV保留全部微秒阶段，长idle段按约1us抽取输出，
内部求解仍使用5ns最大步长。

图14
采用论文图示50A输入模板，32.5us充电、1us上续流、5us测量；固定80mOhm。
这与全桥图13的150V实际电流case分开，不用调整输入迎合百分比标注。
Cauer R=[0.015 0.23 0.24 0.015] K/W;
C=[8e-5 7.4e-4 6.5e-3 2e-3] J/K，初始温升零，壳温固定。
原生Simulink峰值6.123210/3.632014K，完整33.5–38.5us窗口均值
5.236685/2.527375K，下降51.737126%。与独立MATLAB精确Cauer方法最大误差
小于2.72e-5K。论文印刷4.7/1.8K和62%标注不能由该完整窗口取得。

文件
.slx为可编辑原生模型；.m为构建和运行入口；.csv/.mat为实际输出；
.fig为MATLAB原生图；.png为预览；metrics JSON保留参数、指标和验证边界。
slprj和.slxc为MATLAB编译缓存，可忽略，不是复现必需内容。
