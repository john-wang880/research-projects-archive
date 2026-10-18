from pathlib import Path
import json,csv
from xml.sax.saxutils import escape
from reportlab.platypus import SimpleDocTemplate,Paragraph,Spacer,Table,TableStyle,Image,PageBreak
from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.pagesizes import A4
from reportlab.graphics.shapes import Drawing,Rect,String,Line,Polygon
from PIL import Image as PILImage

ROOT=Path(__file__).resolve().parents[1];O=ROOT/'outputs';R=O/'full_reproduction'
pdfmetrics.registerFont(TTFont('CN','C:/Windows/Fonts/simhei.ttf'))
S={n:ParagraphStyle(n,fontName='CN',fontSize=z,leading=l,spaceAfter=a,wordWrap='CJK') for n,z,l,a in [('body',10.4,16,8),('small',8.8,13,6),('title',23,30,14),('head',16,23,10),('cell',9,13,0)]}
story=[]
def clean(s):return str(s).replace('−','-').replace('µ','u').replace('²','^2')
def p(s,st='body'):story.append(Paragraph(clean(s),S[st]))
def h(s):p(s,'head')
def page():story.append(PageBreak())
def read(s):return json.loads((R/s).read_text(encoding='utf-8-sig'))
def table(headers,rows,widths=None):
 widths=widths or [505/len(headers)]*len(headers)
 a=[[Paragraph(escape(clean(v)),S['cell']) for v in row] for row in [headers]+rows]
 t=Table(a,colWidths=widths,repeatRows=1)
 t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),colors.HexColor('#e5eff7')),('GRID',(0,0),(-1,-1),.4,colors.HexColor('#ccd7df')),('VALIGN',(0,0),(-1,-1),'MIDDLE'),('TOPPADDING',(0,0),(-1,-1),6),('BOTTOMPADDING',(0,0),(-1,-1),6)]))
 story.extend([t,Spacer(1,9)])
def pic(path,mh=340):
 im=PILImage.open(path);w,hg=im.size;s=min(505/w,mh/hg);story.extend([Image(str(path),width=w*s,height=hg*s),Spacer(1,7)])
def cp(path,mh=340):pic(R/path,mh)
t=read('simulink/thermal_metrics.json');integ=read('integration/integration_metrics.json');tc=read('tec/TEC_Electrothermal_ClosedLoop_metrics.json');pwm=read('tec/TEC_DualBuck_PWM_metrics.json');conv=read('tec/PWM_convergence_metrics.json');safe=read('clamp/wide_safe_metrics.json');scr=read('scrc/scrc_metrics.json');scross=read('scrc/scrc_crosscheck_metrics.json')

p('GaN 动态导通电阻测试电路','title');h('全篇仿真复现与核验报告')
p('已覆盖论文全部可计算模块，实际运行 LTspice 与 MATLAB R2022b / Simulink / Simscape Electrical，保留可编辑模型、图线数据、日志、独立方程校核与完整重跑入口。此报告把拓扑机制验证、图线标定、功能假设和未做的实物实验分别标明。')
p('Philipp Swoboda 等，Improved Test Circuit for Characterization of the Dynamic On-Resistance of GaN-HEMTs over a Wide Operating Range。IEEE ECCE Europe 2024；DOI 10.1109/ECCEEurope62508.2024.10751914。来源为 KIT 公开的 8 页作者接受稿。','small')
table(['原文范围','本地覆盖','结果层级'],[
 ['图1–4：桥式测试和时序','原生全桥；±10/30/50 A；上下待机；72个反向分流条件','机制验证'],
 ['图5–6：夹钳及测量','原厂代表性Si-MOS模型、互锁、±5 V；量程/噪声预算','机制验证 + 条件假设'],
 ['图7：温控','双Buck PWM、原生Peltier、级联PI、−15..95°C','公开结构的功能验证'],
 ['图8–9：系统与实物','连接、分流器、供电隔离和热安装约束复核','结构复核；未做硬件'],
 ['图10：静态Ron','9条温度曲线，整温度条件留出','公开图线标定'],
 ['图11–12：动态Ron','8电压+5温度切片，显式捕获/释放状态','公开图线标定'],
 ['图13–14：自热对比','LTspice、Simulink、精确Cauer与独立积分','独立数值复核'],
 ['Table I和噪声统计','列出原值及缺失信息，不造20次实测样本','真实实验未复现'],
],[111,265,129])
p('主要核验：原生主桥与 LTspice 的平台电流差约 0.17%；Cauer 热曲线峰值吻合；温控与独立方程的全轨迹温差小于 5.7e−5 K。图14完整5 µs窗口的平均温升降幅为51.74%，与论文标注62%不一致。','small')

