"""Package the shared Research Engine method for private ChatGPT skill acceptance."""
import pathlib, sys, zipfile
root=pathlib.Path(__file__).resolve().parents[1]
out=pathlib.Path(sys.argv[1]);out.parent.mkdir(parents=True,exist_ok=True)
entry='''---
name: research-engine
description: Cited research with Perplexity and original sources. Use when investigating questions, conflicting claims, or current facts, or setting up Perplexity research.
---

# Research Engine

For connection setup or authentication failures, read references/setup.md.
For research, read references/methodology.md and references/connected-runtime.md and follow them.
'''
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
 z.writestr('research-engine/SKILL.md',entry)
 for name in ['methodology.md','connected-runtime.md']:
  text=(root/'references'/name).read_text().replace('use the setup skill','read setup.md')
  z.writestr('research-engine/references/'+name,text)
 setup=(root/'skills/setup/SKILL.md').read_text().split('---',2)[2].replace('For the existing local Claude runtime, follow the README\'s local installation and key setup procedure; do not impose that shell setup on a connected ChatGPT client.','This package uses connected tools; local shell installation is not required.')
 z.writestr('research-engine/references/setup.md',setup)
print(out)
