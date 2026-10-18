; Fu et al., IEEE TED 2023, DOI 10.1109/TED.2023.3286379.
; 2D central cut through one circular micro-hole, represented as a slot.
; Units: geometry in um, chemical active dopant concentrations in cm^-3.
; Figure 3 baseline. HoleD=0 is a planar control; 4/8 are slot cuts.
; Positive-hole geometry, doping and contacts follow the existing SDE.

(sde:clear)
(sde:set-process-up-direction "-y")
(sdegeo:set-default-boolean "ABA")

; Workbench-visible inputs. The paper's 5 um spacing is interpreted as
; edge-to-edge spacing; consequently the nominal cell pitch is 9 um.
(define HoleD @HoleD_um@)
(define HoleGap @HoleGap_um@)
(define EtchDepth @EtchDepth_um@)
(define Tp @Tp_um@)
(define Ti @Ti_um@)
(define Tn @Tn_um@)
(define Tox @Tox_um@)
; Truncated substrate and its doping are explicit modeling assumptions.
(define Tsub @Tsub_um@)
(define NAp @NAp@)
; The paper gives N=1e15 for the i layer without identifying its polarity.
; Here it is a residual n-type layer, exposed as an editable parameter.
(define NDi @NDi@)
(define NDn @NDn@)
(define NDsub @NDsub@)

(define Wcell (+ HoleD HoleGap))
(define Hcell (/ Wcell 2.0))
(define Rhole (/ HoleD 2.0))
(define Ypi Tp)
(define Yin (+ Tp Ti))
(define Ynsub (+ Tp Ti Tn))
(define Ybottom (+ Tp Ti Tn Tsub))

; Keep one connected i region with a 20 nm deep recess at the hole floor.
; Creating this polygon directly avoids dopant placement on a deleted body.
(if (> HoleD 0.0)
 (begin
(sdegeo:create-polygon
 (list (position (- Hcell) Ypi 0)
       (position (- Rhole) Ypi 0)
       (position (- Rhole) EtchDepth 0)
       (position Rhole EtchDepth 0)
       (position Rhole Ypi 0)
       (position Hcell Ypi 0)
       (position Hcell Yin 0)
       (position (- Hcell) Yin 0))
 "4HSiC" "R.i")

(sdegeo:create-rectangle
 (position (- Hcell) 0 0) (position (- Rhole) Ypi 0)
 "4HSiC" "R.pPlus.left")
(sdegeo:create-rectangle
 (position Rhole 0 0) (position Hcell Ypi 0)
 "4HSiC" "R.pPlus.right")
)
 (begin
 (sdegeo:create-rectangle (position (- Hcell) Ypi 0)
  (position Hcell Yin 0) "4HSiC" "R.i")
 (sdegeo:create-rectangle (position (- Hcell) 0 0)
  (position Hcell Ypi 0) "4HSiC" "R.pPlus.left")))

(sdegeo:create-rectangle
 (position (- Hcell) Yin 0) (position Hcell Ynsub 0)
 "4HSiC" "R.n")
(sdegeo:create-rectangle
 (position (- Hcell) Ynsub 0) (position Hcell Ybottom 0)
 "4HSiC" "R.nPlus.substrate")

; Conformal idealized 45 nm passivation, leaving the hole open.
; Oxidation consumption and corner rounding are not specified in the paper.
(if (> HoleD 0.0)
 (sdegeo:create-polygon
 (list (position (- Hcell) (- Tox) 0)
       (position (+ (- Rhole) Tox) (- Tox) 0)
       (position (+ (- Rhole) Tox) (- EtchDepth Tox) 0)
       (position (- Rhole Tox) (- EtchDepth Tox) 0)
       (position (- Rhole Tox) (- Tox) 0)
       (position Hcell (- Tox) 0)
       (position Hcell 0 0)
       (position Rhole 0 0)
       (position Rhole EtchDepth 0)
       (position (- Rhole) EtchDepth 0)
       (position (- Rhole) 0 0)
       (position (- Hcell) 0 0))
 "Oxide" "R.SiO2.passivation")
 (sdegeo:create-rectangle (position (- Hcell) (- Tox) 0)
 (position Hcell 0 0) "Oxide" "R.SiO2.passivation"))

