"""构建离线目录。只读游戏枚举与本机名称；不执行 Lua，不写游戏目录。"""
import argparse
import hashlib
import json
import re
import urllib.request
from pathlib import Path
from collections import Counter

ROOT = Path(__file__).resolve().parents[1]
REV = '7d59952d4e5718ac80ebf9a60b4f7c5611557952'
VERSION = 'Repentance v1.7.9b.J835'
parser = argparse.ArgumentParser()
parser.add_argument('--game', default='E:/The.Binding.of.Isaac.and.The.Binding.of.Isaac.Rebirth.Build.10102354')
args = parser.parse_args()
game = Path(args.game)
enums_path = game / 'resources/scripts/enums.lua'
enums_bytes = enums_path.read_bytes()
enums = enums_bytes.decode('utf-8-sig')

def table(name):
    block = re.search(r'^' + re.escape(name) + r'\s*=\s*\{(.*?)^\}', enums, re.M | re.S)
    if not block:
        raise ValueError('缺少本机枚举：' + name)
    return {key: int(value.replace(' ', '')) for key, value in re.findall(r'^\s*([A-Z][A-Z0-9_]*)\s*=\s*(-?\s*\d+)\s*[,\n]', block[1], re.M)}

cache = ROOT / '.cache/sources'
cache.mkdir(parents=True, exist_ok=True)
def remote(name):
    file = cache / name
    if not file.exists():
        url = f'https://raw.githubusercontent.com/roiiiu/isaac-cheat-sheet/{REV}/{name}'
        with urllib.request.urlopen(url, timeout=60) as response:
            file.write_bytes(response.read())
    return file.read_text(encoding='utf-8-sig')

lookup = {}
for name, kind in [('data.json', 'c'), ('data_trinkets.json', 't'), ('data_card.json', 'k')]:
    records = json.loads(remote(name))
    for record in records:
        lookup[(kind, int(record['id']))] = record
license_text = remote('LICENSE')
(ROOT / 'licenses').mkdir(exist_ok=True)
(ROOT / 'licenses/isaac-cheat-sheet-MIT.txt').write_text(license_text, encoding='utf-8')

# 名称增强：仅取本机的名称字符串，不复制 Lua 代码或整段效果说明。
name_file = game / 'mods/abrep_external_item_descriptions/descriptions/names/zh_cn.lua'
local_names = {}
if name_file.exists():
    text = name_file.read_text(encoding='utf-8-sig')
    for prefix, id_, name, english in re.findall(r'\[(C_ID|T_ID|Card_ID|Pill_ID)\s*\.\.\s*(\d+)\]\s*=\s*"([^"\r\n]*)",?\s*(?:--\s*([^\r\n]*))?', text):
        kind = {'C_ID':'c', 'T_ID':'t', 'Card_ID':'k', 'Pill_ID':'p'}[prefix]
        local_names[(kind, int(id_))] = (name, english.strip())

entries = []
entry_by_key = {}
def add(key, category, name, english='', id_='', kind='literal', command='', description='', **extra):
    if key in entry_by_key:
        old = entry_by_key[key]
        old['aliases'] = list(dict.fromkeys(old.get('aliases', []) + [name, english, extra.get('symbol', '')]))
        return
    entry = dict(key=key, category=category, name=name, english=english, id=str(id_), kind=kind, command=command,
                        description=description, source=extra.pop('source', 'local-enums'), version=VERSION, **extra)
    entries.append(entry)
    entry_by_key[key] = entry

aliases = {
    ('c',118): ['硫磺火','硫磺'], ('c',395): ['妈刀科技','科技X','科技十'],
    ('c',515): ['幸运礼物','神秘礼物','礼物'], ('c',628): ['死亡证明','死证'],
    ('c',105): ['D6','六面骰'], ('c',114): ['妈刀','妈妈刀'], ('c',149): ['吐根'],
    ('c',182): ['圣心'], ('c',331): ['神性'], ('c',678): ['剖腹产'],
}
categories = {'c':'collectibles','t':'trinkets','k':'cards','p':'pills'}
for enum, kind, prefix in [('CollectibleType','c','COLLECTIBLE_'),('TrinketType','t','TRINKET_'),('Card','k','CARD_'),('PillEffect','p','PILLEFFECT_')]:
    values = table(enum)
    seen = set()
    for symbol, id_ in values.items():
        valid_prefix = symbol.startswith(prefix) or (kind == 'k' and symbol.startswith('RUNE_'))
        if not valid_prefix or id_ < (0 if kind == 'p' else 1) or id_ in seen:
            continue
        seen.add(id_)
        record = lookup.get((kind, id_), {})
        local_name, local_en = local_names.get((kind, id_), ('',''))
        english = record.get('titleEn') or local_en or symbol.removeprefix(prefix).replace('_',' ').title()
        name = record.get('title') or local_name or english
        desc = record.get('effect') or {'c':'收藏品，可获取、移除或生成底座。','t':'饰品，可获取、移除或生成掉落物。','k':'卡牌、符文或魂石，可获取或生成掉落物。','p':'按效果 ID 获取胶囊；生成地面胶囊使用的是颜色 ID，不等同于效果 ID。'}[kind]
        add(f'{kind}:{id_}', categories[kind], name, english, id_, 'item', description=desc,
            prefix=kind, aliases=aliases.get((kind,id_), []), symbol=symbol,
            source='cheat-sheet+local-enums' if record else 'local-names+local-enums',
            quality=str(record.get('quality') or ''), charge=str(record.get('charge') or ''))

