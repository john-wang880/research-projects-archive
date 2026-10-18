ECCE Europe 2024 GaN动态导通电阻测试电路：全篇仿真复现
论文 DOI 10.1109/ECCEEurope62508.2024.10751914
公开全文 https://publikationen.bibliothek.kit.edu/1000176527

先读 GaN_ECCE2024_全篇仿真复现报告.pdf。
公开版包含11个可编辑SLX、原生LTspice ASC/CIR、选定CSV、结果图片、
逐图覆盖表和文件哈希。第三方模型用仓库根目录tools/fetch_external.py获取；
大型RAW/MAT/FIG由运行生成。执行证据见docs/validated-run.json和docs/native_execution。

Windows直接运行
在本文件夹打开PowerShell 7，执行：
  .\开始复现.ps1 -Mode Check
  .\开始复现.ps1
默认All模式先串行运行40个LTspice任务（包括34个夹钳CIR、1个72条件
SCRC网表、3个夹钳ASC和2个主桥ASC），再重建并实际运行所有11个SLX。
  .\开始复现.ps1 -Mode Simulink
  .\开始复现.ps1 -Mode LTspice
  .\开始复现.ps1 -Mode Open
Open只打开主桥、宽量程夹钳和温控模型，不重跑。
默认软件路径E:\MATLABR2022b\bin\matlab.exe和D:\LTspice\LTspice.exe；
可用-MatlabPath和-LTspicePath覆盖。软件需相应许可证。
也可在MATLAB中进入本目录，直接运行 run_all 或 open_models。
重跑会重新生成本工程的模型和结果；请先保存自己的修改并保留原包。
运行记录在run_logs；统一MATLAB阶段状态在unified_run_status.json。

解压时保留outputs/full_reproduction与outputs/reproduction的同级关系。
主MATLAB运行使用已保存参数，不需要Python或联网。
可选重新提取/拟合论文图线需要ron_trapping/requirements-refit.txt中的
Python依赖。分析脚本可重新计算数值交叉校核；原始验证结果随包提供。
slprj和slxc是可再生缓存，不是交付必需文件。编译使用系统临时短路径，
避免Windows深层目录超过260字符限制。

覆盖与边界
simulink：±10/30/50 A、上下待机、传统/改进主桥和四级Cauer。
scrc：72条件第三象限并联分流，Simulink与LTspice同方程交叉运行。
clamp：非线性原厂代表性Si-MOS夹钳、±5 V、互锁、滤波/量化及诊断。
tec / tec_audit：原生热电端口、双Buck PWM、温度/电流PI和独立能量核验。
ron_trapping：9条静态、8条电压、5条温度曲线与显式捕获/释放状态。
integration：6种应力/温度/极性快照，从原生电流功率连接到原生Cauer。
audit：图1-14与Table I覆盖、证据层级和未公开输入。
reproduction（同级）：图13/14第一阶段LTspice和热重建完整证据。

最重要的数值发现：按图14完整33.5-38.5 us窗口，平均温升降低51.74%，
原PDF矢量曲线积分也约51.75%；公开稿标注62%的平均口径无法据此确认。
静态/陷阱模型是公开图线标定及留出检验，不是独立器件实验。
作者BOM、PCB寄生、示波器原始噪声、Table I的20次实测样本和真实
GaN紧凑模型未完整公开。因此全篇公开模块已作仿真覆盖，但不声称
复做了全部硬件实验，也不声称校准误差等于真实物理预测精度。

manifest.json保存交付文件SHA256。重跑会改变结果文件与模型时间戳；
原哈希用于核验本次交付快照，重跑后不再代表新生成文件。

2026-10-02统一入口已实际完整运行：40个LTspice任务与9个MATLAB阶段通过。
夹钳ASC/CIR测量窗口吻合；换流细节仍对求解顺序敏感，基线局部点差
最大1.24 V，50 ps/Gear复查仍约0.5 V。报告保留失败的全轨迹判据，
不将运行完成等同于尖峰逐点收敛。
