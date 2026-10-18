"""Extract plotted vector paths, not unpublished measurement data.

The page 7 PDF uses vector line paths. Axis calibration comes directly from
grid lines; uncertainty is reported as half plotted stroke width. This is
a visual-reference resolution, not experimental uncertainty.
"""
from pathlib import Path
import csv
import json
import numpy as np
import pdfplumber
import sys

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
source = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'outputs/ECCE_Europe_2024_GaN_Dynamic_Ron_Fulltext.pdf'
page = pdfplumber.open(source).pages[6]

def sample_path(curve):
    pts = []
    current = None
    first = None
    for op in curve['path']:
        if op[0] == 'm':
            current = np.array(op[1]); first = current.copy(); pts.append(current)
        elif op[0] == 'l':
            current = np.array(op[1]); pts.append(current)
        elif op[0] == 'c':
            p0 = current.copy(); p1,p2,p3 = map(np.array,op[1:])
            for u in np.linspace(0,1,31)[1:]:
                pts.append((1-u)**3*p0+3*(1-u)**2*u*p1+3*(1-u)*u*u*p2+u**3*p3)
            current = p3
        elif op[0] == 'h':
            current = first.copy(); pts.append(current)
        else:
            raise ValueError(op[0])
    return np.array(pts)

def calibrated(curve_index, x0, xs, y0, ys):
    curve = page.curves[curve_index]
    pts = sample_path(curve)
    data = np.column_stack(((pts[:,0]-x0)/xs, (y0-pts[:,1])/ys))
    data = data[np.argsort(data[:,0],kind='stable')]
    # Different native points can share an x coordinate at switching edges.
    ux = np.unique(data[:,0])
    uy = np.array([np.mean(data[data[:,0]==x,1]) for x in ux])
    return np.column_stack((ux,uy)), {
        'pdf_curve_index': curve_index,
        'native_path_points': len(pts),
        'half_stroke_time_us': curve['linewidth']/2/xs,
        'half_stroke_y_units': curve['linewidth']/2/ys,
    }

specs = {
    'figure13_current': (11,12,110.03011292, (127.49166300125-110.03011292)/5,
                         546.0623084287499,(546.0623084287499-535.5310531612499)/10,'A'),
    'figure13_voltage': (16,17,110.03011292, (127.49166300125-110.03011292)/5,
                         622.3756772775,622.3756772775-610.9411772775,'V'),
    'figure14_current': (18,19,371.35247904838, (411.25205403972-371.35247904838)/10,
                         449.19133659626004,(449.19133659626004-436.41411191124)/10,'A'),
    'figure14_temperature': (23,24,371.35247904838, (411.25205403972-371.35247904838)/10,
                         533.52101979626,533.52101979626-523.07080402466,'K'),
}
meta={'source':str(source),'page':7,'method':'Native PDF plotted-vector paths calibrated to grid line coordinates',
      'warning':'Plot reconstruction only; unpublished raw experimental and simulation data are unavailable.',
      'families':{}}
for name,(a,b,x0,xs,y0,ys,unit) in specs.items():
    conv,ma=calibrated(a,x0,xs,y0,ys); prop,mb=calibrated(b,x0,xs,y0,ys)
    t=np.arange(max(conv[0,0],prop[0,0]),min(conv[-1,0],prop[-1,0])+1e-8,.01)
    vc=np.interp(t,conv[:,0],conv[:,1]); vp=np.interp(t,prop[:,0],prop[:,1])
    with (OUT/f'{name}.csv').open('w',newline='',encoding='utf-8') as f:
        w=csv.writer(f); w.writerow(['time_us',f'conventional_{unit}',f'proposed_{unit}'])
        w.writerows(zip(t,vc,vp))
    for label,data in [('conventional',conv),('proposed',prop)]:
        with (OUT/f'{name}_{label}_native.csv').open('w',newline='',encoding='utf-8') as f:
            w=csv.writer(f);w.writerow(['time_us',f'plotted_value_{unit}']);w.writerows(data)
    entry={'units':unit,'conventional':ma,'proposed':mb,'range_us':[float(t[0]),float(t[-1])]}
    if name=='figure14_temperature':
        tw=np.linspace(33.5,38.5,10001)
        cv=np.interp(tw,conv[:,0],conv[:,1]);pv=np.interp(tw,prop[:,0],prop[:,1])
        entry['mean_measurement_33p5_to_38p5_us']={
            'conventional_K':float(np.trapezoid(cv,tw)/5),
            'proposed_K':float(np.trapezoid(pv,tw)/5),
            'reduction_percent':float((1-np.trapezoid(pv,tw)/np.trapezoid(cv,tw))*100),
        }
        entry['at_38p5_us']={'conventional_K':float(cv[-1]),'proposed_K':float(pv[-1])}
    if name=='figure13_current':
        window=(t>=34.0)&(t<=39.5)
        entry['max_plotted_current_A']={'conventional':float(vc.max()),'proposed':float(vp.max())}
        entry['plateau_34_to_39p5_us_A']={'conventional_mean':float(vc[window].mean()),
                                                  'proposed_mean':float(vp[window].mean())}
    meta['families'][name]=entry
(OUT/'plot_extraction_metadata.json').write_text(json.dumps(meta,indent=2,ensure_ascii=True),encoding='utf-8')
print(json.dumps(meta,ensure_ascii=True,indent=2))

