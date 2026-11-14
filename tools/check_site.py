"""Read-only before/after checks for pre-existing portfolio pages."""
from pathlib import Path
import urllib.request,hashlib,json,sys,subprocess
urls=['https://theramlakhan.com/','https://theramlakhan.com/ghtrack/','https://theramlakhan.com/projects/bill-studio/','https://theramlakhan.com/games/','https://theramlakhan.com/cv/']
result={}
for url in urls:
    data=subprocess.check_output(['curl','-fsSL','--max-time','30',url])
    result[url]={'status':200,'sha256':hashlib.sha256(data).hexdigest()}
path=Path('.tools/site-baseline.json')
if sys.argv[1:] == ['before']:
    path.write_text(json.dumps(result,indent=2))
    print('Captured baseline:',len(result),'existing pages')
else:
    before=json.loads(path.read_text())
    for url,value in result.items():
        print(url, 'UNCHANGED' if value == before[url] else 'CHANGED', value['status'])
    if result!=before: sys.exit('Existing page content changed; review before declaring deployment verified.')
