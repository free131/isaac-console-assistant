"""Build an independent binary BMFont v3 from Noto Sans SC (OFL)."""
from pathlib import Path
import hashlib,json,struct,urllib.request,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'.cache/python'))
from PIL import Image,ImageFont,ImageDraw
from fontTools.ttLib import TTFont

MOD=ROOT/'mod/isaac_console_panel'
CACHE=ROOT/'.cache/mod-font'
CACHE.mkdir(parents=True,exist_ok=True)
BASE='https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/'
for name,url in [('NotoSansSC.ttf','NotoSansSC%5Bwght%5D.ttf'),('OFL.txt','OFL.txt')]:
    dest=CACHE/name
    if not dest.exists():
        with urllib.request.urlopen(BASE+url,timeout=120) as response: dest.write_bytes(response.read())

text=''.join(p.read_text('utf-8') for p in MOD.rglob('*.lua'))
glyphs=sorted(set(range(32,127))|{ord(c) for c in text if ord(c)>=160})
tt=TTFont(CACHE/'NotoSansSC.ttf');cmap=tt.getBestCmap()
missing=[chr(c) for c in glyphs if c not in cmap]
if missing: raise RuntimeError('字体缺字: '+''.join(missing))
font=ImageFont.truetype(str(CACHE/'NotoSansSC.ttf'),18)
if hasattr(font,'set_variation_by_name'): font.set_variation_by_name('Regular')
width=2048;cell=26;height=((len(glyphs)+(width//cell)-1)//(width//cell))*cell
height=2**(height-1).bit_length()
atlas=Image.new('RGBA',(width,height),(255,255,255,0));draw=ImageDraw.Draw(atlas)
records=[]
for i,code in enumerate(glyphs):
    ch=chr(code);x=(i%(width//cell))*cell+1;y=(i//(width//cell))*cell+1
    left,top,right,bottom=font.getbbox(ch)
    w,h=right-left,bottom-top
    draw.text((x-left,y-top),ch,font=font,fill=(255,255,255,255))
    records.append(struct.pack('<IHHHHhhhBB',code,x,y,w,h,left,top,round(font.getlength(ch)),0,15))
out=MOD/'resources/font';out.mkdir(parents=True,exist_ok=True)
atlas.save(out/'icp_panel.png')
def block(kind,data): return struct.pack('<BI',kind,len(data))+data
info=struct.pack('<hBBHBBBBBBBB',18,0,0,100,1,0,0,0,0,0,0,0)+b'ICP Panel\0'
common=struct.pack('<HHHHHBBBBB',26,21,width,height,1,0,0,4,4,4)
(out/'icp_panel.fnt').write_bytes(b'BMF\x03'+block(1,info)+block(2,common)+block(3,b'icp_panel.png\0')+block(4,b''.join(records)))
licenses=MOD/'licenses';licenses.mkdir(exist_ok=True)
(licenses/'NotoSansSC-OFL.txt').write_bytes((CACHE/'OFL.txt').read_bytes())
(out/'manifest.json').write_text(json.dumps({'source':BASE+'NotoSansSC%5Bwght%5D.ttf','source_sha256':hashlib.sha256((CACHE/'NotoSansSC.ttf').read_bytes()).hexdigest(),'font_size':18,'glyphs':glyphs,'atlas':[width,height]},ensure_ascii=False,indent=2),'utf-8')
gfx=MOD/'resources/gfx/icp';gfx.mkdir(parents=True,exist_ok=True)
Image.new('RGBA',(1,1),'white').save(gfx/'rect.png')
attrs='XPosition="0" YPosition="0" XScale="100" YScale="100" Delay="1" Visible="true" RedTint="255" GreenTint="255" BlueTint="255" AlphaTint="255" RedOffset="0" GreenOffset="0" BlueOffset="0" Rotation="0" Interpolated="false"'
(gfx/'rect.anm2').write_text(f'''<AnimatedActor><Info CreatedBy="ICP" Version="10" Fps="30"/><Content><Spritesheets><Spritesheet Path="rect.png" Id="0"/></Spritesheets><Layers><Layer Name="Rect" Id="0" SpritesheetId="0"/></Layers><Nulls/><Events/></Content><Animations DefaultAnimation="Idle"><Animation Name="Idle" FrameNum="1" Loop="true"><RootAnimation><Frame {attrs}/></RootAnimation><LayerAnimations><LayerAnimation LayerId="0" Visible="true"><Frame {attrs} XPivot="0" YPivot="0" XCrop="0" YCrop="0" Width="1" Height="1"/></LayerAnimation></LayerAnimations><NullAnimations/><Triggers/></Animation></Animations></AnimatedActor>''','utf-8')
print(json.dumps({'glyphs':len(glyphs),'atlas':[width,height]}))