page();h('1  主功率电路：正负电流与待机')
cp('simulink/signed_current_procedures.png',330)
p('原生 GaN_Full_Bridge_SPS.slx 使用真实电气端口连接：500 µF 有限储能母线、90 µH 电感、桥臂与10 mΩ分流器。正向充电由HS2和LS1承担；测量由DUT和LS2承担。负向程序交换电感电压极性。')
table(['检查','实际结果'],[['六个电流程序','±10/30/50 A；测量电流因导通压降和电容下跌略低于理想目标'],['上下待机5 ms','上态Vds≈Vbus；下态Vds≈0，偏差约0.582 mV；残余电流7.27 mA'],['SPS vs LTspice','传统/改进平台电流RMS相对差0.1683% / 0.1686%'],['5 ns vs 2.5 ns','充电电流最大差6.35 mA；解析RLC终点差小于8 mA']],[140,365])
p('DUT和辅助开关的固定Ron默认各80 mΩ；电感Rser=1 mΩ为本地明示参数。主桥没有宣称已验证真实GaN栅极、Coss和开关损耗。最终采用通过KVL核验的ode45；不采用早期未收敛的SPS输出。','small')

page();h('2  反向自换流与并联分流')
cp('scrc/scrc_gate_gap_sweep.png',330)
p('专门补充第三象限降阶模型，包含节点电容、DUT分流器和两支路KCL。门极低于阈值时，反向导通门槛近似Vth−Vgs；开通时采用导通通道。LS1门压低于DUT会提高LS1门槛，但大电流下仅满足“低于”仍可能分流。')
table(['反向电流','名义隔离所需门压差','包含阈值离散的示例差值'],[['10 A','0.9 V','2.4 V'],['30 A','2.7 V','4.2 V'],['50 A','4.5 V','6.0 V']],[100,180,225])
p('阈值1.7 V、反向Ron80 mΩ和总节点电容200 pF为降阶假设。阈值范围1.1–2.6 V及连续门压额定−10..7 V由GS66508B数据手册核对；所有扫描门压−9..6 V在此范围内。72个条件均由Simulink与LTspice实际执行，支路电流两引擎差小于1.1e−13 A。','small')
p('这里的“误测偏差”只指错误地用总电感电流代替DUT电流。论文使用DUT实际分流器；该正确测量不会凭空产生同样偏差。本模块验证公开机制的数学实现，尚非厂家紧凑模型或独立器件实验。','small')

page();h('3  夹钳：双向量程与驱动互锁')
cp('clamp/wide_safe_interlock.png',255)
p('采用公开夹钳拓扑，阻断管和背靠背管使用可追溯的原厂Si-MOS模型；TVS、探头及寄生参数明确列在MODEL_CARD。所选元件和驱动属于代表性实现，作者BOM没有公开。')
table(['母线 / V','输入 / V','窗口误差 / µV','2%恢复 / ns'],[[x['bus_V'],x['on_voltage_V'],f"{x['window_error_V']*1e6:.1f}",f"{x['last_2percent_violation_after_DUT_edge_ns']:.2f}"] for x in safe],[95,95,157,158])
p('最终互锁先关断BTB，再进入负压测量；DUT电压恢复后才重新短接输出。代表性50/150/400 V × ±5 V六例全部通过有限窗口判据。最大输入瞬态0.607 A，已消除错误互锁产生的18–75 A体二极管短接。保护峰值仍可达8.514 V，名义8 V TVS不是硬限幅。','small')
p('保留原300 Ω慢驱的短窗口失败、长时恢复和全组合DC证据。实际加载源是强制DUT电压，输入电流可定量，但仍不能证明真实耦合DUT完全不受扰动。','small')
p('3份ASC已原生运行，规范化网表拓扑与参数一致。测量窗口均值差小于0.14 uV；基线换流瞬间最大点差1.24 V，50 ps/Gear复查仍有约0.5 V局部差异。窗口传递通过，但细瞬态对数值求解敏感，未声称尖峰逐点收敛。','small')

