"""Read-only audit of declared evidence; writes only this audit directory."""
from pathlib import Path
import csv, json, hashlib, zipfile, datetime, re

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
FULL=ROOT/'outputs/full_reproduction'
def load(rel):
    return json.loads((FULL/rel).read_text(encoding='utf-8'))
def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()
M='1 已独立机制验证'
C='2 公开曲线标定'
F='3 功能假设'
H='4 未完成真实硬件实验'
rows=[]
def row(item,page,claim,layer,status,method,result,evidence,limits):
    rows.append(dict(对象=item,论文PDF页=page,原论文内容=claim,证据层=layer,完成状态=status,
                     本次方法=method,定量结果或结论=result,证据路径=evidence,边界及未完成项=limits))

thermal=load('simulink/thermal_metrics.json')
electrical=load('simulink/electrical_metrics.json')
scrc=load('scrc/scrc_metrics.json')
cross=load('scrc/scrc_crosscheck_metrics.json')
safe=load('clamp/wide_safe_metrics.json')
diagnostic=load('clamp/diagnostic_metrics.json')
tec=load('tec/TEC_Electrothermal_ClosedLoop_metrics.json')
teca=load('tec_audit/TEC_independent_audit_metrics.json')
pwm=load('tec/PWM_convergence_metrics.json')
native=load('ron_trapping/Simulink_execution_metrics.json')
fit=load('ron_trapping/metrics.json')
integrated=load('integration/native_integration_validation.json')
with (FULL/'ron_trapping/fit_metrics.csv').open(encoding='utf-8',newline='') as f:
    trap=list(csv.DictReader(f))

row('Fig1',2,'全桥、并联LS1和单电感测试结构',M+'；'+F,'完成公开结构仿真',
    '原生SPS电气连接；LTspice独立基线；RLC/KVL校核',
    '500µF有限母线、90µH；充电终点与RLC解析解差<8mA',
    'simulink/GaN_Full_Bridge_SPS.slx; simulink/electrical_metrics.json; ../../reproduction/ltspice/',
    '主桥为固定80mΩ双向开关；无GS厂家电荷模型；1mΩ电感Rser为LTspice默认值核验结果，非论文给值')
row('Fig2',3,'正电流：LS1充电、上续流、DUT测量',M+'；'+F,'完成六种有符号程序中的正向三例',
    '实际原生±10/30/50A程序；5µs测量、1µs上续流',
    '正30A名义输入的DUT测量均值29.2948A；改进结构DUT充电电流近零',
    'simulink/positive_10A.csv; simulink/positive_30A.csv; simulink/positive_50A.csv; simulink/electrical_metrics.json',
    '目标为tcharge=L I/V的理想名义值；损耗和电容压降使实际电流降低，不声称恰好目标值')
row('Fig3',3,'负电流程序和负栅压SCRC门压关系',M+'；'+F,'完成同步负电流及独立SCRC机制验证',
    '主桥−10/30/50A；SCRC72个KCL连续状态条件与原生SPICE',
    f"SCRC解析支路误差MAX={scrc['maximumAnalyticBranchError_A']:.3g}A；跨引擎DUT支路差MAX={cross['maximumDUTcurrentDifference_A']:.3g}A",
    'simulink/negative_30A.csv; scrc/GaN_SCRC_Current_Sharing.slx; scrc/scrc_metrics.json; scrc/scrc_crosscheck_metrics.json',
    '主桥负电流为同步开通态；SCRC单独使用固定阈值/线性反向电阻，未得到厂家GaN紧凑模型')
row('Fig4',3,'上/下续流待机施加VDC/约0V',M+'；'+F,'完成原生上下待机到5ms',
    '有限母线和电感完整放电动态',
    '下态Vds=0.582mV；上态Vds−Vbus=0.582mV；残余IL=7.27mA',
    'simulink/idle_lower.csv; simulink/idle_upper.csv; simulink/electrical_metrics.json',
    '0V是电感充分放电极限；5ms残值非精确0。分钟尺度捕获/释放由单独标定状态模型完成')
row('Fig5',3,'Blocking FET、BTB短接、双向TVS夹钳',M+'；'+F,'完成公开拓扑与互锁诊断',
    '原厂ST/Diodes Si-MOS宏模型；独立Simulink KCL/门极RC/TVS连续状态',
    '34个原生SPICE案例与10个原生SLX分支；含±0.48V、50/150/400V×±5V',
    'clamp/metrics.json; clamp/MODEL_CARD.md; clamp/verification.json; clamp/GaN_Fig5_Clamp_Analog_State.slx',
    '代表性元件不等于作者BOM；TVS为显式近似；Simulink没有原厂完整Cgd/内部寄生；理想DUT电压源')