players = ['以撒','抹大拉','该隐','犹大','小蓝人','夏娃','参孙','阿撒泻勒','拉撒路','伊甸','游魂','复活的拉撒路','黑犹大','莉莉丝','店主','亚玻伦','遗骸','遗骸之魂','伯大尼','雅各','以扫','里以撒','里抹大拉','里该隐','里犹大','里小蓝人','里夏娃','里参孙','里阿撒泻勒','里拉撒路','里伊甸','里游魂','里莉莉丝','里店主','里亚玻伦','里遗骸','里伯大尼','里雅各','里拉撒路复活形态','里雅各灵魂形态','里遗骸之魂']
for symbol, id_ in table('PlayerType').items():
    if symbol.startswith('PLAYER_') and 0 <= id_ <= 40:
        add(f'player:{id_}', 'players', players[id_], symbol[7:].replace('_',' ').title(), id_, command=f'restart {id_}', description='以此角色重新开始一局。当前对局将结束；部分 ID 是角色的内部形态。', symbol=symbol)

challenges = ['无挑战','漆黑一片','格调高雅','头部创伤','黑暗降临','坦克','太阳系','自杀之王','好奇害死猫','拆迁办','诅咒！','玻璃大炮','当生活给你柠檬','豆子！','尽在卡牌中','慢吞吞','电脑高手','吃豆人','宿主','顾家男人','纯粹主义者','超超超超超超大','速度！','蓝色炸弹人','付费游玩','心动过速','我是领主','脑子！','彩虹日','俄南连击','守护者','本末倒置','愚人节','宝可萌','终极困难','乒乓','大便之王','血腥玛丽','以火施洗','以撒的觉醒','眼花缭乱','异食癖','烫手山芋','卡牌大满贯','赤色救赎','删除这个']
for symbol,id_ in table('Challenge').items():
    if symbol.startswith('CHALLENGE_') and 0 <= id_ <= 45:
        add(f'challenge:{id_}', 'challenges', challenges[id_], symbol[10:].replace('_',' ').title(), id_, command=f'challenge {id_}', description='以指定挑战重新开局，将结束当前对局。0 表示无挑战。', symbol=symbol)

# 只列存在的楼层组合；不把 LevelStage 与 StageType 做笛卡尔积。
stages = []
for start, base, alt, third, down, down_alt in [
    (1,'地下室','地窖','燃烧地下室','下水道','污水池'),
    (3,'洞穴','墓穴','水淹洞穴','矿洞','灰坑'),
    (5,'深牢','坟场','阴湿深牢','陵墓','炼狱')]:
    for offset in range(2):
        for suffix,label in [('',base),('a',alt),('b',third),('c',down),('d',down_alt)]:
            stages.append((str(start+offset)+suffix,label+(' I' if offset==0 else ' II')))
for n in (7,8):
    for suffix,label in [('', '子宫'),('a','血宫'),('b','结痂子宫')]:
        stages.append((str(n)+suffix,label+(' I' if n==7 else ' II')))
stages += [('9','蓝子宫'),('10','阴间'),('10a','教堂'),('11','暗室'),('11a','玩具箱'),('12','虚空'),('13','家')]
for code,name in stages:
    add(f'stage:{code}', 'stages', name, 'Stage '+code, code, command='stage '+code, description='传送并生成目标楼层。表中为普通模式编号；贪婪模式使用自己的楼层顺序。', aliases=['传送','楼层'])

