#setdep @node|sde@
#seth Wcell @<HoleD_um+HoleGap_um>@
#seth HalfCell @<0.5*(HoleD_um+HoleGap_um)>@

File {
 Grid="@tdr@"
 Parameter="@parameter@"
 Current="@plot@"
 Plot="@tdrdat@"
 Output="@log@"
}

Electrode {
 { Name="anode" Voltage=0 }
 { Name="cathode" Voltage=0 }
}

Physics {
 AreaFactor=@<40000.0/(HoleD_um+HoleGap_um)>@
 Temperature=300
 Fermi
 DefaultParametersFromFile
 EffectiveIntrinsicDensity(Slotboom NoFermi)
 Mobility(DopingDependence HighFieldSaturation)
 IncompleteIonization
 Recombination(SRH(DopingDependence) Auger)
 Aniso(Mobility Poisson direction(SimulationSystem)=(0 1 0))
 Optics (
  ComplexRefractiveIndex(WavelengthDep(Real Imag))
  OpticalGeneration (
   QuantumYield(StepFunction(EffectiveBandgap))
   ComputeFromMonochromaticSource
   Scaling=0
  )
  Excitation (
   Wavelength=0.200
   Intensity=1.4175e-5
   Polarization=0.5
   Theta=0
   Window(Origin=(0 -0.080) Line(x1=-@HalfCell@ x2=@HalfCell@))
  )
  OpticalSolver (
   RayTracing (
    RayDistribution(Mode=AutoPopulate NumberOfRays=601)
    DepthLimit=1000
    MinIntensity=1e-6
    CompactMemoryOption
   )
  )
 )
}

# Both p+ truncation contacts carry the same bias. Absorbing the far substrate
# boundary approximates a semi-infinite substrate, rather than an optical mirror.
RayTraceBC {
 { Name="anode" Reflectivity=0 Transmittivity=0 }
 { Name="cathode" Reflectivity=0 Transmittivity=0 }
}

Plot {
 DopingConcentration DonorConcentration AcceptorConcentration
 eDensity hDensity Potential SpaceCharge
 ElectricField/Vector eCurrent/Vector hCurrent/Vector
 BandGap ConductionBandEnergy ValenceBandEnergy
 eQuasiFermiEnergy hQuasiFermiEnergy
 eMobility hMobility eLifeTime hLifeTime
 SRH Auger OpticalGeneration AbsorbedPhotonDensity
 ComplexRefractiveIndex QuantumYield
}

CurrentPlot {
 ModelParameter="Wavelength"
 ModelParameter="Optics/OpticalGeneration/Scaling"
 OpticalGeneration(Integrate(Semiconductor))
 SRH(Integrate(Semiconductor))
}

Math {
 ExtendedPrecision(128)
 Digits=7
 ErrRef(electron)=1e-2
 ErrRef(hole)=1e-2
 RHSMin=1e-18
 Iterations=25
 NotDamped=100
 Extrapolate
 Method=Super
 NumberOfThreads=2
 eMobilityAveraging=ElementEdge
 hMobilityAveraging=ElementEdge
 RefDens_eGradQuasiFermi_ElectricField_HFS=1e12
 RefDens_hGradQuasiFermi_ElectricField_HFS=1e12
 CdensityMin=1e-30
 CurrentPlot(IntegrationUnit=cm)
 ExitOnFailure
}

Solve {
 NewCurrentPrefix="dark_"
 Coupled(Iterations=200 LineSearchDamping=0.001) { Poisson }
 Coupled(Iterations=200) { Poisson Electron Hole }
 Quasistationary(
  InitialStep=0.01 MaxStep=0.1 MinStep=1e-8 Increment=1.4
  Goal { Name="cathode" Voltage=@Vr_V@ }
 ) { Coupled { Poisson Electron Hole } }
 Plot(FilePrefix="n@node@_darkV@Vr_V@")
 Save(FilePrefix="n@node@_darkV@Vr_V@")

 NewCurrentPrefix="light_init_"
 Quasistationary(
  InitialStep=0.02 MaxStep=0.2 MinStep=1e-8 Increment=1.4
  Goal { ModelParameter="Optics/OpticalGeneration/Scaling" Value=1 }
 ) { Coupled { Poisson Electron Hole } }

 NewCurrentPrefix="spectrum_"
 Quasistationary(
  DoZero
  InitialStep=0.025 MaxStep=0.025 MinStep=1e-8 Increment=1.4
  Goal { ModelParameter="Wavelength" Value=0.400 }
 ) {
  Coupled { Poisson Electron Hole }
  CurrentPlot(Time=(Range=(0 1) Intervals=40))
  Plot(FilePrefix="n@node@_lambda280nm" Time=(0.4))
 }
 Plot(FilePrefix="n@node@_lambda400nm")
}
