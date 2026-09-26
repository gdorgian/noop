import sys,re,html,json
src,dst,*kv=sys.argv[1:]
s=open(src).read()
m=re.search(r'data-props="([^"]*)"',s)
props=json.loads(html.unescape(m.group(1)))
for pair in kv:
    k,v=pair.split('=',1)
    props[k]['default']=json.loads(v)
s=s[:m.start(1)]+html.escape(json.dumps(props),quote=True)+s[m.end(1):]
open(dst,'w').write(s)