page();h('4  测量量程与噪声：可复核的边界')
cp('clamp/noise_range_budget.png',325)
p('20 MHz滤波和12 bit量化已在原生Simulink状态模型中执行。量化台阶随满量程变化，夹钳降低所需量程，因此有利于小导通电压的测量。滤波/量化预算是功能分析，不能代替示波器、探头、布局和重测样本的噪声验证。')
table(['原文测量对照','改进夹钳','阻断夹钳','电流镜夹钳'],[['原文响应 / ns','275','160','120'],['原文Ron标准差 / µΩ','90.3','525.4','695.0'],['本地处理','原图数字化对照','原图数字化对照','原图数字化对照']],[163,114,114,114])
p('原厂非线性电路显示门极电荷注入与恢复速度的折衷；降阶Simulink没有全部Cgd/宏模型内部电荷，较小尖峰只说明简化模型的边界。没有调一个人为噪声源去重现原文标准差。')
p('Table I的82.74 / 79.50 mΩ均值和0.331 / 0.242 mΩ标准差来自不同待机历史与20次硬件重复；公开稿未给原始样本。图10低应力曲线的约47–53 mΩ不能被强行当作该表基线。','small')

page();h('5  自热：图13–14三套计算交叉')
pic(O/'reproduction/matlab/figure14_input_reconstruction/original_plot_comparison.png',290)
table(['温升指标','原文标签','本地重算'],[['传统/改进峰值 K','6.1 / 3.6',f"{t['peakConventional_K']:.3f} / {t['peakProposed_K']:.3f}"],['传统/改进窗口均值 K','4.7 / 1.8',f"{t['meanConventional_K']:.3f} / {t['meanProposed_K']:.3f}"],['平均降低比例','62%',f"{t['meanReduction_percent']:.2f}%"]],[195,150,160])
p('图14采用50 A模板：32.5 µs充电、1 µs续流和5 µs测量。四级Cauer取R=[0.015,0.23,0.24,0.015] K/W，C=[8e−5,7.4e−4,6.5e−3,2e−3] J/K，固定壳温且初始温升为零。原生Simulink与精确积分最大差2.72e−5 K。')
p('平均窗口33.5–38.5 µs。原PDF矢量曲线积分得到5.222 / 2.520 K与51.75%，也支持完整窗口约51.7%的结果。作者平均口径未公开；没有移动窗口或改热参数迎合62%。图13实际电流约54–55 A，与图14的50 A模板分别保存。','small')

page();h('6  温控：原生Peltier与级联PI')
cp('tec/TEC_Electrothermal_ClosedLoop_plot.png',340)
p('原生Simscape Peltier块连接电气与热端口，模拟双Buck平均输出、两个电感、电流反馈和温度反馈及两级PI。四个600 s段依次15、55、−15、95°C；端点属于论文报告的系统能力，原文未给对应温控动态曲线。')
table(['明确假设','本地值'],[['理想散热器 / 绝热漏热','热端恒25°C；漏热导纳0.02 W/K；壳热容4.5 J/K'],['Peltier恒参数','α=0.012578 V/K；R=0.8 Ω；K=0.070126 W/K'],['控制与电源','24 V，外环iref限±3 A；命令电压限±3.6 V'],['实际瞬态峰值',f"电流{tc['max_abs_current_A']:.4f} A；电压命令{tc['max_abs_voltage_command_V']:.4f} V"]],[170,335])
p('参数由现行厂家QC-31-1.4-3.7CM表的8.4 W、3.7 A、72 K和交流电阻0.8 Ω近似反算。论文写8.6 W；交流电阻作恒直流电阻也是近似，不能称其为作者原参数。恒系数模型不能同时精确匹配全部额定点。','small')

page();h('7  PWM与独立热电能量核验')
cp('tec/TEC_DualBuck_PWM_plot.png',330)
p('短时PWM模型保留两路220 µH / 10 µF滤波和真实Peltier端口，理想开关节点0/24 V以20 kHz切换，电流参考+1→−1 A。长时热模型省略已快速衰减的输出电容瞬态，保留串联电感和电流闭环；这项快慢尺度近似已明确。')
table(['检查','结果'],[['PWM平台平均电流',f"{pwm['current_positive_mean']:.6f} / {pwm['current_negative_mean']:.6f} A；与参考约1.3%差异"],['100 ns→50 ns步长',f"平台电流RMS变化{conv['plateau_rms_current_difference_A']*1000:.3f} mA"],['独立六状态方程 vs 原生结果','全轨迹MAX温差5.68e−5 K、MAX电流差1.43e−5 A'],['稳态热电守恒','Peltier功率与两侧热流残差小于7e−16 W']],[170,335])
p('实际电流峰值3.509 A高于参考限幅3 A；不能声称有3 A硬电流保护。理想25°C散热器与假设绝热条件决定温控端点，尚需真实散热器和安装热阻才可转成硬件性能声明。','small')