row('Fig6',4,'改进/Blocking/电流镜波形、响应及噪声',M+'；'+F+'；'+H,'机制和预算完成；原硬件数值未独立重现',
    '三类夹钳的实际SPICE；公开原图数字化仅作参考；响应判据独立声明',
    '普通±0.48V误差<8µV；慢驱动约295µV。论文275/160/120ns及90.3/525.4/695µΩ仅为原实验对照',
    'clamp/clamp_metrics.json; clamp/fig6_digitization.json; clamp/noise_range_budget.json; clamp/MODEL_CARD.md',
    '作者门驱动/实际满量程/噪声滤波/布局和采样缺失；未调噪声或时间常数迎合275ns与σ')
row('Fig7',4,'双Buck可逆TEC、两级PI温控',M+'；'+F,'完成原生电热闭环和独立ODE；短时PWM',
    '真实Peltier守恒端口；独立6状态SciPy Radau；20kHz LC PWM半步长核验',
    f"15/55/−15/95°C各600s；ΔT max5.68e−5K；实际I峰值{tec['max_abs_current_A']:.6f}A；PWM平台电流差RMS={pwm['plateau_rms_current_difference_A']:.6f}A",
    'tec/TEC_Electrothermal_ClosedLoop.slx; tec/TEC_DualBuck_PWM.slx; tec/PWM_convergence_metrics.json; tec_audit/TEC_independent_audit_metrics.json',
    '无限理想25°C散热器、热容/绝热/PI及传感器假设；无DUT平均热负荷；±3A只为参考限幅。论文8.6W，当前8.4W规格用于alpha')
row('Fig8',5,'主板、可换夹具、独立电感PCB与仪器结构',F+'；'+H,'完成系统结构复核；未实物重建',
    '全文/原图复核并将公开元件和互连映射到模型',
    '可换夹具/隔离驱动/局部与500µF母线/独立90µH电感/夹钳/分流器/温敏元件结构已记录',
    'ECCE_Europe_2024_GaN_Dynamic_Ron_Fulltext.pdf; audit/AUDIT.txt',
    '未建立作者PCB布线、尺寸/寄生、原生PCB CAD或装配；模型不等于硬件复制')
row('Fig9',5,'实际测试装置照片与自动化仪器链',F+'；'+H,'完成结构复核；未搭建实物',
    '照片与SecV文字逐项对应',
    '双继电器全极断开高压源；独立24V电源；Ethernet/UART自动化架构已复核',
    'ECCE_Europe_2024_GaN_Dynamic_Ron_Fulltext.pdf; audit/AUDIT.txt',
    '未声称照片可做数值仿真；没有硬件、真实高压隔离、仪器通信或安全认证')
row('Fig10',6,'有符号Id与15..95°C壳温的静态测得Ron曲线',C,'九条公开曲线全部提取；原生模型实际运行',
    'PDF原生矢量坐标；15项多项式；五温度训练，四个整温度条件留出',
    '留出25/45/65/85°C RMSE0.490707mΩ，MAX2.336989mΩ；469个原生SLX查询',
    'ron_trapping/coordinate_provenance.json; ron_trapping/metrics.json; ron_trapping/RonStatic_Fig10.slx',
    '公开曲线标定不是独立物理预测；15..95°C、约±50A域；可能含残余自热。正文150V与图注100V应力冲突')
for figure,page,conds,description in [('fig11',6,'50..400V共8条；30A、25°C','不同电压应力的分钟级捕获和恢复'),('fig12',7,'15..55°C共5条；30A、150V','不同温度的分钟级捕获和恢复')]:
    rr=[q for q in trap if q['figure']==figure]
    rms=[float(q['independent_test_RMSE_mOhm']) for q in rr]
    mx=max(float(q['independent_test_MAX_mOhm']) for q in rr)
    row(figure.capitalize().replace('Fig','Fig'),page,description,C,'全部公开曲线和约53min原生状态仿真完成',
        '1至3指数状态；时间块分离60%拟合/20%模型选择/20%独立曲线点留出',
        f"{conds}；曲线点测试RMSE{min(rms):.4f}..{max(rms):.4f}mΩ、MAX≤{mx:.4f}mΩ",
        f'ron_trapping/{figure}_trap_reconstruction.png; ron_trapping/fit_metrics.csv; ron_trapping/RonTrap_{figure}.slx; ron_trapping/Simulink_execution_metrics.json',
        '只在给定公开条件内标定；无整电压或整温度动态外推验证。5s采样不足识别部分更快常数；图线应力释放时刻与正文13min有差异')
