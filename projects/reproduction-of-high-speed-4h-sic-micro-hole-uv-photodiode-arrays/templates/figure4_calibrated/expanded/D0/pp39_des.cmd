Device PIN {
 File {
  Grid="n25_msh.tdr"
  Parameter="pp39_des.par"
  Load="__FIGURE3_PROJECT__/n49_darkV20_des.sav"
  Current="n39_des.plt"
  Plot="n39_des.tdr"
 }
Electrode {
 { Name="anode" Voltage=0 }
 { Name="cathode" Voltage=0 }
}

Physics {
 AreaFactor=4444.44444444444
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
   TimeDependence(
    WaveTime=(5e-9 5e-9)
    WaveTSigma=6.00561204393225e-12
    WaveTPeriod=1e-6
    WavePeriods=6
    Scaling=1
    OpticalTurningPoints(
     MinAmplitude=1e-8
     DtRise=1e-12 DtFall=1e-12 DtPlateau=0
     DtRiseStart=1e-12 DtRiseEnd=0
     DtFallStart=0 DtFallEnd=1e-12
    )
   )
  )
  Excitation (
   Wavelength=0.266
   Intensity=17902.961672
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


}
File{Output="n39_des.log"}
Math {
 Transient=BE

 Digits=7
 ErrRef(electron)=1e-2
 ErrRef(hole)=1e-2
 RHSMin=1e-18
 Iterations=25
 NotDamped=100

 Method=Blocked
 SubMethod=ParDiSo
 NumberOfThreads=2
 eMobilityAveraging=ElementEdge
 hMobilityAveraging=ElementEdge
 RefDens_eGradQuasiFermi_ElectricField_HFS=1e12
 RefDens_hGradQuasiFermi_ElectricField_HFS=1e12
 CdensityMin=1e-30
 CurrentPlot(IntegrationUnit=cm)
 ExitOnFailure
}


System {
 PIN pd("anode"=out "cathode"=nbias)
 Vsource_pset supply(nbias 0){dc=20}
 Resistor_pset rseries(out meas){resistance=567.53594}
 Capacitor_pset cscope(meas 0){capacitance=5e-12}
 Resistor_pset rload(meas 0){resistance=50}
 Hint(out=0 meas=0 nbias=20)
 Plot "n39_circuit.plt" (time() v(out) v(nbias) i(pd,out) i(pd,nbias) i(rload,meas) v(meas) i(rseries,out) i(rseries,meas) i(cscope,meas))
}
Solve {
 NewCurrentPrefix="dark_"
 Coupled(Iterations=100){pd.Poisson}
 Coupled(Iterations=100){pd.Poisson pd.Electron pd.Hole pd.Contact Circuit}

 Coupled(Iterations=100){pd.Poisson pd.Electron pd.Hole pd.Contact Circuit}
 Save(FilePrefix="n39_dark266")
 Plot(FilePrefix="n39_dark266")
 NewCurrentPrefix="pulse_"
 Transient(
  InitialTime=0 FinalTime=6e-6
  InitialStep=1e-12 MinStep=1e-18 MaxStep=5e-8 Increment=1.4 Decrement=2
  TurningPoints(
  (Condition(Time(4.94e-09)) Value=1e-12)
  (Condition(Time(Range=(4.94e-09 5.06e-09))) Value=1e-12)
  (Condition(Time(Range=(5.06e-09 6e-09))) Value=5e-12)
  (Condition(Time(Range=(6e-09 1.5e-08))) Value=5e-11)
  (Condition(Time(Range=(1.5e-08 1.05e-07))) Value=2e-9)
  (Condition(Time(1.00494e-06)) Value=1e-12)
  (Condition(Time(Range=(1.00494e-06 1.00506e-06))) Value=1e-12)
  (Condition(Time(Range=(1.00506e-06 1.006e-06))) Value=5e-12)
  (Condition(Time(Range=(1.006e-06 1.015e-06))) Value=5e-11)
  (Condition(Time(Range=(1.015e-06 1.105e-06))) Value=2e-9)
  (Condition(Time(2.00494e-06)) Value=1e-12)
  (Condition(Time(Range=(2.00494e-06 2.00506e-06))) Value=1e-12)
  (Condition(Time(Range=(2.00506e-06 2.006e-06))) Value=5e-12)
  (Condition(Time(Range=(2.006e-06 2.015e-06))) Value=5e-11)
  (Condition(Time(Range=(2.015e-06 2.105e-06))) Value=2e-9)
  (Condition(Time(3.00494e-06)) Value=1e-12)
  (Condition(Time(Range=(3.00494e-06 3.00506e-06))) Value=1e-12)
  (Condition(Time(Range=(3.00506e-06 3.006e-06))) Value=5e-12)
  (Condition(Time(Range=(3.006e-06 3.015e-06))) Value=5e-11)
  (Condition(Time(Range=(3.015e-06 3.105e-06))) Value=2e-9)
  (Condition(Time(4.00494e-06)) Value=1e-12)
  (Condition(Time(Range=(4.00494e-06 4.00506e-06))) Value=1e-12)
  (Condition(Time(Range=(4.00506e-06 4.006e-06))) Value=5e-12)
  (Condition(Time(Range=(4.006e-06 4.015e-06))) Value=5e-11)
  (Condition(Time(Range=(4.015e-06 4.105e-06))) Value=2e-9)
  (Condition(Time(5.00494e-06)) Value=1e-12)
  (Condition(Time(Range=(5.00494e-06 5.00506e-06))) Value=1e-12)
  (Condition(Time(Range=(5.00506e-06 5.006e-06))) Value=5e-12)
  (Condition(Time(Range=(5.006e-06 5.015e-06))) Value=5e-11)
  (Condition(Time(Range=(5.015e-06 5.105e-06))) Value=2e-9)
  )
 ){
  Coupled{pd.Poisson pd.Electron pd.Hole pd.Contact Circuit}
  Plot(FilePrefix="n39_pulse5ns" Time=(5e-9))
 }
 Plot(FilePrefix="n39_final6us")
}

