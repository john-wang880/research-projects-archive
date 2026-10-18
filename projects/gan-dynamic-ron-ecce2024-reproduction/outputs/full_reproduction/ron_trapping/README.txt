MATLAB R2022b与已授权Simulink

进入本文件夹后执行：
  build_run_ron_models

此命令重建三个原生SLX、运行所有图10至12条件、保存原生FIG与MAT，并刷新Simulink_execution_metrics.json。曲线模型参数已保存在model_parameters.json，因此MATLAB重跑不需要Python或网络。

单条件查询：
  R_mOhm = ron_static_behavior(30,25)
  [R_mOhm,p] = ron_trap_behavior((-14:1/12:39)','fig11',150)
  [R_Ohm,info] = ron_behavior_coupled(30,25,150,10,0,13,25)

所有慢历史时间单位为分钟，静态Ron和独立陷阱查询输出mΩ，耦合接口输出Ω。

从PDF重新抽取并拟合
此步骤可选，不属于保存参数的MATLAB一键重跑。初始bundled Python没有全部科学库。
已成功运行的环境为Python 3.12.14；固定版本见requirements-refit.txt。
在其他机器先用Python 3.12安装requirements-refit.txt中的依赖，然后运行：
  python reconstruct_ron_trapping.py "完整论文PDF路径" "本文件夹路径"
  MATLAB执行build_run_ron_models

数据与指标
  *_native.csv：全部图线坐标和PDF坐标
  *_comparison.csv：逐点标定、模型选择、独立测试角色
  coordinate_provenance.json：轴、曲线索引、线宽、来源哈希
  crossfigure_axis_check.json：图11的150V与图12的25°C共用条件坐标交叉核对
  fit_metrics.csv / metrics.json：逐条件拟合与留出误差
  Simulink_execution_metrics.json：实际运行与解析解交叉验证
  MODEL_CARD.txt：范围、模型方程、已知源文件差异和不可复现项

完整复现包应同时保留作者8页全文以及原来的图13至14电流/自热项目。此文件夹只覆盖图10至12，不取代硬件实验记录。
