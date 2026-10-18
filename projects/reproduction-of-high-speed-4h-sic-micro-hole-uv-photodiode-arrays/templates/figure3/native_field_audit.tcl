foreach {N D V} {38 4 5 46 4 20 40 8 5 52 8 20 49 0 20} {
 set ds [load_file n${N}_lambda280nm_des.tdr -name N${N}]
 set plt [create_plot -dataset $ds -name N${N}]
 foreach x {0.0 1.8} {
  set line [create_cutline -plot $plt -type x -at $x]
  export_variables {Y ElectrostaticPotential eDensity hDensity DonorConcentration AcceptorConcentration eLifetime hLifetime OpticalGeneration SRHRecombination ElectricField-Y} -dataset $line -filename native_cut_D${D}_V${V}_x${x}.csv -overwrite
 }
}
exit
