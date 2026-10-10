# 美术资源 · gpt-image 提示词

游戏里所有图片都是「放进对应路径就自动替换」，缺图时会用程序绘制的占位图，所以可以一边出图一边玩。
放入图片后，在 Godot 编辑器里聚焦一下窗口让它完成导入；游戏内「卡牌编辑器 → 刷新图片」可以立即看到效果。

## 0. 规格总表

| 资源 | 路径 | 生成尺寸 | 背景 |
| --- | --- | --- | --- |
| 宝可梦立绘 | `assets/pokemon/<物种ID>.png` | 1024×1024 | 透明 |
| 闪光立绘（可选） | `assets/pokemon/<物种ID>_shiny.png` | 1024×1024 | 透明 |
| 品质框 ×6 | `assets/ui/frames/rarity_<品质ID>.png` | 1024×1536（建议缩放到 720×1000） | 透明（中间镂空） |
| 属性底框 ×18 | `assets/ui/frames/type_<属性ID>.png` | 1024×1536 | 不透明 |
| 世界地图 | `assets/ui/world_map.png` | 1536×1024 | 不透明 |
| 战斗背景（通用） | `assets/ui/battle_bg.png` | 1536×1024 | 不透明 |
| 战斗背景（按地区，可选） | `assets/ui/battle_bg_<地区ID>.png` | 1536×1024 | 不透明 |
| 主界面背景（可选） | `assets/ui/background.png` | 1536×1024 | 不透明 |
| 道具图标 ×9 | `assets/items/<道具ID>.png` | 1024×1024 | 透明 |

品质 ID：`common` 普通 / `uncommon` 优良 / `rare` 稀有 / `epic` 史诗 / `legendary` 传说 / `mythic` 神话

属性 ID：`normal fire water electric grass ice fighting poison ground flying psychic bug rock ghost dragon dark steel fairy`

> 生成透明背景时，在 gpt-image 的参数里设置 `background: "transparent"`、输出格式 `png`。

---

## 1. 统一画风前缀（每条提示词都加在最前面）

```text
Cute monster-collecting RPG game art, clean bold outlines, cel shading with soft gradients, vibrant saturated colors, glossy highlights, high readability at small sizes, consistent lighting from top-left, professional mobile game asset, no text, no watermark, no logo.
```

## 2. 宝可梦立绘

### 模板

```text
[统一画风前缀]
Full-body character illustration of {外观描述}. Three-quarter view facing LEFT, dynamic idle pose, the whole body fully inside the frame and centered with small margins, transparent background, no ground shadow, no scenery.
```

- 朝向一定要**朝左**（敌方站在右侧面向玩家；我方会被自动水平翻转）。
- 闪光版：在描述末尾加 `alternate rare "shiny" color palette: {闪光配色}`，保存为 `<ID>_shiny.png`；不做闪光图时游戏会自动给普通立绘叠金色调。
- 官方角色名有时会被模型拒绝，下表都是**纯外观描述**；如果你的工具允许，可以在前面加上英文名提高还原度。

### 外观描述（物种 ID → 可直接替换模板里的 `{外观描述}`）