page();h('8  图10：Ron与电流、温度的公开曲线')
cp('ron_trapping/Fig10_static_resistance.png',390)
p('从原PDF原生矢量路径提取9个温度条件及正负电流。用低阶电流/温度多项式表示测量表面；训练温度为15/35/55/75/95°C，完整留出25/45/65/85°C进行检验。')
table(['检验','误差'],[['整温度条件留出','RMSE 0.4907 mΩ；MAX 2.3370 mΩ'],['原生SLX vs 同一方程','MAX 4.27e−14 mΩ'],['支持范围','电流−50..50 A；温度15..95°C']],[180,325])
p('该表面重建公开测量图线，包含测量时残留自热；它并非独立GaN物理预测。不能直接把温度输入当已去嵌的真实结温，再添加反馈自热而重复计算。图内100 V待机标注与正文150 V存在来源差异，保留两者。','small')

page();h('9  图11–12：捕获、释放与长时间历史')
cp('ron_trapping/fig11_trap_reconstruction.png',230)
cp('ron_trapping/fig12_trap_reconstruction.png',230)
p('8个电压切片与5个温度切片采用显式捕获/释放状态；原生SLX实际积分，未回放CSV。独立时间块检验RMSE：图11 0.0523–0.0950 mΩ，图12 0.0465–0.1085 mΩ。它们是对公开曲线的留出检验，仍不是独立实验重复。','small')
p('动态图原生ODE与解析解最大差0.000675 mΩ。62个快速模式中13个时间常数短于原文5 s采样，不能视作已辨识的物理陷阱。图11约13.583 min释放，图12曲线约13.75 min且标线14 min；正文13 min口径也单独核对，不能暗中替换。','small')

page();h('10  联动：应力历史→电路→脉冲自热')
cp('integration/integration_pulse_heating.png',330)
labels=['初始25°C','捕获5 min','恢复20 min','负向捕获','55°C捕获','400 V历史']
table(['案例','设置Ron / mΩ','测量均值I / A','峰值温升 / K'],[[labels[k],f"{a['setRon_Ohm']*1e3:.3f}",f"{a['meanCurrent_A']:.3f}",f"{a['peakPulseRise_K']:.3f}"] for k,a in enumerate(integ['cases'])],[127,135,120,123])
p('六个条件均实际运行原生全桥，从DUT电压与实际电流提取Ron，再把I²R功率连到原生四级Cauer。最大Ron设置/提取差8.16e−12 Ω；原生热模型与精确积分最大差3.20e−11 K。')
p('这是固定历史状态下的标定行为模型联动检验；Ron在单个短脉冲内冻结，热输出用于诊断而未反向更新Ron。未假装这是去嵌后的双向电热器件模型，也未调参拟合Table I统计。','small')

page();h('11  系统结构复核：供电、测量与热路径')
d=Drawing(505,285)
blocks=[(15,190,125,64,'隔离后DC-link','500 µF / 测試储能'),(185,190,130,64,'桥式测试回路','DUT + 90 µH + LS1'),(360,190,130,64,'夹钳 / 分流器','Vds与实际DUT电流'),(185,78,130,65,'24 V双Buck + TEC','温度和电流双闭环'),(15,78,125,65,'状态 / 时序 / 记录','应力待机与脉冲测量'),(360,78,130,65,'测量结果与校核','Ron / 热流 / 参数出处')]
for x,y,w,hh,a,b in blocks:
 d.add(Rect(x,y,w,hh,rx=7,fillColor=colors.HexColor('#eaf2f8'),strokeColor=colors.HexColor('#3c6786')))
 d.add(String(x+w/2,y+40,clean(a),fontName='CN',fontSize=11,textAnchor='middle'))
 d.add(String(x+w/2,y+20,clean(b).replace('測試','测试'),fontName='CN',fontSize=9,textAnchor='middle'))
