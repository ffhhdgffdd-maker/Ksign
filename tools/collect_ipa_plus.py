import json, pathlib, tempfile, subprocess, zipfile, plistlib, re, datetime

catalog=json.load(open('sources/ipa-plus-catalog.json'))['apps']
checkpoint=pathlib.Path('sources/ipa-plus-verified.json')
previous=json.loads(checkpoint.read_text()) if checkpoint.exists() else []
results={x['download']:x for x in previous if x.get('verified')}
for i, original in enumerate(catalog,1):
    a=dict(original)
    if a['download'] in results:
        print(f'{i}/{len(catalog)} cached',flush=True);continue
    try:
        with tempfile.TemporaryDirectory() as d:
            file=pathlib.Path(d)/'app.ipa'
            subprocess.run(['curl','--fail','--location','--silent','--show-error','--max-time','120','--max-filesize','1500000000',a['download'],'-o',str(file)],check=True,capture_output=True)
            with zipfile.ZipFile(file) as z:
                entries=[x for x in z.infolist() if re.fullmatch(r'Payload/[^/]+\.app/Info\.plist',x.filename)]
                if len(entries)!=1 or entries[0].file_size>2*1024*1024:raise ValueError('Invalid main Info.plist')
                info=plistlib.loads(z.read(entries[0]))
            if info.get('CFBundleIdentifier')!=a['bundle']:raise ValueError('Bundle identifier differs from catalog')
            a.update(bundleIdentifier=info['CFBundleIdentifier'],version=str(info.get('CFBundleShortVersionString',info.get('CFBundleVersion',''))),buildVersion=str(info.get('CFBundleVersion','')),minOSVersion=info.get('MinimumOSVersion'),sizeBytes=file.stat().st_size,date=datetime.datetime.now(datetime.timezone.utc).isoformat(),verified=True)
            if not a['version']:raise ValueError('Missing app version')
    except subprocess.CalledProcessError as e:
        a.update(verified=False,error=e.stderr.decode('utf-8',errors='replace')[:250])
    except Exception as e:a.update(verified=False,error=str(e)[:250])
    results[a['download']]=a
    checkpoint.write_text(json.dumps(list(results.values()),ensure_ascii=False,indent=2))
    print(f"{i}/{len(catalog)} {a['name']}: verified={a['verified']}",flush=True)

# Only verified, matching bundles are exposed as installable source entries.
grouped={}
for a in results.values():
    if not a.get('verified'):continue
    version=dict(version=a['version'],buildVersion=a['buildVersion'] or '1',date=a['date'],downloadURL=a['download'],size=a['sizeBytes'])
    if a.get('minOSVersion'):version['minOSVersion']=a['minOSVersion']
    app=grouped.setdefault(a['bundleIdentifier'],dict(name=a['name'],bundleIdentifier=a['bundleIdentifier'],developerName='IPA Plus',iconURL=a['icon'],localizedDescription='نسخة مقدمة من IPA Plus. الباندل والإصدار مقروءان من ملف IPA.',versions=[]))
    app['versions'].append(version)
source=dict(name='WolFox — IPA Plus',identifier='com.wolfox.source.ipaplus',website='https://ipa-plus.com/public/app-gps-plus/',tintColor='1677FF',apps=list(grouped.values()))
pathlib.Path('sources/ipa-plus.json').write_text(json.dumps(source,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'catalog':len(catalog),'verified':len(source['apps']),'failed':sum(not a.get('verified') for a in results.values())}),flush=True)