| ID | 名称 | 外观描述 |
| --- | --- | --- |
| bulbasaur | 妙蛙种子 | a small teal-green quadruped dinosaur-like creature with darker green spots, red eyes, and a large green plant bulb growing on its back |
| ivysaur | 妙蛙草 | a teal quadruped creature with a pink flower bud surrounded by broad leaves on its back, sturdier legs, determined face |
| venusaur | 妙蛙花 | a huge sturdy teal quadruped creature carrying a giant blooming pink-red flower with big leaves and a palm-like trunk on its back |
| charmander | 小火龙 | a small orange bipedal lizard with a cream belly, big friendly eyes, and a bright flame burning at the tip of its tail |
| charmeleon | 火恐龙 | a crimson-red bipedal lizard with a horn on the back of its head, sharp claws, fierce eyes, flame on tail tip |
| charizard | 喷火龙 | a large orange dragon with big teal-lined wings, cream belly, long neck, two horns, and a roaring flame on its tail |
| squirtle | 杰尼龟 | a small light-blue bipedal turtle with a brown shell, cream belly plate, curly tail, cheerful face |
| wartortle | 卡咪龟 | a blue bipedal turtle with fluffy white feathery ears and a big fluffy curled tail, brown shell |
| blastoise | 水箭龟 | a large blue bipedal tortoise with a heavy brown shell fitted with two silver water cannons on its shoulders |
| caterpie | 绿毛虫 | a small green caterpillar with a yellow segmented underside, big eyes, and a short red forked antenna on its head |
| metapod | 铁甲蛹 | a green hard-shelled cocoon creature with a pointed top and sleepy half-closed eyes |
| butterfree | 巴大蝶 | a purple-bodied butterfly creature with large white wings with black veins, big red compound eyes, and curled antennae |
| pidgey | 波波 | a small plump brown and cream songbird with a pink beak and a tuft on its head |
| pidgeotto | 比比鸟 | a medium brown bird of prey with a red and yellow crest, sharp talons, and spread wings |
| pidgeot | 大比鸟 | a large majestic brown bird with a long flowing red and yellow crest, powerful wings, and keen eyes |
| rattata | 小拉达 | a small purple rat with a cream belly, long whiskers, big front teeth, and a curled tail |
| raticate | 拉达 | a chubby tan-brown rat with large sharp incisors, bushy whiskers, and a long scaly tail |
| pikachu | 皮卡丘 | a small yellow electric mouse with long black-tipped ears, red cheek pouches, and a lightning-bolt shaped tail |
| raichu | 雷丘 | an orange electric mouse with a cream belly, yellow cheek pouches, and a long thin black tail ending in a lightning bolt |
| sandshrew | 穿山鼠 | a small round yellow pangolin-like creature with a brick-patterned back and short claws |
| sandslash | 穿山王 | a yellow pangolin-like creature covered in sharp brown spikes on its back with long curved claws |
| clefairy | 皮皮 | a small round pink fairy with curled ears, a curl on its forehead, and tiny wings |
| clefable | 皮可西 | a larger pink fairy with pointed ears, a double curl on its head, and small folded wings |
| vulpix | 六尾 | a small russet-red fox with six curled orange tails and a fluffy curl of fur on its head |
| ninetales | 九尾 | an elegant cream-golden fox with nine long flowing tails tipped in orange and red eyes |
| zubat | 超音蝠 | a blue bat with purple wing membranes, no eyes, a wide open mouth with small fangs, and long legs |
| golbat | 大嘴蝠 | a large blue bat with an enormous gaping mouth with fangs, small eyes, and big purple wings |
| oddish | 走路草 | a small round blue plant creature with red eyes and five long green leaves sprouting from its head |
| gloom | 臭臭花 | a blue plant creature with a drooping big red-orange flower on its head, drooling, sleepy look |
| psyduck | 可达鸭 | a yellow duck holding its head with both hands, blank confused eyes, three hairs on its head |
| golduck | 哥达鸭 | a sleek blue humanoid duck with a red gem on its forehead, webbed hands and feet |
| growlithe | 卡蒂狗 | an orange puppy with black tiger stripes, fluffy cream fur on head, chest, and tail |
| arcanine | 风速狗 | a large majestic orange lion-dog with black stripes and a flowing cream mane and tail |
| abra | 凯西 | a yellow fox-like humanoid sitting cross-legged with eyes closed, brown armor-like torso |
| kadabra | 勇基拉 | a yellow fox-like humanoid psychic holding a silver spoon, a red star on its forehead, mustache |
| alakazam | 胡地 | a yellow fox-like humanoid sage with a long mustache, holding a silver spoon in each hand |
| machop | 腕力 | a small gray-blue muscular humanoid with three ridges on its head and red eyes |
| machoke | 豪力 | a muscular gray humanoid bodybuilder wearing a black championship belt with a gold buckle |
| machamp | 怪力 | a hulking gray humanoid with four muscular arms and a championship belt |
| geodude | 小拳石 | a round gray boulder with two muscular rocky arms and angry eyes, no legs |
| graveler | 隆隆石 | a lumpy gray boulder creature with four rocky arms and two stubby legs |
| golem | 隆隆岩 | a huge round creature with a brown rocky shell, a reptilian gray face, and strong limbs |
| magnemite | 小磁怪 | a small floating steel sphere with one big eye, a screw on top, and two horseshoe magnets on its sides |
| magneton | 三合一磁怪 | three small steel spheres with single eyes and magnets fused together in a triangle |
| gastly | 鬼斯 | a dark purple-black ghost sphere surrounded by a swirling purple gas aura with a big grin and fangs |
| haunter | 鬼斯通 | a purple ghost with spiky head, mischievous grin, and floating disembodied clawed hands |
| gengar | 耿鬼 | a round dark purple ghost with spikes on its back, red eyes, and a huge mischievous grin |
| onix | 大岩蛇 | a giant serpent made of a chain of gray boulders with a horn on its head |
| steelix | 大钢蛇 | a giant serpent made of shiny steel segments with jagged jaws and crystal-like spikes |
| cubone | 卡拉卡拉 | a small brown dinosaur-like creature wearing a white skull as a helmet and holding a bone club |
| marowak | 嘎啦嘎啦 | a brown dinosaur-like warrior wearing a skull helmet, wielding a large bone club |
| scyther | 飞天螳螂 | a green mantis warrior with large scythe blades for arms and translucent wings |
| magikarp | 鲤鱼王 | a red-orange carp fish with whiskers, a yellow crown-like fin, and blank goofy eyes |
| gyarados | 暴鲤龙 | a huge blue sea serpent dragon with a wide angry roaring mouth, white fins, and a cream belly |
| lapras | 拉普拉斯 | a gentle blue plesiosaur with a gray spiked shell on its back, a horn on its head |
| eevee | 伊布 | a small brown fox-like creature with big ears, a fluffy cream neck ruff, and a bushy tail |
| snorlax | 卡比兽 | a huge sleepy dark teal bear-like creature with a cream face and belly, sitting contentedly |
| articuno | 急冻鸟 | a majestic legendary ice-blue bird with long flowing crystal tail feathers and a crest |
| zapdos | 闪电鸟 | a legendary yellow bird with jagged spiky feathers crackling with lightning |
| moltres | 火焰鸟 | a legendary golden-orange bird with wings and crest made of blazing fire |
| dratini | 迷你龙 | a small slender blue serpent dragon with a white belly and white fin-like ears |
| dragonair | 哈克龙 | an elegant long blue serpent dragon with blue orbs on its neck and tail, small white wings on its head |
| dragonite | 快龙 | a friendly bulky orange dragon with small teal wings, antennae, and a cream belly |
| mewtwo | 超梦 | a tall pale purple-gray feline humanoid with a long purple tail and a tube connecting the back of its head to its spine, intense psychic aura |
| mew | 梦幻 | a tiny pink floating feline creature with big blue eyes and a long thin tail, playful pose |
| sneasel | 狃拉 | a black weasel-like creature with sharp claws, a red feather crest on its head, and a cunning look |
| larvitar | 幼基拉斯 | a small green rock-skinned dinosaur with a horn, red belly mark, and holes on its chest |
| pupitar | 沙基拉斯 | a gray-blue armored cocoon-like shell with angry eyes and jet vents |
| tyranitar | 班基拉斯 | a huge green armored kaiju dinosaur with spikes, a blue belly plate, and heavy tail |

