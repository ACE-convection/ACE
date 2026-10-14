#!/usr/bin/env python3
from pathlib import Path
import argparse,os,subprocess,json
from oop_regression import ROOT,INPUT_HASH,TABLE_HASH,compare_file,sha
parser=argparse.ArgumentParser(description='Compare OOP initialization contracts and 600 s dry/native state streams in fresh processes.')
parser.add_argument('work',type=Path,help='Existing candidate workspace with production_plain executable')
parser.add_argument('--resume',action='store_true',help='Resume completed gates after verifying executable and artifact hashes')
parser.add_argument('--baseline',type=Path,default=ROOT/'migration_work/fortran_v020_oop_stage0')
parser.add_argument('--lookup-directory',type=Path,default=Path('/scratch/peter50504/ACE_FORTRAN/input_data'))
args=parser.parse_args()
root=ROOT; work=args.work.resolve(); dest=work/'initialization_contract';dest.mkdir(exist_ok=args.resume)
baseline=args.baseline.resolve()/'builds/production_plain/ace_model.exe'
candidate=work/'builds/production_plain/ace_model.exe'
lookup=args.lookup_directory.resolve()
env=os.environ.copy();env.update(OMP_NUM_THREADS='32',OMP_THREAD_LIMIT='32',OMP_DYNAMIC='FALSE',OMP_STACKSIZE='64M')
input_file=root/'data/input/manaus1342_khn26.nc'
assert sha(input_file)==INPUT_HASH
assert sha(lookup/'p3_lookupTable_1.dat-v6.4-2momI')==TABLE_HASH
report={'input_sha256':INPUT_HASH,'lookup_sha256':TABLE_HASH,'passed':False,'commands':[],'checks':{},'executable_sha256':{'baseline':sha(baseline),'candidate':sha(candidate)},'scope':'Supplemental fresh-process initialization/error/600 s dry-native gates; frozen baseline workspace is read-only.'}
runner_hash=sha(Path(__file__))
(dest/('runner_'+runner_hash+'.py')).write_bytes(Path(__file__).read_bytes())
report['execution_runners']=[runner_hash]
report['runner_sha256']=runner_hash
# Legacy only initializes; preserve the original relative paths via symlink in each isolated cwd.
cases=[('default_shared',[],True),('legacy',['--legacy-input'],True),('invalid_physics',['--physics','bad'],False),('missing_option',['--input'],False),('invalid_dt',['--dt','0'],False),('missing_input',['--input',str(dest/'missing.nc')],False),('unused_lookup',['--p3-lookup-directory',str(dest/'missing_tables')],True),('none_600s',['--physics','none','--dt','4','--steps','150'],True),('native_600s',['--physics','native','--dt','4','--steps','150'],True)]
if args.resume:
    previous=json.loads((dest/'results.json').read_text())
    assert previous['executable_sha256']==report['executable_sha256']
    report['commands']=previous['commands']
    report['checks']=previous['checks']
    report['execution_runners']=list(dict.fromkeys(previous.get('execution_runners',[])+[runner_hash]))
for name,options,success in cases:
    if name in report['checks']:
        check=report['checks'][name]
        if success:
            filename='states.bin' if name.endswith('600s') else 'initialization.bin'
            for variant in ('baseline','candidate'):
                assert sha(dest/(name+'_'+variant)/filename)==check[variant+'_sha256']
        print('Verified completed gate',name,flush=True)
        continue
    dirs={}; logs={}; codes={}
    for variant,exe in [('baseline',baseline),('candidate',candidate)]:
        cwd=dest/(name+'_'+variant);cwd.mkdir();(cwd/'input_data').symlink_to(lookup,target_is_directory=True)
        cmd=[str(exe),'--input',str(input_file),'--p3-lookup-directory',str(lookup),*options]
        if success:
            cmd += ['--state-output',str(cwd/'states.bin')] if name.endswith('600s') else ['--validate-input',str(cwd/'initialization.bin')]
        print('Supplemental',name,variant,flush=True)
        with (cwd/'run.log').open('w') as log:
            code=subprocess.run(cmd,cwd=cwd,env=env,stdout=log,stderr=subprocess.STDOUT).returncode
        report['commands'].append({'argv':cmd,'cwd':str(cwd),'exit_code':code})
        dirs[variant]=cwd; codes[variant]=code;logs[variant]=(cwd/'run.log').read_text()
    assert (codes['baseline']==0)==success and (codes['candidate']==0)==success,(name,codes)
    if success:
        filename='states.bin' if name.endswith('600s') else 'initialization.bin'
        check=compare_file(dirs['baseline']/filename,dirs['candidate']/filename)
        assert check['bitwise_identical'],name
    else:
        # Compare user-visible errors; backtrace addresses/line numbers move with the extraction.
        messages={k:[line for line in v.splitlines() if line.startswith('ERROR STOP') or line.strip().startswith('ACE input:')] for k,v in logs.items()}
        assert messages['baseline'] and messages['baseline']==messages['candidate'],(name,messages)
        check={'matched_failure':True,'messages':messages['baseline'],'exit_codes':codes}
    report['checks'][name]=check
    (dest/'results.json').write_text(json.dumps(report,indent=2)+'\n')
report['passed']=True
# The process snapshots its runner before launch so edits during execution cannot obscure provenance.

(dest/'results.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS supplemental gates',flush=True)
