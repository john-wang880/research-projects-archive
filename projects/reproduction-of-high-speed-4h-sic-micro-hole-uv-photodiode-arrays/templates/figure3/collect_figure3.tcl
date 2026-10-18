load_library physicalconstants
set WL {Device=,File=CommandFile/Physics,DefaultRegionPhysics,ModelParameter=Optics/Excitation/Wavelength}
set PH {Device=,File=CommandFile/Physics,DefaultRegionPhysics,ModelParameter=Optics/OpticalGeneration/Scaling}
set Pin 5.67e-9
set q $const::ElementaryCharge
set hc_over_q [expr $const::PlanckConstant*$const::SpeedOfLight/$q*1e9]
foreach {name title} {P0 {(a) Without micro-hole} P4 {(b) 4 um micro-hole} P8 {(c) 8 um micro-hole} PC {(d) 20 V comparison}} {
 create_plot -1d -name $name
 set_plot_prop -plot $name -title $title
 set_axis_prop -plot $name -axis x -title {Wavelength (nm)} -range {200 400} -type linear
 set_axis_prop -plot $name -axis y -title {Responsivity (A/W)} -type linear
 set_legend_prop -plot $name -location top_right -label_font_size 12
}
create_plot -1d -name AUDIT
set peakfile [open figure3_peaks.csv w]
puts $peakfile "diameter_um,Vr_V,peak_wavelength_nm,peak_responsivity_A_W,peak_EQE_percent"

foreach {N SN D VR} {
 39 25 0 5 47 25 0 10 48 25 0 15 49 25 0 20
 38 13 4 5 44 13 4 10 45 13 4 15 46 13 4 20
 40 37 8 5 50 37 8 10 51 37 8 15 52 37 8 20
} {
 set dark [load_file dark_n${N}_des.plt -name Dark_${N}]
 create_curve -name DC_${N} -plot AUDIT -dataset $dark -axisX {cathode OuterVoltage} -axisY {cathode TotalCurrent}
 set idark [lindex [get_curve_data DC_${N} -axisY] end]
 set vdark [lindex [get_curve_data DC_${N} -axisX] end]
 if {abs($vdark-$VR)>1e-5} { error "Dark bias endpoint missing at n$N" }
 set light [load_file spectrum_n${N}_des.plt -name Spectrum_${N}]
 foreach {key field} [list W $WL I {cathode TotalCurrent} A {anode TotalCurrent} V {cathode OuterVoltage} G {IntegrSemiconductor OpticalGeneration} S $PH] {
  create_curve -name ${key}_${N} -plot AUDIT -dataset $light -axisX $WL -axisY $field
  set arr($key) [get_curve_data ${key}_${N} -axisY]
 }
 set waves {};set rs {};set eqes {};set rows {};set peak -1;set peaklambda 0;set maxeqe 0
 set outfile [open figure3_D${D}_V${VR}.csv w]
 puts $outfile "wavelength_nm,Vr_V,current_light_A,current_dark_A,responsivity_A_W,EQE_percent,optical_generation_integral_cm_1_s_1,terminal_balance_A,optical_scaling"
 set seen [dict create]
 foreach wl $arr(W) i $arr(I) a $arr(A) v $arr(V) g $arr(G) scale $arr(S) {
  set nm [expr 1000*$wl]
  if {abs($v-$VR)>1e-5 || abs($scale-1)>1e-6} { error "Bias or illumination endpoint missing at n$N" }
  set grid [expr round(($nm-200.)/5.)]
  if {abs($nm-(200+5*$grid))>1e-3} { continue }
  if {[dict exists $seen $grid]} { continue }
  dict set seen $grid 1
  set r [expr abs($i-$idark)/$Pin]
  set eqe [expr 100*$r*$hc_over_q/$nm]
  lappend waves $nm; lappend rs $r; lappend eqes $eqe
  puts $outfile [join [list $nm $v $i $idark $r $eqe $g [expr $i+$a] $scale] ,]
  if {$r>$peak} {set peak $r;set peaklambda $nm;set maxeqe $eqe}
 }
 close $outfile
 if {[dict size $seen]!=41 || ![dict exists $seen 0] || ![dict exists $seen 40]} {
  error "Incomplete spectral grid at n$N: [dict size $seen]/41 wavelengths"
 }
 puts $peakfile [join [list $D $VR $peaklambda $peak $maxeqe] ,]
 create_variable -name Wavelength_nm -dataset R_${N} -values $waves
 create_variable -name Responsivity_A_W -dataset R_${N} -values $rs
 create_variable -name EQE_percent -dataset R_${N} -values $eqes
 set panel P${D}
 create_curve -name Responsivity_${N} -plot $panel -dataset R_${N} -axisX Wavelength_nm -axisY Responsivity_A_W
 set color [dict get [dict create 5 black 10 red 15 blue 20 #008c8c] $VR]
 set_curve_prop Responsivity_${N} -plot $panel -color $color -label "${VR} V" -line_width 2
 if {$VR==20} {
  create_curve -name Compare_${N} -plot PC -dataset R_${N} -axisX Wavelength_nm -axisY Responsivity_A_W
  set label "${D} um"
  if {$D==0} {set label "Without hole"}
  set_curve_prop Compare_${N} -plot PC -color [dict get [dict create 0 black 4 red 8 blue] $D] -label $label -line_width 2
 }
}
close $peakfile
remove_plots AUDIT
foreach panel {P0 P4 P8 PC} {
 export_view figure3_${panel}_native.png -plots $panel -format PNG -resolution 1200x900 -overwrite
}
export_view figure3_native.png -plots {P0 P4 P8 PC} -format PNG -resolution 1800x1400 -overwrite
puts "FIGURE3_NATIVE_EXTRACTION_PASSED_12_CURVES_41_WAVELENGTHS"
exit