row('Fig13',7,'传统/改进DPT充电电流与自热比较实验',M+'；'+F+'；'+H,'电路导通/功耗机制完成；实验绝对值未独立重现',
    '150V、500µF、90µH、32.5µs充电；两个原生引擎及公开原图对照',
    '改进DUT充电期间电流近零；测量波形平台跨引擎RMS差约0.1683%',
    'simulink/baseline_conventional.csv; simulink/baseline_proposed.csv; simulink/ltspice_difference_audit.json; ../../reproduction/reference/figure13_current.csv',
    '原实验~53A、动态Ron与上待机历史未公开；固定80mΩ不能独立解释TableI的82.74/79.50mΩ')
row('Fig14',7,'厂家热网络与自热降低的公开仿真',M+'；'+F,'四级Cauer实际运行；发现标注/完整窗口不一致',
    '厂家公开R/C；明确50A时序模板；零初始温升；独立精确Cauer交叉校核',
    f"完整33.5..38.5µs均值{thermal['meanConventional_K']:.6f}/{thermal['meanProposed_K']:.6f}K，下降{thermal['meanReduction_percent']:.6f}%；精确法误差<2.72e−5K",
    'simulink/GaN_Cauer_Figure14.slx; simulink/thermal_metrics.json; ../../reproduction/reference/independent_thermal_check.json',
    '论文4.7/1.8K、62%不能由本次完整5µs窗口得到；不改变电流/窗口迎合标注；作者详细输入和平均规则缺失')
row('TableI',7,'20次真实硬件自热测量统计',H,'原数值整理完成；硬件统计未重现',
    '原表逐项复核；不合成20次随机噪声或调整Ron凑均值',
    '传统/改进均值82.74/79.50mΩ，σ0.331/0.242mΩ，min82.09/78.79，max83.24/79.87mΩ',
    'ECCE_Europe_2024_GaN_Dynamic_Ron_Fulltext.pdf; ron_trapping/MODEL_CARD.txt; audit/AUDIT.txt',
    '样品、前历史、原始20次V/I、完整量程和热状态未知；Fig10低应力曲线绝对值不能直接代替此上待机实验')
row('SCRC门压不等式',3,'Vgs,LS1<Vgs,DUT避免辅助管反向导通',M+'；'+F,'完成条件扫描与适用范围审计',
    '双反向支路阈值、电阻、10mΩ DUT分流器；72个条件',
    '同阈值off-state无分流要求gap≥0.9/2.7/4.5V对应10/30/50A；极差散布示意2.4/4.2/6.0V',
    'scrc/README.txt; scrc/scrc_metrics.json; scrc/scrc_crosscheck_metrics.json',
    '仅严格低于不足保证任意电流完全隔离；+6V DUT/+0V LS1在30/50A仍分流；阈值7mA规格不能当高电流精确开启压降')
row('测量V/I语义',5,'逐时刻Vds,clamp(t)/Id(t)再取5µs均值',M+'；'+F,'完成实现核验',
    'DUT支路分流器与Vds分别测量；行为Ron六条件耦合',
    '设置Ron与逐时刻V/I均值差<8.16e−12Ω；原生电热集成与精确Cauer差3.20e−11K',
    'integration/integration_metrics.json; integration/native_integration_validation.json; scrc/README.txt',
    '该结果验证已设置元件值的电路实现；不构成独立GaN Ron预测。分流时误用总IL才出现诊断偏差；正确shunt仍测实际Id')
row('慢历史/快电路耦合',6,'上待机捕获与下待机恢复的跨尺度使用',C+'；'+F,'六个真实原生电路快照和一个同时电热SLX完成',
    'Ron(I,T,Vstress,t,schedule)→电气脉冲→I²R四级Cauer',
    f"native集成热差MAX={integrated['maximumDifferenceFromExactCauer_K']:.3g}K",
    'integration/GaN_Behavioral_Electrothermal_Snapshot.slx; integration/README.txt; ron_trapping/ron_behavior_coupled.m',
    '冻结历史Ron快照、30A增量可加性假设；非双向迭代物理陷阱耦合；不将残余自热重复反馈到Fig10曲面')