for x1,y1,x2,y2 in [(140,222,185,222),(315,222,360,222),(250,143,250,190),(140,110,185,110),(425,190,425,143)]:
 d.add(Line(x1,y1,x2,y2,strokeColor=colors.HexColor('#3c6786')))
story.extend([d,Spacer(1,10)])
p('复核图8–9系统约束：主供电两极隔离后由DC-link提供脉冲能量，局部换流回路靠近DUT；分流器测量实际DUT电流；TEC热端与散热器相接，冷端、温度检测和壳温路径保持明确。上/下待机分别控制应力与低应力状态。')
p('以上为逻辑和安装关系重建。没有生成伪装成实测的硬件照片，没有制造PCB或搭建作者测试夹具。没有作者BOM、驱动实物、布局寄生和全部测量链参数，就不能给出可信的真实开关损耗或噪声重复结果。')
h('尚未成为独立实验复现的部分')
p('厂家同型号的已核实GaN紧凑模型、真实陷阱参数、20次统计样本、示波器过载恢复/噪声处理、实物温控波形和PCB验证均未公开完整输入。本包把这些作为明确限制，不以图线标定误差冒充实验精度。')
p('“全篇仿真覆盖”说明每个公开模块都有模型或证据复核；“原作者实验已全部重做”仍不成立。数据文件和模型卡持续保留这一区分。','small')

page();h('12  工程入口、文件结构与可追溯来源')
p('解压完整工程后，使用 outputs/full_reproduction/开始复现.ps1 可以启动本机LTspice与MATLAB批处理重跑；默认MATLAB位于E:/MATLABR2022b、LTspice位于D:/LTspice。脚本接收软件路径参数，支持先只打开原生模型。')
table(['目录','用途'],[['simulink / scrc','主桥、Cauer、第三象限分流原生模型'],['clamp','原厂代表性Si模型、native ASC、SLX、量程及互锁证据'],['tec / tec_audit','原生Peltier、PWM、独立方程/能量校核'],['ron_trapping','图线坐标、分区角色、状态参数、native SLX和模型卡'],['integration','六条件原生电路与热联动'],['audit / manifest.json','逐图覆盖、边界与文件SHA256'],['reproduction（同级）','前阶段图13/14原生LTspice工程与热重建']],[180,325])
p('主MATLAB重跑使用已保存的模型参数，无需Python或网络。可选“从PDF重新抽取并拟合”另需requirements-refit.txt中的Python依赖；完整参数、单位、模型域与拟合数据角色都保存在本地。','small')
p('2026-10-02统一入口实际通过40个LTspice任务及9个MATLAB运行/校验阶段，重建并运行11个SLX。执行状态与软件原始日志位于unified_run_status.json和run_logs。','small')
h('公开来源与本地证据')
p('<link href="https://publikationen.bibliothek.kit.edu/1000176527" color="#174a70">KIT论文全文与出版元数据</link><br/><link href="https://www.infineon.com/assets/row/public/documents/24/49/infineon-gs66508b-datasheet-en.pdf" color="#174a70">GS66508B官方数据手册</link><br/><link href="https://www.quick-ohm.de/pdf/peltier-element/Information_TEC.pdf" color="#174a70">QC-31-1.4-3.7CM现行厂家规格表（第7页）</link><br/><link href="https://www.mathworks.com/help/simscape-electrical/ref/peltierdevice.html" color="#174a70">MathWorks Peltier热电方程</link>','small')
p('每项模拟保留日志、数值CSV/MAT、可编辑SLX/ASC/FIG和出处信息。总清单记录文件哈希；ZIP CRC与逐文件SHA256在打包后逐一检查。数据不是作者未公开的原始实测样本。','small')

def footer(c,doc):
 c.setFont('CN',8);c.setFillColor(colors.HexColor('#59636c'));c.drawString(44,23,'ECCE Europe 2024 GaN | 全篇仿真与公开证据核验 | 2026-10-02');c.drawRightString(A4[0]-44,23,str(doc.page))
dest=R/'GaN_ECCE2024_全篇仿真复现报告.pdf'
doc=SimpleDocTemplate(str(dest),pagesize=A4,leftMargin=44,rightMargin=44,topMargin=38,bottomMargin=42,title='GaN动态导通电阻全篇仿真复现与核验报告',author='',pageCompression=1)
doc.build(story,onFirstPage=footer,onLaterPages=footer)
print(json.dumps({'report':str(dest)},ensure_ascii=False))