entity_cn = {
    'ENTITY_BOMB':'炸弹实体','ENTITY_PICKUP':'掉落物','ENTITY_SLOT':'老虎机与乞丐',
    'ENTITY_GAPER':'张嘴怪','ENTITY_GUSHER':'喷血怪','ENTITY_HORF':'吐血头','ENTITY_FLY':'苍蝇','ENTITY_POOTER':'吐弹苍蝇',
    'ENTITY_CLOTTY':'血团怪','ENTITY_MULLIGAN':'孵化人','ENTITY_SHOPKEEPER':'店主尸体','ENTITY_ATTACKFLY':'攻击苍蝇',
    'ENTITY_LARRYJR':'小长虫','ENTITY_MONSTRO':'萌死戳','ENTITY_MAGGOT':'蛆虫','ENTITY_HIVE':'蜂巢',
    'ENTITY_CHARGER':'冲锋蛆','ENTITY_GLOBIN':'血红怪','ENTITY_BOOMFLY':'爆炸苍蝇','ENTITY_MAW':'大嘴怪',
    'ENTITY_HOST':'宿主','ENTITY_CHUB':'胖蛆','ENTITY_BOIL':'脓包','ENTITY_SPITTY':'吐弹脑','ENTITY_BRAIN':'脑',
    'ENTITY_FIREPLACE':'火堆','ENTITY_BABY':'婴儿','ENTITY_VIS':'内脏','ENTITY_GUTS':'肠子','ENTITY_KNIGHT':'骑士',
    'ENTITY_STONEHEAD':'石像头','ENTITY_MONSTRO2':'萌死戳二世','ENTITY_POKY':'刺石块','ENTITY_MOM':'妈妈',
    'ENTITY_SLOTH':'懒惰','ENTITY_LUST':'色欲','ENTITY_WRATH':'暴怒','ENTITY_GLUTTONY':'暴食',
    'ENTITY_GREED':'贪婪','ENTITY_ENVY':'嫉妒','ENTITY_PRIDE':'傲慢','ENTITY_LEECH':'水蛭','ENTITY_PIN':'针',
    'ENTITY_FAMINE':'饥荒骑士','ENTITY_PESTILENCE':'瘟疫骑士','ENTITY_WAR':'战争骑士','ENTITY_DEATH':'死亡骑士',
    'ENTITY_DUKE':'苍蝇公爵','ENTITY_PEEP':'窥视者','ENTITY_LOKI':'洛基','ENTITY_FISTULA_BIG':'大瘘管','ENTITY_FISTULA_MEDIUM':'中瘘管',
    'ENTITY_MOMS_HEART':'妈妈的心','ENTITY_GEMINI':'双子','ENTITY_HEADLESS_HORSEMAN':'无头骑士','ENTITY_SATAN':'撒旦',
    'ENTITY_MASK_OF_INFAMY':'恶名面具','ENTITY_HEART_OF_INFAMY':'恶名之心','ENTITY_ISAAC':'以撒',
    'ENTITY_THE_LAMB':'羔羊','ENTITY_MEGA_SATAN':'超级撒旦','ENTITY_MEGA_SATAN_2':'超级撒旦第二形态',
    'ENTITY_ULTRA_GREED':'超级贪婪','ENTITY_HUSH':'噤声','ENTITY_DELIRIUM':'百变怪','ENTITY_DOGMA':'教条','ENTITY_BEAST':'祸兽',
}
unsafe_types = {0,1,2,3,7,8,9,1000}
for symbol,id_ in table('EntityType').items():
    if symbol.startswith('ENTITY_') and id_ not in unsafe_types:
        english = symbol[7:].replace('_',' ').title()
        add(f'entity:{id_}', 'entities', entity_cn.get(symbol, english), english, id_, 'entity', description='本机 EntityType 枚举中的实体类型。可填写变体和子类型；并非每个类型都存在 0 号变体，具体效果需在游戏中确认。', entityType=id_, variant=0, subtype=0, symbol=symbol)

pickup_cn = {10:'心',20:'硬币',30:'钥匙',40:'炸弹',41:'可投掷炸弹',42:'便便块',50:'普通箱子',51:'石头箱子',52:'刺箱',53:'永恒箱',54:'拟态箱',55:'旧箱子',56:'木箱',57:'大箱子',58:'幽灵箱',60:'金箱子',69:'福袋',70:'随机胶囊',90:'电池',100:'随机道具底座',110:'破铲子',150:'商店物品',300:'随机卡牌',340:'结局大箱子',350:'随机饰品',360:'红箱',370:'奖杯',380:'床',390:'妈妈的箱子'}
for symbol,id_ in table('PickupVariant').items():
    if id_ > 0:
        add(f'pickup:{id_}', 'entities', pickup_cn.get(id_, symbol), symbol[7:].replace('_',' ').title(), f'5.{id_}.0', 'entity', description='生成此类掉落物。子类型 0 通常表示随机；道具、饰品、卡牌可在对应目录选择精确对象后生成。', entityType=5,variant=id_,subtype=0,symbol=symbol)