## 3. 品质框（6 张）

模板（生成后缩放到 720×1000，中间区域必须完全透明）：

```text
[统一画风前缀]
Ornate trading card border frame only, portrait orientation, the entire center area is fully transparent and empty, the frame band is thin (about 5% of the card width) with small decorative corner ornaments, {材质与颜色}, symmetric, flat front view, transparent background, no character, no text.
```

| 文件 | `{材质与颜色}` |
| --- | --- |
| rarity_common.png | simple brushed gray stone and dull silver metal, minimal ornaments |
| rarity_uncommon.png | polished green jade with light silver trim, small leaf ornaments in the corners |
| rarity_rare.png | deep blue sapphire metal with silver filigree and small gem studs in the corners |
| rarity_epic.png | glowing purple amethyst crystal with gold filigree and soft magical sparkles |
| rarity_legendary.png | radiant orange-gold metal with engraved patterns, a sun emblem on top, warm glow |
| rarity_mythic.png | crimson red and black obsidian with gold edges, flame-like ornaments and a red glowing aura |

## 4. 属性底框（18 张）

模板（这是卡牌内部的底图，立绘画在它上面，所以中间要干净、不要太亮）：

```text
[统一画风前缀]
Trading card inner background art, portrait orientation, abstract themed pattern of {主题元素}, dominant color {主色}, darker and calmer in the center so a character can be placed on top, subtle vignette, no frame, no character, no text.
```