row('Tc范围',5,'论文温控能力−15..95°C；Ron静态/动态温度范围不同',C+'；'+F+'；'+H,'三类范围区分完整',
    'TEC−15/15/55/95°C；Fig10九条15..95°C；Fig12五条15..55°C',
    'TEC稳态目标误差<6e−12°C，独立ODE温差MAX5.68e−5K',
    'tec/TEC_Electrothermal_ClosedLoop_metrics.json; tec_audit/AUDIT.txt; ron_trapping/coordinate_provenance.json',
    '未宣称Fig12支持−15/95°C动态Ron；TEC闭环假设成功不等于真实散热/绝热能力验证')
row('±电流/额定',5,'正负电流并可短时达到±50A',M+'；'+F+'；'+H,'有符号电路和曲线覆盖完整',
    '同步±10/30/50A；Fig10约±50A；SCRC反向10/30/50A',
    '实际50A名义测量均值+48.2041/−48.2904A；脉冲操作不按30A连续额定解释',
    'simulink/electrical_metrics.json; scrc/scrc_metrics.json; ron_trapping/metrics.json',
    '模型没有证明SOA、封装电感、栅极过压或长期硬件安全；不能把50A脉冲当连续额定')
row('±5V夹钳量程',4,'测量最大约±5V，TVS±8V与VRWM±5.5V',M+'；'+F,'正确互锁下详细模型六例通过；失败保留',
    'BTB提前关断；DUT回正高压后才重闭；原厂Si-MOS宏模型',
    f"safe六例误差{min(abs(q['window_error_V']) for q in safe)*1e6:.1f}..{max(abs(q['window_error_V']) for q in safe)*1e6:.1f}µV；最后2%超差66.64..68.00ns",
    'clamp/wide_safe_metrics.json; clamp/wide_range_metrics.json; clamp/diagnostic_metrics.json; clamp/MODEL_CARD.md',
    '原慢驱动负5V有限窗口只到−4.2606V；DC/长窗口能恢复−4.99994V。错误互锁可18..75A体二极管短路；safe输入峰流0.181..0.607A，理想源不能证明真实DUT无扰动')
row('噪声σ/测量预算',4,'小量程降低实验σ与FS误差',F+'；'+H,'方向和预算完成；原σ未独立重现',
    '明确假设FS与12bit均匀量化；包含V/I误差和相关性解释',
    '假设跨度1.6/20/8V、10A：理想量化σ11.28/140.95/56.38µΩ；不等于原实验90.3/525.4/695µΩ',
    'clamp/noise_range_budget.json; clamp/MODEL_CARD.md',
    '20MHz与额外未知滤波、实际探头倍率/满量程/相关噪声未公开；未制造高斯σ匹配实验')
row('GS66508B厂家电气模型',5,'作者用GS66508B Schottky p-GaN DUT',F+'；'+H,'官方手册已核验；精确厂家紧凑文件未获得',
    'Rev200402规格/反向开启机理用于模型范围说明',
    '固定80mΩ主桥、公开曲线Ron和固定阈值SCRC三个显式模型；均非厂家完整电气宏模型',
    '../../reproduction/models/GS66508B_model_provenance.json; scrc/README.txt; simulink/README.txt; ron_trapping/MODEL_CARD.txt',
    '真实GaN非线性Coss/Cgd、gate charge、trap physics及switching loss未独立重现；夹钳厂家模型为代表性Si-MOS，不应混称GaN厂家模型')
row('GS66508B厂家热网络',7,'论文使用厂家公开热模型',M+'；'+F,'公开四级Cauer按实际热流连接完成',
    'R=[.015,.23,.24,.015]K/W；C=[8e−5,7.4e−4,.0065,.002]J/K',
    '原生Cauer与精确法一致；热容量/热阻单位和R4固定壳温边界明确',
    'simulink/thermal_metrics.json; simulink/GaN_Cauer_Figure14.slx',
    '官方网络仅结到壳瞬态；固定壳温不包含真实板级散热；不将热网络称完整厂家电气模型')
