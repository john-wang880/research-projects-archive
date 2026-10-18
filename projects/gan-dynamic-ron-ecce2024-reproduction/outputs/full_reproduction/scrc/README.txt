GaN 第三象限反向导通与并联分流机制

来源
论文负电流程序旁的图3文字要求：LS1的栅压低于DUT栅压，避免并联辅助管
参与自换流反向导通。图4是上/下待机状态，已经由另一个原生全桥模型验证。
GS66508B官方数据手册Rev200402，印刷页14–15（PDF页15–16）解释了：
GaN器件没有内置体二极管；关断状态下，反向电压使栅漏电压超过阈值后开启
沟道；负栅压增加反向导通压降。6V开通态近似表现为双向沟道电阻。
官方电气表印刷页3（PDF页4）的阈值min/typ/max为1.1/1.7/2.6V，测量条件
仅7mA；不能将此阈值直接当10–50A工作点的精确反向开启压降。
官方额定表印刷页2（PDF页3）的连续Vgs范围−10至+7V；扫描最小栅压−9V，
最大+6V，均在该栅压额定内。没有据此宣称这些反向电流点适合硬件长期工作。
官方全文
https://www.infineon.com/assets/row/public/documents/24/49/infineon-gs66508b-datasheet-en.pdf

可编辑模型与重跑
MATLAB进入本文件夹，运行 build_run_scrc。
GaN_SCRC_Current_Sharing.slx使用节点电容KCL真实动态积分，不回放电流CSV。
Iload = Idut + Ils1 + Cnode*dV/dt + V/Rleak，其中节点电容C=200pF为假设。
实际方程为C*dVcommon/dt=Iload−Idut−Ils1−Vcommon/Rleak。
Fdut=max(Vth,DUT−Vgs,DUT,0), Faux=max(Vth,LS1−Vgs,LS1,0);
Idut=max((Vcommon−Fdut)/(Rrev,DUT+Rshunt),0);
Ils1=max((Vcommon−Faux)/Rrev,LS1,0)。
DUT真实源漏电压Vsd,DUT=Vcommon−Idut*Rshunt，分流器10mOhm明确保留。
阈值名义1.7V、两管反向沟道电阻80mOhm、节点总电容200pF和线性分段
函数均为降阶假设；没有冒充未获得的GS66508B厂家紧凑模型。
5us左右电流脉冲使用10ns上/下降斜坡，与SPICE激励一致。

实际覆盖
72个原生仿真条件：负电流幅值10/30/50A，DUT门压−3/0/+6V，
Vgs,DUT−Vgs,LS1为0/0.5/1/2/3/4.5/5/6V。
scrc_current_sharing_sweep.csv为稳态支路电流、电压和诊断指标；
scrc_native_sweep.mat保留全部时域状态；原生FIG与预览PNG已保存。
scrc_parallel.cir是同一个降阶机制的原生SPICE电路。root已串行运行LTspice，
该目录中的LOG/RAW为实际输出，native_run_record.json记录运行状态。
crosscheck_scrc.py读取RAW的全精度时域数据，按实际72个步进条件对齐原生
结果，使用2–5.8us平台均值进行跨求解器检查。结果保存在
scrc_spice_native_crosscheck.csv与scrc_crosscheck_metrics.json。
72条件最大DUT电流差1.066e−13A、LS1电流差7.283e−14A，最大DUT电压差
1.954e−14V；SPICE平台含1GOhm泄漏支路的最大KCL误差1.867e−14A。
这验证同一个分段线性降阶电路的实现一致性，不增加器件物理或实验可信度。
最终LTspice日志没有花括号预解析、未定义符号或致命数值警告。

解释
相同门极电压时两个反向支路分流，DUT串有10mOhm分流器，因此两管80mOhm
假设下DUT约承担47.06%，LS1约52.94%，不严格各半。
LS1门极较低会提高其反向开启门槛，但严格不等式本身不保证所有电流下
完全隔离。两管名义阈值相同且两者处于off-state反向导通时，无LS1分流
需要gateGap至少(Rrev,DUT+Rshunt)*I，名义10/30/50A分别0.9/2.7/4.5V。
若仅把官方阈值极差作为固定阈值散布，降阶条件分别变成2.4/4.2/6.0V；
这只是功能模型内的保守关系，不是厂家保证的设计余量。
当DUT+6V、LS1为0V时，LS1仍可能在足够大的反向电压下自然导通；不能用
理想开关“gate=off就永不导通”的结果证明真实GaN不会分流。
上述混合状态分别使用DUT开启沟道的零阈值偏移、LS1关断反向支路1.7V
阈值偏移，没有把两支路都当关断器件。10/30/50A时，名义LS1分流分别
为0/5.882/16.471A，已由两套求解器逐条件确认。

误测偏差的定义
trueEffectiveSCRCresistance=Vsd,DUT/Idut包含阈值压降，不等同纯沟道Ron。
wrongTotalCurrentResistance=Vsd,DUT/Iload只描述错误将总电感电流当DUT
电流时的诊断偏差。论文正确使用DUT支路分流器，所以不会自动产生该错误；
实际影响是测试的DUT电流没有达到原定总电流，以及反向导通测量条件改变。
正确的逐时刻Vds/Id仍对应实际DUT支路电流。
本验证不含真实栅极电荷、非线性Coss、自热/陷阱或反向开关损耗。