| 文件 | `{主题元素}` | `{主色}` |
| --- | --- | --- |
| type_normal.png | soft rolling meadow shapes and simple geometric stars | warm beige gray |
| type_fire.png | swirling flames and glowing embers | orange red |
| type_water.png | flowing waves, bubbles and ripples | ocean blue |
| type_electric.png | crackling lightning bolts and sparks | bright yellow |
| type_grass.png | layered leaves and vines | fresh green |
| type_ice.png | snowflakes and ice crystals | pale cyan |
| type_fighting.png | dynamic impact bursts and speed lines | deep red |
| type_poison.png | toxic bubbles and dripping ooze | violet purple |
| type_ground.png | cracked earth and sand dunes | sandy brown |
| type_flying.png | clouds, feathers and wind swirls | lavender sky blue |
| type_psychic.png | concentric psychic waves and third-eye symbols | magenta pink |
| type_bug.png | honeycomb hexagons and tiny leaves | lime yellow-green |
| type_rock.png | layered boulders and crystal veins | ochre brown |
| type_ghost.png | wispy spirits and dark mist | dusky indigo purple |
| type_dragon.png | dragon scales and ancient runes | royal violet blue |
| type_dark.png | crescent moon and shadow claw marks | dark brown black |
| type_steel.png | brushed metal plates, rivets and gears | silver blue gray |
| type_fairy.png | sparkles, ribbons and pastel stars | soft pink |

## 5. 世界地图

地区节点坐标在 `data/world.json` 的 `pos` 字段里（基于 840×560 的画布）。生成地图后如果位置对不上，直接改 `pos` 即可。

```text
[统一画风前缀]
Top-down fantasy world map of an island continent for a monster-collecting RPG, painted style, surrounded by ocean. Regions placed roughly: bottom-left a lush green forest; left-center rocky brown mountains; upper-left a sandy coast with a lighthouse; center-left an abandoned power plant; top a flower garden city; top-center a haunted purple tower; center a wide safari savanna; center-bottom icy snowy islands; bottom-right an erupting volcano island; right a long mountain road leading to a stadium; top-right a mysterious dark cave entrance. Dotted trails connect the regions, no text labels, no UI.
```

## 6. 战斗背景

通用版（`battle_bg.png`，同时用于对战塔和传说战）：

```text
[统一画风前缀]
Side-view battle background for a monster-collecting RPG, wide landscape, bright blue sky with soft clouds in the upper half, open grassy field in the lower half, empty center area for two creatures to stand on (no platforms needed), subtle depth of field, no characters, no text.
```

地区专属（可选，文件名 `battle_bg_<地区ID>.png`，把上面提示词里的场景换成）：

| 地区ID | 场景 |
| --- | --- |
| viridian_forest | sunlit dense forest clearing with tall trees and dappled light |
| pewter_mountain | rocky mountain pass with gray cliffs and boulders |
| cerulean_coast | sandy beach with turquoise sea and a lighthouse far away |
| power_plant | interior of an abandoned power plant with sparking generators and pipes |
| celadon_garden | blooming flower garden with fountains and hedges |
| lavender_tower | inside a dark haunted tower with candles and purple fog |
| fuchsia_safari | golden savanna with acacia trees and distant hills |
| seafoam_islands | frozen ice cave with glowing blue crystals |
| cinnabar_volcano | volcanic crater with lava rivers and ash clouds |
| victory_road | grand stone canyon road with a stadium silhouette far away |
| unknown_dungeon | mysterious deep cave with glowing purple runes |

## 7. 主界面背景（可选）

```text
[统一画风前缀]
Dark navy blue abstract background for a game menu, subtle hexagon pattern, faint glowing poke-ball like circle motifs, soft bokeh light particles, low contrast so UI panels stay readable, no text.
```

## 8. 道具图标

模板：

```text
[统一画风前缀]
Game item icon of {道具描述}, centered, slight 3/4 angle, soft drop shadow, transparent background.
```

| 文件 | `{道具描述}` |
| --- | --- |
| poke_ball.png | a capture ball, red top half, white bottom half, black band and white button in the middle |
| great_ball.png | a capture ball, blue top half with two red stripes, white bottom half, black band and button |
| ultra_ball.png | a capture ball, black top half with yellow H-shaped stripes, white bottom half |
| master_ball.png | a capture ball, purple top half with two pink bumps and a white letter M, white bottom half |
| potion.png | a purple spray bottle medicine with a white nozzle |
| super_potion.png | a yellow-orange spray bottle medicine with a white nozzle |
| max_potion.png | a deep blue spray bottle medicine with a gold cap |
| revive.png | a small golden diamond-shaped crystal shard glowing softly |
| rare_candy.png | a light blue wrapped candy with a sparkle |