row('切换损耗扩展',2,'测切换损耗时必须拆除LS1，避免其Coss影响',F+'；'+H,'公开限制已复核；未独立量化开关损耗',
    'SecII-A文字与模型边界审核',
    'Ron项目保留LS1；没有对完整GaN非线性电容/开关能量进行厂家模型预测',
    'ECCE_Europe_2024_GaN_Dynamic_Ron_Fulltext.pdf; audit/AUDIT.txt',
    '未声称small modifications已经做成开关损耗实验；能量模型当前以导通I²R为主')

HERE.mkdir(parents=True,exist_ok=True)
for r in rows:
    r['证据路径']=r['证据路径'].replace('../../reproduction','../reproduction').replace('ECCE_Europe_2024_GaN_Dynamic_Ron_Fulltext.pdf','../ECCE_Europe_2024_GaN_Dynamic_Ron_Fulltext.pdf')
with (HERE/'coverage_matrix.csv').open('w',encoding='utf-8-sig',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)

# Evidence inventory, not an additional simulation or a claim that ZIP validity
# itself proves execution. Runtime flags and numeric records are listed above.
inventory=[]
for folder in ['simulink','ron_trapping','clamp','tec','tec_audit','integration','scrc']:
    for p in sorted((FULL/folder).glob('*')):
        if not p.is_file(): continue
        include=(p.suffix=='.slx' or p.name.startswith(('README','MODEL_CARD')) or
                 p.name.endswith(('metrics.json','validation.json','checks.json','convergence.json','verification.json')) or
                 p.name in ['native_model_integrity.json','crossfigure_axis_check.json','coordinate_provenance.json'])
        if include:
            record=dict(path=str(p.relative_to(ROOT)),bytes=p.stat().st_size,mtime=p.stat().st_mtime,sha256=sha(p))
            if p.suffix=='.slx':
                with zipfile.ZipFile(p) as z:
                    record['ZIP_integrity_failure']=z.testzip()
                    record['blockdiagram_xml_present']='simulink/blockdiagram.xml' in z.namelist()
            inventory.append(record)
logs=[ROOT/'work/simulink_full/build.log',ROOT/'work/simulink_full/integration.log',ROOT/'work/simulink_full/scrc.log',
      ROOT/'work/tec/native_tec_clean.log',ROOT/'work/tec/native_pwm_final.log',ROOT/'work/tec/native_pwm_half.log',
      FULL/'ron_trapping/MATLAB_Simulink_execution.log',FULL/'ron_trapping/coupled_verification.log']
for p in logs:
    if p.exists():
        s=p.read_text(encoding='utf-8',errors='replace')
        inventory.append(dict(path=str(p.relative_to(ROOT)),bytes=p.stat().st_size,mtime=p.stat().st_mtime,sha256=sha(p),
                              error_lines=[line for line in s.splitlines() if re.search(r'^Error|^错误|^Unrecognized',line)][:8],
                              note='Final-run log read; warnings do not imply failure, numeric execution evidence remains authoritative'))
summary=dict(audit_time=datetime.datetime.now().astimezone().isoformat(),source_paper_sha256=sha(ROOT/'outputs/ECCE_Europe_2024_GaN_Dynamic_Ron_Fulltext.pdf'),
             coverage_rows=len(rows),figures=list(range(1,15)),native_SLX_count=sum(q['path'].endswith('.slx') for q in inventory),
             four_evidence_layers=[M,C,F,H],TEC_native_SHA256_matches_independent_audit=sha(FULL/'tec/TEC_Electrothermal_ClosedLoop_results.csv')==teca['native_results_sha256'],
             all_native_SLX_ZIP_integrity_pass=all(q.get('ZIP_integrity_failure') is None for q in inventory),evidence=inventory)
(HERE/'evidence_inventory.json').write_text(json.dumps(summary,indent=2,ensure_ascii=False),encoding='utf-8')