sub_names = {
 'HEART_FULL':'红心','HEART_HALF':'半颗红心','HEART_SOUL':'魂心','HEART_ETERNAL':'永恒之心','HEART_DOUBLEPACK':'双红心','HEART_BLACK':'黑心','HEART_GOLDEN':'金心','HEART_HALF_SOUL':'半颗魂心','HEART_SCARED':'胆小的心','HEART_BLENDED':'混合心','HEART_BONE':'骨心','HEART_ROTTEN':'腐心',
 'COIN_PENNY':'一枚硬币','COIN_NICKEL':'镍币','COIN_DIME':'铸币','COIN_DOUBLEPACK':'双硬币','COIN_LUCKYPENNY':'幸运硬币','COIN_STICKYNICKEL':'粘性镍币','COIN_GOLDEN':'金硬币',
 'KEY_NORMAL':'普通钥匙','KEY_GOLDEN':'金钥匙','KEY_DOUBLEPACK':'双钥匙','KEY_CHARGED':'充能钥匙','BOMB_NORMAL':'普通炸弹拾取物','BOMB_DOUBLEPACK':'双炸弹','BOMB_TROLL':'即爆炸弹','BOMB_GOLDEN':'金炸弹','BOMB_SUPERTROLL':'超级即爆炸弹','BOMB_GOLDENTROLL':'金色即爆炸弹','BOMB_GIGA':'巨型炸弹',
 'BATTERY_NORMAL':'普通电池','BATTERY_MICRO':'微型电池','BATTERY_MEGA':'巨型电池','BATTERY_GOLDEN':'金电池'}
for enum,variant in [('HeartSubType',10),('CoinSubType',20),('KeySubType',30),('BombSubType',40),('BatterySubType',90)]:
    for symbol,id_ in table(enum).items():
        english=symbol.replace('_',' ').title()
        add(f'pickup:{variant}:{id_}', 'entities', sub_names.get(symbol,english),english,f'5.{variant}.{id_}','entity',description='生成指定的掉落物。',entityType=5,variant=variant,subtype=id_,symbol=symbol)

# 更多底层变体保留英文原名，避免不可靠的机器翻译。
for enum,type_,label in [('FamiliarVariant',3,'跟班'),('EffectVariant',1000,'特效'),('BombVariant',4,'炸弹')]:
    for symbol,id_ in table(enum).items():
        if symbol.endswith('_NULL') or symbol.startswith('NUM_'): continue
        english=symbol.replace('_',' ').title()
        add(f'variant:{type_}:{id_}', 'entities', label+' · '+english,english,f'{type_}.{id_}.0','entity', description='本机枚举中的'+label+'变体，部分对象依赖拥有者或特定房间状态；生成效果需游戏内确认。',entityType=type_,variant=id_,subtype=0,symbol=symbol)

keys=[x['key'] for x in entries]
assert len(keys)==len(set(keys)), '重复目录键'
assert all(x['name'] and x['id']!='' for x in entries), '目录缺失名称或 ID'
counts=dict(Counter(x['category'] for x in entries))
assert counts['collectibles'] >= 700 and counts['trinkets'] >= 180
assert counts['cards']==97 and counts['pills']==50 and counts['players']==41 and counts['challenges']==46
out={ 'version':VERSION, 'entries':entries, 'counts':counts,
 'coverage': '物品目录以本机枚举为准；实体包含全部可检索实体类型，以及本机公开枚举的掉落物、跟班、特效和炸弹变体，不包含未公开的全部敌人变体。',
 'provenance': {'enumsSha256':hashlib.sha256(enums_bytes).hexdigest(), 'cheatSheetRevision':REV,
 'sources':[{'id':'local-enums','label':'本机 resources/scripts/enums.lua'},{'id':'cheat-sheet+local-enums','label':'isaac-cheat-sheet（MIT）＋本机枚举','url':f'https://github.com/roiiiu/isaac-cheat-sheet/tree/{REV}'},{'id':'local-names+local-enums','label':'本机 EID 名称＋本机枚举'}]}}
(ROOT/'src/data').mkdir(parents=True,exist_ok=True)
(ROOT/'src/data/catalog.json').write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding='utf-8')
(ROOT/'src/data/enum-reference.json').write_text(json.dumps({x:table(x) for x in ['CollectibleType','TrinketType','Card','PillEffect','PlayerType','Challenge','EntityType']},indent=2),encoding='utf-8')
print(json.dumps(counts,ensure_ascii=False))
print('目录条目：',len(entries))