; Lateral p+ contacts approximate the continuous p+ sheet around a 3D
; circular hole. They are truncation contacts, not metal over the aperture.
; Keep the p+ truncation contact strictly inside p+. A contact ending
; exactly at the p/i corner also clamps the i-layer endpoint in SDevice.
; Split each lateral edge at 10%% and 90%% of the p+ thickness.
(sdegeo:insert-vertex (position (- Hcell) (* 0.10 Tp) 0))
(sdegeo:insert-vertex (position (- Hcell) (* 0.90 Tp) 0))
(sdegeo:insert-vertex (position Hcell (* 0.10 Tp) 0))
(sdegeo:insert-vertex (position Hcell (* 0.90 Tp) 0))
(sdegeo:define-contact-set "anode" 4 (color:rgb 1 0 0) "##")
(sdegeo:define-contact-set "cathode" 4 (color:rgb 0 0 1) "##")
(sdegeo:define-2d-contact
 (find-edge-id (position (- Hcell) (/ Tp 2.0) 0)) "anode")
(sdegeo:define-2d-contact
 (find-edge-id (position Hcell (/ Tp 2.0) 0)) "anode")
(sdegeo:define-2d-contact
 (find-edge-id (position 0 Ybottom 0)) "cathode")

; SiC dopant species, verified against the native datexcodes database.
; Region-local placement prevents background doping from being double added.
(sdedr:define-constant-profile "D.pPlus" "AluminumActiveConcentration" NAp)
(sdedr:define-constant-profile-region "P.pPlus.left" "D.pPlus" "R.pPlus.left")
(if (> HoleD 0.0) (sdedr:define-constant-profile-region "P.pPlus.right" "D.pPlus" "R.pPlus.right"))
(sdedr:define-constant-profile "D.i" "NitrogenActiveConcentration" NDi)
(sdedr:define-constant-profile-region "P.i" "D.i" "R.i")
(sdedr:define-constant-profile "D.n" "NitrogenActiveConcentration" NDn)
(sdedr:define-constant-profile-region "P.n" "D.n" "R.n")
(sdedr:define-constant-profile "D.nPlus" "NitrogenActiveConcentration" NDsub)
(sdedr:define-constant-profile-region "P.nPlus" "D.nPlus" "R.nPlus.substrate")

; Official-style global, region and interface refinement. No global
; nanometer mesh is applied to the truncated, heavily doped substrate.
(sdedr:define-refeval-window "W.global" "Rectangle"
 (position (- Hcell) (- Tox) 0) (position Hcell Ybottom 0))
(sdedr:define-refinement-size "Ref.global" 0.70 0.60 0 0.075 0.025 0)
(sdedr:define-refinement-function "Ref.global" "DopingConcentration" "MaxTransDiff" 2.0)
(sdedr:define-refinement-function "Ref.global" "MaxLenInt"
 "4HSiC" "Oxide" 0.015 1.8 "DoubleSide")
(sdedr:define-refinement-placement "Place.global" "Ref.global" "W.global")

(sdedr:define-refinement-size "Ref.pPlus" 0.25 0.050 0 0.020 0.008 0)
(sdedr:define-refinement-region "Place.pPlus.left" "Ref.pPlus" "R.pPlus.left")
(if (> HoleD 0.0) (sdedr:define-refinement-region "Place.pPlus.right" "Ref.pPlus" "R.pPlus.right"))
(sdedr:define-refinement-size "Ref.i" 0.30 0.100 0 0.020 0.010 0)
(sdedr:define-refinement-region "Place.i" "Ref.i" "R.i")
(sdedr:define-refinement-size "Ref.n" 0.35 0.120 0 0.030 0.020 0)
(sdedr:define-refinement-region "Place.n" "Ref.n" "R.n")
(sdedr:define-refinement-size "Ref.oxide" 0.30 0.020 0 0.015 0.010 0)
(sdedr:define-refinement-region "Place.oxide" "Ref.oxide" "R.SiO2.passivation")

; Resolve both ends of the recessed hole floor and the neighboring p/i edge.
(sdedr:define-refinement-size "Ref.corner" 0.080 0.020 0 0.010 0.005 0)
(sdedr:define-refeval-window "W.corner.left" "Rectangle"
 (position (- (- Rhole) 0.12) (- Tp 0.08) 0)
 (position (+ (- Rhole) 0.12) (+ EtchDepth 0.12) 0))
(sdedr:define-refeval-window "W.corner.right" "Rectangle"
 (position (- Rhole 0.12) (- Tp 0.08) 0)
 (position (+ Rhole 0.12) (+ EtchDepth 0.12) 0))
(sdedr:define-refinement-placement "Place.corner.left" "Ref.corner" "W.corner.left")
(sdedr:define-refinement-placement "Place.corner.right" "Ref.corner" "W.corner.right")

; Retain native editable geometry and boundary alongside the mesh.
(sde:save-model "n@node@_geo")
(sdeio:save-tdr-bnd (get-body-list) "n@node@_bnd.tdr")
(sde:build-mesh "n@node@_msh")
