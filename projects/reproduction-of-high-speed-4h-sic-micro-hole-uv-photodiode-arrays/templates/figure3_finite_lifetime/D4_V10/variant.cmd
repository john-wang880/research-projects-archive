
File {
 Grid="__FIGURE3_PROJECT__/n13_msh.tdr"
 Parameter="__FIGURE3_VARIANT_PROJECT__/D4_V10/variant.par"
 Current="variant.plt"
 Plot="variant.tdr"
 Output="variant.log"
}

Electrode {
 { Name="anode" Voltage=0 }
 { Name="cathode" Voltage=0 }
}

Physics {
 AreaFactor=4444.44444444
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
   Window(Origin=(0 -0.080) Line(x1=-4.5 x2=4.5))
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

RayTraceBC {
 { Name="anode" Reflectivity=0 Transmittivity=0 }
 { Name="cathode" Reflectivity=0 Transmittivity=0 }
}

Physics(MaterialInterface="4HSiC/Oxide"){Recombination(SurfaceSRH)}
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
 ExtendedPrecision(80)
 Digits=7
 ErrRef(electron)=1e-2
 ErrRef(hole)=1e-2
 RHSMin=1e-18
 Iterations=25
 NotDamped=100

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
 Load(FilePrefix="__FIGURE3_PROJECT__/n44_darkV10")
 NewCurrentPrefix="dark_"
 Coupled(Iterations=100){Poisson Electron Hole}
 Plot(FilePrefix="variant_dark")
 NewCurrentPrefix="light_init_"
 Quasistationary(InitialStep=0.1 MaxStep=0.5 MinStep=1e-8 Increment=1.5 Goal{ModelParameter="Optics/OpticalGeneration/Scaling" Value=1}){Coupled{Poisson Electron Hole}}
 NewCurrentPrefix="spectrum_"
 Quasistationary(DoZero InitialStep=0.025 MaxStep=0.025 MinStep=1e-8 Increment=1.5 Goal{ModelParameter="Wavelength" Value=0.4}){
  Coupled{Poisson Electron Hole}
  CurrentPlot(Time=(Range=(0 1) Intervals=40))
  Plot(FilePrefix="variant280" Time=(0.4))
 }
 Plot(FilePrefix="variant400")
}
