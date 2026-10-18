from pathlib import Path
import re,json
out=Path(__file__).resolve().parent

def create(label,deck):
 src=(out/deck).read_text(encoding='ascii');source_values={n:'PWL('+next(l for l in src.splitlines() if l.startswith(n+' ')).split('PWL(',1)[1] for n in ('Vdut','Vdrive_block','Vdrive_btb')};a=['Version 4','SHEET 1 1880 1460'];
 a+=['TEXT 32 16 Left 3 ;Figure 5: editable physical clamp schematic',f'TEXT 32 56 Left 2 ;{label}: official representative parts; not author BOM; matching {deck}', 'TEXT 32 96 Left 2 ;Gate timing must prevent the BTB short from overlapping negative DUT voltage.']
 def flag(x,y,name):a.append(f'FLAG {x} {y} {name}')
 def wire(x1,y1,x2,y2):a.append(f'WIRE {x2} {y2} {x1} {y1}')
 def symbol(kind,x,y,orientation,name,value,prefix=None):
  a.append(f'SYMBOL {kind} {x} {y} {orientation}')
  if kind=='voltage':a.append('WINDOW 3 -40 136 Left 1')
  if kind=='nmos' and orientation=='R0':
   a.append('WINDOW 0 72 16 Left 2');a.append('WINDOW 3 '+('72 -40' if name=='blocking' else '-240 112')+' Left 1')
  if kind=='nmos' and orientation=='R180':
   a.append('WINDOW 0 64 -32 Left 2');a.append('WINDOW 3 64 -8 Left 1')
  if kind=='diode' and orientation=='R180':
   a.append('WINDOW 0 32 20 Left 1');a.append('WINDOW 3 32 80 Left 1')
  native_prefix=prefix or {'voltage':'V','res':'R','cap':'C','diode':'D','nmos':'X'}[kind]
  a.extend([f'SYMATTR InstName {native_prefix+name}',f'SYMATTR Value {value}'])
  if prefix:a.append(f'SYMATTR Prefix {prefix}')
 # The physical blocking channel is from DUT input (D) to measurement output (S).
 symbol('voltage',128,256,'R0','dut',source_values['Vdut']);flag(128,272,'input');flag(128,352,'0')
 symbol('nmos',384,256,'R0','blocking','STN1NK60Z','X');flag(432,256,'input');flag(384,336,'gate_block');flag(432,352,'out')
 wire(432,352,1664,352)
 # Common-source BTB pair with opposite body-diode directions.
 symbol('nmos',848,416,'R0','btb_top','DMG2302UK','X');wire(896,352,896,416);flag(848,496,'gate_top')
 symbol('nmos',944,608,'R180','btb_bot','DMG2302UK','X');flag(896,512,'middle');flag(944,528,'gate_bot');flag(896,608,'0')
 # TVS anti-series cathodes, equivalent to the CIR.
 symbol('diode',1008,416,'R0','tvsp','DTVS');wire(1024,352,1024,416)
 symbol('diode',1040,544,'R180','tvsm','DTVS');flag(1024,544,'0')
 symbol('res',1120,432,'R0','probe','1Meg');wire(1136,352,1136,448);flag(1136,528,'0')
 symbol('cap',1320,432,'R0','probe','{CPROBE}');wire(1336,352,1336,432);flag(1336,496,'0')
 symbol('cap',1536,432,'R0','stray','5p');wire(1552,352,1552,432);flag(1552,496,'0')
 a.append('TEXT 848 648 Left 2 ;Back-to-back shunt outside the measuring window')
 a.append('TEXT 32 456 Left 2 ;Blocking gate referenced to measurement output')
 symbol('voltage',128,512,'R0','drive_block',source_values['Vdrive_block']);flag(128,528,'drv_block');flag(128,608,'out')
 symbol('res',368,512,'R0','gate_block','{RDRV}');flag(384,528,'drv_block');flag(384,608,'gate_block')
 a.append('TEXT 32 736 Left 2 ;Common-source gate drive: strong OFF clamp / explicit interlock')
 symbol('voltage',128,800,'R0','drive_btb',source_values['Vdrive_btb']);flag(128,816,'drv_btb');flag(128,896,'middle')
 rtop=re.search(r'Rgate_top drv_btb gate_top (.+)',src).group(1).strip();rbot=re.search(r'Rgate_bot drv_btb gate_bot (.+)',src).group(1).strip()
 symbol('res',368,800,'R0','gate_top',rtop);flag(384,816,'drv_btb');flag(384,896,'gate_top')
 symbol('res',624,800,'R0','gate_bot',rbot);flag(640,816,'drv_btb');flag(640,896,'gate_bot')
 symbol('res',1120,768,'R0','mid_leak','100Meg');flag(1136,784,'middle');flag(1136,864,'0')
 # Keep all simulation/control values directly editable in native directives.
 y=1000
 for line in src.splitlines():
  if line.lower().startswith(('.include','.param','.model','.tran','.options','.save','.meas')):
   a.append(f'TEXT 32 {y} Left 1 !{line}');y+=24
 for vsource,post in [('Vdut','dut'),('Vdrive_block','block'),('Vdrive_btb','btb')]:
  line=next(l for l in src.splitlines() if l.startswith(vsource+' '));items=re.search(r'PWL\((.+)\)',line).group(1).split();pairs=[]
  for n in range(0,len(items),2):pairs.append(items[n]+' '+items[n+1])
  # LTspice PWL data files do not substitute .param braces. Expand those explicitly.
  params=dict(re.findall(r'(VBUS|VON)=([^\s]+)',src))
  s='\n'.join(pairs)+'\n'
  s=re.sub(r'(\d+(?:\.\d+)?)u\b',lambda m:'%.12g'%(float(m[1])*1e-6),s)
  for k,v in params.items():s=s.replace('{'+k+'}',v)
  (out/(label+'_'+post+'.pwl')).write_text(s,encoding='ascii')
 head=a[:2];wire_lines=[l for l in a[2:] if l.startswith('WIRE ')];flag_lines=[l for l in a[2:] if l.startswith('FLAG ')];text_lines=[l for l in a[2:] if l.startswith('TEXT ')];symbol_lines=[l for l in a[2:] if not l.startswith(('WIRE ','FLAG ','TEXT '))]
 a=head+wire_lines+flag_lines+symbol_lines+text_lines
 a=[l.replace('SYMBOL nmos 384','SYMBOL ClampBlockingSTN 384').replace('SYMBOL nmos 848','SYMBOL ClampBTBDMG 848').replace('SYMBOL nmos 944','SYMBOL ClampBTBDMG 944') for l in a]
 path=out/(label+'.asc');path.write_text('\n'.join(a)+'\n',encoding='ascii');return {'native_schematic':path.name,'equivalent_verified_deck':deck,'run_deck':str(path)}
rows=[create('GaN_Fig5_Clamp_Safe400_Pos5','wide_safe_400V_pos5V.cir'),create('GaN_Fig5_Clamp_Safe400_Neg5','wide_safe_400V_neg5V.cir'),create('GaN_Fig5_Clamp_Default','improved_positive.cir')]
(out/'native_schematic_manifest.json').write_text(json.dumps(rows,indent=2),encoding='utf-8');(out/'asc_run_manifest.json').write_text(json.dumps({'decks':[r['run_deck'] for r in rows]},indent=2),encoding='utf-8')
print('3 native schematic ASC files ready')
