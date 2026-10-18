* Functional circuit reproduction of ECCE Europe 2024, DOI 10.1109/ECCEEurope62508.2024.10751914
* Fixed Ron model for current-path/self-heating study, NOT a validated GS66508B compact model.
* Paper: VDC=150V, Cdc=500uF, L=90uH, tcharge=32.5us, tfreewheel=1us, tmeasure=5us.
* Assumed: auxiliary Ron=80mOhm, constant Coss=200pF, reverse diode approximation, 40ns deadtime (TD each side).
.param VDC=150 LLOAD=90u CDCVAL=500u RDUT=80m RAUX=80m RSHUNT=10m
.param T0=2u TCH=32.5u TFW=1u TMEAS=5u TD=20n TR=10n
.param T1={T0+TCH} T2={T1+TFW} T3={T2+TMEAS} TSTOP=55u
.model SWD SW(Ron={RDUT} Roff=1e10 Vt=3 Vh=0)
.model SWA SW(Ron={RAUX} Roff=1e10 Vt=3 Vh=0)
* Reverse path only serves commutation. No switching-loss or trap prediction is claimed.
.model DREV D(Is=1e-18 N=2.5 Rs=20m Cjo=0)
D_HS1 left bus DREV
D_HS2 right bus DREV
D_DUT source_dut left DREV
D_LS1 0 left DREV
D_LS2 0 right DREV
C_HS1 bus left 200p
C_HS2 bus right 200p
C_DUT left source_dut 200p
C_LS1 left 0 200p
C_LS2 right 0 200p
R_LEAK bus 0 1G
.options plotwinsize=0 reltol=1e-5 abstol=1e-9 vntol=1e-7 numdgt=12
.temp 25
.tran 0 {TSTOP} 0 5n uic
.save V(bus) V(left) V(right) V(source_dut) V(g_dut) V(g_ls1) V(g_ls2) V(g_hs1) V(g_hs2) I(LLOAD) I(VDUT) I(S_LS1) I(S_LS2) I(CDC)
.meas TRAN id_meas AVG I(VDUT) FROM {T2} TO {T3}
.meas TRAN id_charge RMS I(VDUT) FROM {T0+100n} TO {T1-100n}
.meas TRAN ls1_meas RMS I(S_LS1) FROM {T2+100n} TO {T3-100n}
.meas TRAN bus_end FIND V(bus) AT {T1}
