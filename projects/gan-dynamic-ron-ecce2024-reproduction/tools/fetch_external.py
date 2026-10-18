"""Obtain requested third-party dependencies from their official sources.

No downloaded vendor file or manuscript is covered by this project's MIT
license. Downloads are ignored by Git. A local research cache is optional.
"""
from pathlib import Path
import argparse,hashlib,io,urllib.request,zipfile

ROOT=Path(__file__).resolve().parents[1]
CLAMP=ROOT/'outputs/full_reproduction/clamp'
ITEMS={
 'STN1NK60Z':('https://www.st.com/resource/en/spice_model/stn1nk60z_spice.zip','ae3fbcb8dc17fa64dae525ef494b0c55d491f6aa2e9abfa3bbbf28d4f2078bc9','outputs/full_reproduction/clamp/sources/STN1NK60Z_spice.zip'),
 'DMG2302UK':('https://www.diodes.com/spice/download/1786/DMG2302UK.spice.txt','535c3dffa46d186a712eaf9a7d6b322dd692cdfc6d0d8c73ffcee92d503c9115','outputs/full_reproduction/clamp/models/DMG2302UK_official.lib'),
 'BAS21':('https://www.diodes.com/spice/download/1510/BAS21.spice.txt','2f88c024fef08446fffccaa7b9f5d9bebfe85666748cdbc7b9c78d0001bed7c7','outputs/full_reproduction/clamp/models/BAS21_official.lib'),
 'paper':('https://publikationen.bibliothek.kit.edu/1000176527/155655990','0df6d7ddf4b4bbde241b4690f0f73ed644e232a0214c3041e4f1ca166e694e3c','outputs/ECCE_Europe_2024_GaN_Dynamic_Ron_Fulltext.pdf')}

def obtain(name,cache):
    url,expected,relative=ITEMS[name];target=ROOT/relative
    if cache:
        data=(cache/relative).read_bytes()
    elif target.is_file() and hashlib.sha256(target.read_bytes()).hexdigest()==expected:
        data=target.read_bytes()
    else:
        req=urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'})
        try:
            with urllib.request.urlopen(req,timeout=60) as response:data=response.read()
        except Exception as error:
            raise SystemExit(f'Could not retrieve {name}: {error}\nDownload manually from {url}\nSave to {target} and rerun; no alternate model will be substituted.')
    actual=hashlib.sha256(data).hexdigest()
    if actual!=expected:raise SystemExit(f'{name}: source SHA256 changed. Expected {expected}, got {actual}. Review the source before using it.')
    target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
    print(f'Verified external source: {name}')
    return data

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--models',action='store_true');parser.add_argument('--paper',action='store_true')
    parser.add_argument('--local-cache',type=Path,help='Optional previous research workspace containing the same outputs/ layout')
    args=parser.parse_args()
    if not(args.models or args.paper):parser.error('Choose --models and/or --paper')
    if args.models:
        data=obtain('STN1NK60Z',args.local_cache)
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            members=[n for n in z.namelist() if Path(n).name.lower()=='stn1nk60z.lib']
            if len(members)!=1:raise SystemExit('Unexpected ST archive members')
            model=z.read(members[0])
        assert hashlib.sha256(model).hexdigest()=='5e20623ac9afc71fa30918733a58770cb7ecd2778317c54a7f40b9ead643185a'
        (CLAMP/'models').mkdir(exist_ok=True);(CLAMP/'models/stn1nk60z.lib').write_bytes(model)
        obtain('DMG2302UK',args.local_cache);bas=obtain('BAS21',args.local_cache)
        text=bas.decode('utf-8-sig');lines=text.splitlines(keepends=True)
        fixed=''.join('* '+line if line.strip()=='Switching Diode' else line for line in lines)
        (CLAMP/'models/BAS21_LTspice_compat.lib').write_bytes(fixed.encode('utf-8'))
    if args.paper:obtain('paper',args.local_cache)
    print('Third-party files retain their owners\' terms. They are not MIT-licensed and are ignored by Git.')

if __name__=='__main__':main()
