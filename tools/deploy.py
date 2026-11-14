"""Publish only public/paytrack using the owner's existing gh-track portfolio pipeline."""
from pathlib import Path
import subprocess, shutil, sys
ROOT = Path(__file__).resolve().parents[1]
SITE = 'ramlakhanmadheshiya/ramlakhanmadheshiya.github.io'
DEST = 'public/paytrack'
WORK = ROOT / '.tools' / 'portfolio'
def run(*args, cwd=ROOT):
    return subprocess.check_output(args,cwd=cwd,text=True).strip()
source = ROOT / 'build' / 'web'
required = ['index.html','index.js','index.pck','index.wasm']
if not all((source / name).is_file() for name in required):
    sys.exit('Export Web first; missing required runtime files.')
if not WORK.exists():
    run('gh','repo','clone',SITE,str(WORK),'--','--depth','1')
if run('git','status','--porcelain',cwd=WORK):
    sys.exit('Portfolio inspection copy has local changes. Review them before deployment.')
run('git','pull','--ff-only',cwd=WORK)
if not (WORK / 'public' / 'ghtrack').is_dir() or not (WORK / '.github/workflows/deploy.yml').is_file():
    sys.exit('Portfolio layout differs from inspected gh-track pipeline. Stop for review.')
target = WORK / DEST
if target.exists(): shutil.rmtree(target)
target.mkdir(parents=True)
for path in source.iterdir():
    if path.is_file() and path.suffix in ['.html','.js','.wasm','.pck','.png','.svg']:
        shutil.copy2(path,target / path.name)
run('git','add','--',DEST,cwd=WORK)
changed = run('git','diff','--cached','--name-only',cwd=WORK).splitlines()
if not changed: sys.exit('No changed PayTrack runtime files.')
if not all(name.startswith(DEST+'/') for name in changed):
    sys.exit('Refusing deployment: changes outside public/paytrack.')
print('Reviewed path-scoped files:\n'+'\n'.join(changed),flush=True)
run('git','commit','-m','Publish PayTrack fictional Web demo',cwd=WORK)
run('git','push','origin','HEAD:main',cwd=WORK)
print('Published runtime commit:',run('git','rev-parse','HEAD',cwd=WORK))
print('Watch the existing Pages workflow before verifying https://theramlakhan.com/paytrack/')