audit='''全篇复现覆盖与主张审计

论文：Improved Test Circuit for Characterization of the Dynamic On-Resistance of GaN-HEMTs over a Wide Operating Range，IEEE ECCE Europe 2024，DOI 10.1109/ECCEEurope62508.2024.10751914。基于8页作者全文、公开厂家资料和本地真实执行结果。coverage_matrix.csv逐项涵盖图1–14、Table I和关键跨图关系，其中证据路径相对于outputs/full_reproduction根目录；evidence_inventory.json记录已审核模型、README、MODEL_CARD、指标及最终运行日志的SHA256，便于检查新鲜度。

四层证据必须分开
1 已独立机制验证：公开电路/热网络的真实原生求解，与解析RLC、独立KCL、精确Cauer或独立ODE交叉核验。此“独立”指数值实现/机理验证，不表示有第二批独立硬件实验；其精度也不能超过已声明参数假设。
2 公开曲线标定：图10–12原生PDF矢量曲线全部提取，并划分拟合、模型选择和留出测试；运行的Ron状态模型使用已标定参数。它重构公开测得行为，没有发现/恢复作者未发表陷阱物理。
3 功能假设：未公开的夹钳BOM、驱动时序、PCB电容、TEC热容和绝热、PI及传感器参数均明确写出。验证“这些假设下功能成立”不能改写为“作者实物参数已复原”。
4 未完成真实硬件实验：原PCB/夹具制造、仪器校准、原Fig6精确响应与σ、Table I的20次测量和SOA/真实负载扰动验证尚未做。不存在作者原始数据，不能用生成噪声或调参制造实验复现。

真实执行和主要证据
主桥原生SPS覆盖正负10/30/50A、上下待机和传统/改进基线；500µF是有限储能母线，90µH电感含明确1mΩ串联电阻。5ns/2.5ns步长充电电流差6.35mA、解析RLC终点差<8mA，跨LTspice平台电流RMS差约0.1683%。固定80mΩ的V/I返回80mΩ只是元件/测量公式实现核验。电流目标使用理想LI/V估计，名义±50A实际均值约+48.204/−48.290A。上下待机5ms残余Vds误差0.582mV和IL7.27mA均保留，未强行置零。

SCRC是图3负电流段落的门压关系；图4是待机。72个独立原生SLX条件和72个实际SPICE条件覆盖DUT栅压−3/0/+6V、总反向电流10/30/50A及门压差0..6V。固定阈值1.7V、反向电阻80mΩ、节点电容200pF和10mΩ DUT分流器下，解析支路差9.2e−9A，跨引擎DUT电流差1.07e−13A。GS66508B没有体二极管，关断第三象限由Vgd超阈值开启沟道。LS1栅压严格低于DUT仅提高其反向开启门槛；同阈值off-state模型无分流需要gap至少0.9/2.7/4.5V。DUT+6V而LS1=0V时，30/50A仍发生5.88/16.47A辅助分流。正确的DUT分流器仍测实际DUT支路电流；只有误把总IL代入V/I才构成该诊断偏差。典型阈值规格在7mA给出，线性高电流模型不等同厂家精确特性。

夹钳已运行34个原厂Si-MOS宏模型SPICE案例和10个降阶SLX分支，包含正负低压、驱动敏感性、宽量程、DC/长时恢复和互锁。普通±0.48V测量误差<8µV，慢驱动约295µV。正确互锁的50/150/400V×±5V六例全部通过本次有限窗口±2%电压判据，误差58.9..103.7µV，恢复66.64..68.00ns。原慢驱动−5V在1.4..1.8µs窗口只到−4.2606V是尚未恢复，不能称其没有负向量程：独立DC和6..7µs延长窗口到−4.99994V。错误互锁令Blocking体二极管与仍开通BTB短接，18..75A大电流暴露出理想输入的局限；safe互锁峰输入电流仍0.181..0.607A，不能据此证明真实DUT无扰动。作者夹钳BOM未知，ST/Diodes厂家文件是本次代表性Si-MOS元件，不是GS GaN厂家模型。原275/160/120ns和90.3/525.4/695µΩ仍属于作者实验对照。12bit与20MHz不足恢复实际噪声；量化预算的跨度及协方差解释均公开，没有以原σ设置随机噪声。

TEC双Buck原生PWM带LC，两级PI长时模型接真实Peltier守恒端口。15/55/−15/95°C各600s，与独立6状态SciPy Radau的温差MAX5.68e−5K、电流差MAX1.43e−5A。正电流冷却A、负电流加热A的热流号和Peltier电功率+QA+QB=0经独立方程审计；稳态I约+.255886/−.618032/+1.327220/−1.231397A。外环±3A是参考限幅，实际短时峰3.5092A；不得称实际电流始终≤3A。模型是无限理想25°C散热器，壳体热容4.5J/K、绝热G=.02W/K及传感器/PI属假设，无平均DUT负荷；达标不等于真实−15..95°C硬件热能力已验证。论文明确给−15..95°C能力，不能误写成论文外测试。作者TEC标8.6W，现行规格8.4W用于本次alpha反算，二者版本差异需保留。PWM100ns/50ns半步长平台差RMS3.15mA、全轨迹MAX26.76mA，真实PWM开关斜率不应要求逐点完全相同。

图10–12全部22条曲线均已提取，坐标索引、轴和原PDF哈希可追溯。图10五个训练温度、四个整温度留出，留出RMSE0.490707mΩ、MAX2.336989mΩ。图11、12时间块独立曲线点测试RMSE分别0.0523..0.0950、0.0465..0.1085mΩ；这是同条件公开曲线留出，未验证整电压/整动态温度外推。原生两个捕获/恢复模型实际积分−14..39min（53min），不是CSV回放；原生与解析状态解差MAX0.000675mΩ。部分tau<5s，在作者5s采样下无法独立识别为真实快陷阱常数。接口只支持25°C的50..400V电压切片或150V的15..55°C温度切片，没有编造二维联合应力网格。六个行为Ron→原生测量脉冲→Cauer快照实际执行；+30A捕获例的同时电热SLX与精确热网络差3.20e−11K。陷阱增量按30A数据与静态曲面相加、历史Ron冻结均为显式功能假设。图10测的是Tc且可能含残余自热，额外Cauer温升未再反馈进拟合曲面，以避免重复算热。

图13实现了把充电导通损耗从DUT转移到LS1的机制。图14按厂家四级Cauer、50A时序模板、32.5µs充电/1µs续流/5µs测量与零初始温升计算，完整33.5..38.5µs均值5.236685/2.527375K，下降51.737126%，原生与精确法差<2.72e−5K。论文图示4.7/1.8K和62%不能从该完整窗口取得；公开原图曲线积分也支持约51.7%的结果。没有调整窗口、电流或热参数凑62%；作者实际输入/平均规则缺失，不将此差异扩大为所有设定下的论文错误。Table I来自20次硬件测量：82.74/79.50mΩ均值和0.331/0.242mΩ标准差；其上待机历史、样品状态及原始V/I没有公开，不能把Fig10低应力静态曲线、自热估计或随机波动拼成这20次实验。

结构复核和剩余实物边界
图8/9确认主板、可换测试夹具、隔离驱动电源、局部换流电容与主500µF、独立电感PCB、夹钳、温敏元件和DUT分流器。测量时双继电器全极隔离高压电源；主板和TEC有独立24V实验电源，仪器经Ethernet/UART自动控制。模型覆盖公开电气/控制连接，未生成作者原PCB布线和装配实物；照片只作结构对应，不能伪装成数值仿真。LS1在测开关损耗时需拆除以免Coss影响；本次没有厂家完整GaN电荷模型或独立开关损耗实验。

来源内差异与可复现边界
Fig10正文VDC150V与图内应力100V注释冲突。动态应力释放正文13min，而原矢量竖线/响应在13.58..14min附近；标定使用公开曲线的切换对齐时刻，并非恢复控制命令。Fig11的150V与Fig12的25°C同条件660个重合矢量点最大差6.34e−6mΩ，提供轴交叉核验，但不是独立第二批样本。温控8.6/8.4W、Fig14平均值差异及未知仪器条件均列入矩阵，未经数据支持不作选择性抹除。

可合理交付的结论
可称“整篇公开内容的分层仿真与数据重构已覆盖”：14幅图的结构/程序/公开曲线和相关机制都在矩阵中有对应。可称“原生可编辑模型已实际执行并完成相应数学校核”。不可称“完成作者全部真实硬件实验”“恢复隐藏的GaN陷阱物理模型”“精确独立重现所有噪声/响应统计”或“用厂家GaN紧凑模型预测了全过程”。公开缺失项已明确封存为实物/作者原始数据边界，不因缺失而制造结果。

主要原始资料
作者全文：https://publikationen.bibliothek.kit.edu/1000176527/155655990
GS66508B Rev200402：https://www.infineon.com/assets/row/public/documents/24/49/infineon-gs66508b-datasheet-en.pdf
MathWorks Peltier方程：https://www.mathworks.com/help/simscape-electrical/ref/peltierdevice.html
本次夹钳代表性厂商元件链接和哈希见clamp/sources/source_manifest.json。
'''
(HERE/'AUDIT.txt').write_text(audit,encoding='utf-8-sig')
print(json.dumps({k:v for k,v in summary.items() if k!='evidence'},ensure_ascii=False,indent=2))
