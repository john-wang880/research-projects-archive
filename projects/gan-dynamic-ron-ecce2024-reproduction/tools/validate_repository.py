"""Portable source/integrity and scientific-evidence checks (no simulator claim)."""
from pathlib import Path
import argparse,csv,hashlib,json,re,subprocess,zipfile

ROOT=Path(__file__).resolve().parents[1]
FULL=ROOT/'outputs/full_reproduction'
MANIFEST=FULL/'manifest.json'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def sensitive(data):
    # Deliberately assembled to avoid matching the validator's own source.
    win=b'C:'+bytes([92])+b'Users'+bytes([92])
    return win.lower() in data.lower() or re.search(rb'(gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)',data)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--refresh',action='store_true');args=parser.parse_args()
    if args.refresh:
        listed=subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode().split('\0')
        paths=[ROOT/p for p in listed if p and ROOT/p!=MANIFEST]
        assert paths,'Stage the intended public files before refreshing the inventory.'
        MANIFEST.write_text(json.dumps({'scope':'Public source distribution; external vendor models/manuscript and large generated outputs are not distributed',
            'paths_relative_to':'repository root','files':[{'path':p.relative_to(ROOT).as_posix(),'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(paths)]},indent=2),encoding='utf-8')
    m=read(MANIFEST);models=[]
    for row in m['files']:
        p=ROOT/row['path'];assert p.is_file(),p
        assert sha(p)==row['sha256'],f'Inventory differs: {row["path"]}'
        assert p.suffix.lower() not in {'.lib','.raw','.mat','.fig'},f'External/large generated file included: {p}'
        assert p.name!='ECCE_Europe_2024_GaN_Dynamic_Ron_Fulltext.pdf'
        data=p.read_bytes();assert not sensitive(data),f'Private path or credential pattern: {p}'
        if p.suffix in {'.asc','.cir','.inc'}:
            for dependency in re.findall(r'\.include\s+([^\r\n]+)',data.decode('utf-8'),re.I):
                target=(p.parent/dependency.strip().strip('"')).resolve()
                external={'stn1nk60z.lib','DMG2302UK_official.lib','BAS21_LTspice_compat.lib','BAS21_official.lib'}
                if target.name not in external:
                    assert target.is_file(),f'Missing circuit include: {p.name}: {dependency}'
                    assert target.relative_to(ROOT).as_posix() in {x['path'] for x in m['files']},f'Unpublished circuit dependency: {target}'
        if p.suffix=='.slx':
            models.append(p)
            with zipfile.ZipFile(p) as z:
                assert z.testzip() is None
                assert 'simulink/blockdiagram.xml' in z.namelist()
                for member in z.namelist():assert not sensitive(z.read(member)),f'Private metadata: {p}:{member}'
    assert len(models)==11
    t=read(FULL/'simulink/thermal_metrics.json')
    assert abs(t['meanReduction_percent']-51.737126)<.02
    assert t['paperPrintedReduction_percent']==62
    scr=read(FULL/'scrc/scrc_crosscheck_metrics.json')
    assert scr['actualSPICEcases']==72 and scr['actualNativeCases']==72 and scr['passed']
    assert scr['maximumDUTcurrentDifference_A']<1e-10
    safe=read(FULL/'clamp/wide_safe_metrics.json');assert len(safe)==6 and all(x['passes_2percent_wide_voltage'] for x in safe)
    edges=read(FULL/'clamp/native_ASC_waveform_verification.json')
    assert len(edges)==3 and all(x['canonical_native_netlist_identical'] and x['measurement_window_pass'] for x in edges)
    assert all(not x['pointwise_transient_equivalence_claimed'] for x in edges)
    assert any(not x['initial_10mV_whole_trace_RMS_criterion_pass'] for x in edges)
    integration=read(FULL/'integration/integration_metrics.json');assert len(integration['cases'])==6
    assert all(abs(x['extractionError_Ohm'])<1e-9 for x in integration['cases'])
    public=read(ROOT/'docs/validated-run.json')
    assert len(public['LTspice_jobs'])==40 and all(x['exit_code']==0 for x in public['LTspice_jobs'])
    assert public['MATLAB']['complete'] and public['MATLAB']['model_count']==11
    assert all(x['passed'] for x in public['MATLAB']['stages'])
    saved=public['saved_model_execution']
    assert saved['models_executed']==11 and saved['all_reached_stop_time']
    assert len(saved['records'])==11
    for record in saved['records']:
        assert record['stop_event']=='ReachedStopTime'
        assert sha(ROOT/record['model'].replace('\\','/'))==record['slx_sha256']
    static=list(csv.DictReader((FULL/'ron_trapping/fig10_model_comparison.csv').open(encoding='utf-8-sig')))
    assert len({float(x['Tc_C']) for x in static})==9
    required=['README.md','LICENSE','THIRD_PARTY.md','tools/fetch_external.py','outputs/full_reproduction/audit/coverage_matrix.csv','outputs/reproduction/matlab/cauer_temperature.m','outputs/reproduction/ltspice/common.inc','outputs/reproduction/ltspice/conventional_gates.inc','outputs/reproduction/ltspice/proposed_gates.inc']
    assert all((ROOT/p).is_file() for p in required)
    print(f'PASS: {len(m["files"])} public files, 11 native model containers, required data, numeric evidence and explicit unresolved-edge limits.')
    print('Portable validation does not execute MATLAB or LTspice; see docs/validated-run.json for native execution evidence.')

if __name__=='__main__':main()
