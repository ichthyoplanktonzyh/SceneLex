# SceneLex MVP 首批核心义项清单 (320 WordSenses)

> 基于 12 大词义经验分类与 14 个微世界候选构建的高频具身词义总表。

## scalar_degree (44 义项)

| ID | Lemma | POS | 微世界 | 词频 | 核心经验不变量 | 最近邻对比 | 释义摘要 |
|---|---|---|---|---|---|---|---|
| `almost-01` | **almost** | adverb | `ScalarThreshold` | top_500 | 沿连续量逼近阈值且差距极小，处于'差一点'未越线状态 | barely-01, nearly-01, already-01 | 差一点就达到临界值，但最终未达到 |
| `barely-01` | **barely** | adverb | `ScalarThreshold` | top_1000 | 沿连续量刚刚跨过阈值，余量极小接近于零 | almost-01, hardly-01, easily-01 | 刚刚好达到或勉强越过临界线 |
| `nearly-01` | **nearly** | adverb | `ScalarThreshold` | top_1000 | 量度距离目标状态仅有微小间隙，通常带时间或过程推进感 | almost-01, completely-01, approximately-01 | 非常接近某一状态或数量 |
| `enough-01` | **enough** | adverb | `ScalarThreshold` | top_500 | 量度越过需求线，不再产生短缺匮乏反应 | too-01, insufficient-01, barely-01 | 达到满足特定目的所需的最低充分阈值 |
| `too-01` | **too** | adverb | `ScalarThreshold` | top_500 | 量度越过容忍上限线，触发溢出、阻碍或负面溢出效应 | enough-01, very-01, slightly-01 | 超过可接受或合适范围的上限阈值产生负面后果 |
| `hardly-01` | **hardly** | adverb | `ScalarThreshold` | top_1000 | 量度紧贴零点或基线，几乎无法跨过可感知的最低阈值 | barely-01, easily-01, almost-01 | 几乎没有达到阈值，极度勉强或极少发生 |
| `completely-01` | **completely** | adverb | `ScalarThreshold` | top_1000 | 量轴充满至最大容量上限，无任何剩余空隙 | partly-01, almost-01, half-01 | 达到100%极限满格，毫无保留或遗漏 |
| `partly-01` | **partly** | adverb | `ScalarThreshold` | top_2000 | 量轴处于两极点之间的非完整填充区间 | completely-01, entirely-01, not_at_all-01 | 部分达到，处于0%与100%之间的中间区域 |
| `halfway-01` | **halfway** | adverb | `ScalarThreshold` | top_2000 | 位移或量度正好位于起点与终点的对称黄金平分线 | almost-01, halfway_through-01, start-01 | 恰好处于全程或总量的50%中点位置 |
| `fully-01` | **fully** | adverb | `ScalarThreshold` | top_1000 | 状态达到无折损、全尺寸、全功能的饱和点 | partially-01, completely-01, barely-01 | 完全充实展开，达到标准饱和状态 |
| `slightly-01` | **slightly** | adverb | `ScalarThreshold` | top_1000 | 在量轴上仅移动微小刻度，变化刚可察觉 | significantly-01, extremely-01, not_at_all-01 | 微小程度偏离基准零点 |
| `extremely-01` | **extremely** | adverb | `ScalarThreshold` | top_1000 | 量度远超日常基准平均值，逼近物理或心理承受极点 | moderately-01, slightly-01, fairly-01 | 处于量轴的最远端极值区间 |
| `fairly-01` | **fairly** | adverb | `ScalarThreshold` | top_1000 | 量度越过一般平均线，但在安全合理的中间带 | extremely-01, slightly-01, very-01 | 达到中等偏上但未达极端的适度程度 |
| `quite-01` | **quite** | adverb | `ScalarThreshold` | top_500 | 量度超出普通基线产生明确显著的心理感知 | slightly-01, completely-01, barely-01 | 显著高于一般基准，达到相当引人注意的程度 |
| `just-01` | **just** | adverb | `ScalarThreshold` | top_500 | 点坐标精准重合于目标阈值线，误差接近于零 | barely-01, almost-01, well-01 | 恰好贴在临界线上，无多余富余 |
| `practically-01` | **practically** | adverb | `ScalarThreshold` | top_2000 | 微小的未达成差距在功能或实用层面上可忽略不计 | theoretically-01, literally-01, completely-01 | 在实际效果上几乎等同于全部达成 |
| `scarcely-01` | **scarcely** | adverb | `ScalarThreshold` | top_3000 | 出现概率或量度极度微弱，紧贴消失边界 | abundantly-01, barely-01, frequently-01 | 数量极其罕见或程度极低，几乎难以达成 |
| `mostly-01` | **mostly** | adverb | `ScalarThreshold` | top_1000 | 占满量轴的70%-90%大部区间 | partly-01, completely-01, entirely-01 | 绝大部分比例达成，仅留微小未覆盖区域 |
| `entirely-01` | **entirely** | adverb | `ScalarThreshold` | top_1000 | 全域覆盖无死角，排他性达到100% | partly-01, largely-01, completely-01 | 完全、整体性地毫无例外 |
| `exceedingly-01` | **exceedingly** | adverb | `ScalarThreshold` | top_3000 | 量度跨越常规安全上界进入高溢出区 | moderately-01, barely-01, enough-01 | 大幅超过正常限度或预期规格 |
| `roughly-01` | **roughly** | adverb | `ScalarThreshold` | top_2000 | 点坐标落在以目标值为中心的容差置信区间内 | exactly-01, precisely-01, approximately-01 | 在目标参考值附近上下轻微波动近似 |
| `moderately-01` | **moderately** | adverb | `ScalarThreshold` | top_3000 | 量度保持在既不高也不低的平衡中心区 | extremely-01, excessively-01, slightly-01 | 在温和、适度、不偏激的中间区间内 |
| `substantially-01` | **substantially** | adverb | `ScalarThreshold` | top_2000 | 量度跨过微小变化门槛，形成不可忽视的体量 | nominally-01, slightly-01, completely-01 | 达到相当显著且有实际份量的比例 |
| `scant-01` | **scant** | adjective | `ScalarThreshold` | top_3000 | 供给量紧贴最低需求线下方，带来紧张感 | plentiful-01, abundant-01, barely-01 | 勉强够用但实际上处于不足边缘 |
| `insufficient-01` | **insufficient** | adjective | `ScalarThreshold` | top_2000 | 量度停留在需求线下方，造成功能无法正常启动 | enough-01, adequate-01, excessive-01 | 未达到特定目的所必须的最低量度 |
| `all-01` | **all** | determiner | `QuantitySet` | top_500 | 在给定闭合集合内，所有离散点全部点亮，无一例外 | none-01, some-01, most-01 | 集合内100%成员无一遗漏全覆盖 |
| `each-01` | **each** | determiner | `QuantitySet` | top_500 | 聚光灯从左至右逐个移动到每一个成员身上独立检验 | all-01, every-01, together-01 | 逐个独立聚焦集合内的每一个个体成员 |
| `every-01` | **every** | determiner | `QuantitySet` | top_500 | 强调集合的完整性，将全体成员无死角视为一个总规则 | each-01, some-01, any-01 | 无差别泛指集合内所有成员整体 |
| `both-01` | **both** | determiner | `QuantitySet` | top_500 | 恰好两个对象同时被选中点亮，比例为 2/2 | either-01, neither-01, all-01 | 二元集合中全部2个成员同时满足条件 |
| `either-01` | **either** | determiner | `QuantitySet` | top_500 | 在两个候选对象中选择其中任何一个均满足条件 | both-01, neither-01, one-01 | 二元集合中任意选择1个成员满足条件 |
| `neither-01` | **neither** | determiner | `QuantitySet` | top_1000 | 两个候选对象双双被红叉打上排除，比例为 0/2 | both-01, either-01, none-01 | 二元集合中2个成员均不满足条件，0%排除 |
| `few-01` | **few** | determiner | `QuantitySet` | top_500 | 数量仅有点滴几个，无法满足正常使用规模 | a_few-01, many-01, several-01 | 数量显著低于预期极度稀少，带有否定意味 |
| `several-01` | **several** | determiner | `QuantitySet` | top_500 | 数量大致在3到7个之间，可一眼看清每个个体 | few-01, many-01, couple-01 | 数量大于两个但不多，数个离散个体 |
| `most-01` | **most** | determiner | `QuantitySet` | top_500 | 选中区域在饼图或柱状图中超过半数基准线 | all-01, some-01, majority-01 | 在集合中占据超过50%的绝大多数 |
| `none-01` | **none** | pronoun | `QuantitySet` | top_500 | 在全集合扫描检验后，符合条件的个体总数为 0 | all-01, some-01, nothing-01 | 集合中满足条件的成员数为零 |
| `entire-01` | **entire** | adjective | `QuantitySet` | top_1000 | 一个实体从头到尾被无缝全部涂色覆盖，无残缺 | part-01, whole-01, partial-01 | 作为整体不可分割的100%全貌 |
| `whole-01` | **whole** | adjective | `QuantitySet` | top_500 | 未经过切片或剥离的完整原始几何形态 | piece-01, entire-01, slice-01 | 包含全部组成部分的完整形态未被切割 |
| `plenty-01` | **plenty** | pronoun | `QuantitySet` | top_1000 | 储备量大大堆积超过容量虚线，无需担心耗尽 | enough-01, scarce-01, excess-01 | 数量远超需求线存在充裕富余 |
| `some-01` | **some** | determiner | `QuantitySet` | top_500 | 从集合中抓取部分点，数量既非零也非全部 | all-01, none-01, any-01 | 集合中不确定的一部分成员存在 |
| `any-01` | **any** | determiner | `QuantitySet` | top_500 | 不论指向集合中的哪一个随机点均成立 | some-01, every-01, no-01 | 在开放集合中不受限制的任意一个成员 |
| `majority-01` | **majority** | noun | `QuantitySet` | top_1000 | 在天平或选票箱中，数量压过50%中线赢得主导 | minority-01, plurality-01, most-01 | 在群体投票或计数中超过半数的优势一方 |
| `minority-01` | **minority** | noun | `QuantitySet` | top_1000 | 在选票箱或群体分布中占比在50%中线以下 | majority-01, few-01 | 在群体中占比不足半数的少数一方 |
| `fraction-01` | **fraction** | noun | `QuantitySet` | top_2000 | 在百格图上仅占1到5格的微小比例切片 | majority-01, whole-01, bulk-01 | 整体中极小比例的一小撮部分 |
| `surplus-01` | **surplus** | noun | `QuantitySet` | top_3000 | 满足所有消耗需求后，箱外依然多余堆放的物料 | deficit-01, shortage-01, balance-01 | 超出消费或使用容量的过剩积压数量 |

## attribute (25 义项)

| ID | Lemma | POS | 微世界 | 词频 | 核心经验不变量 | 最近邻对比 | 释义摘要 |
|---|---|---|---|---|---|---|---|
| `long-01` | **long** | adjective | `DimensionNorm` | top_500 | 一维延伸距离显著大于容器或情境预期中位线 | short-01, medium-01 | 线性长度超出当前情境的基准参照 |
| `short-01` | **short** | adjective | `DimensionNorm` | top_500 | 一维延伸距离明显不足，未能触及基准目标线 | long-01, tall-01 | 线性长度或高度短于情境基准参照 |
| `wide-01` | **wide** | adjective | `DimensionNorm` | top_500 | 物体或开口的两侧间距充裕，允许多个主体同时通行 | narrow-01, broad-01 | 横向跨度超出基准，两侧边界间距大 |
| `narrow-01` | **narrow** | adjective | `DimensionNorm` | top_1000 | 两侧间距逼近通行物体的极限尺寸，需侧身或单列通过 | wide-01, tight-01 | 横向跨度极窄，两侧边界挤压难以通过 |
| `deep-01` | **deep** | adjective | `DimensionNorm` | top_1000 | 向下探底距离超出视线或肢体可触及的常规范围 | shallow-01, bottomless-01 | 从开口表面垂直向下的距离深远 |
| `shallow-01` | **shallow** | adjective | `DimensionNorm` | top_2000 | 底部极易被看见或触及，流体仅能浅浅覆盖脚踝 | deep-01, flat-01 | 表面到底部的垂直距离极短 |
| `thick-01` | **thick** | adjective | `DimensionNorm` | top_1000 | 前后表面间距大，不易弯折或光线难以穿透 | thin-01, fat-01 | 横截面厚度大，两表面间距显著 |
| `thin-01` | **thin** | adjective | `DimensionNorm` | top_1000 | 前后表面间距极小，极易透光或受力弯折 | thick-01, slender-01 | 横截面厚度极薄，轻薄柔韧 |
| `tall-01` | **tall** | adjective | `DimensionNorm` | top_500 | 从立足地面向上延伸的垂直高度显著超出观察者视平线 | short-01, high-01, low-01 | 垂直向上立起的高度超出同类基准 |
| `high-01` | **high** | adjective | `DimensionNorm` | top_500 | 物体底面相对于基准地面的绝对高度差大 | low-01, tall-01 | 处于离地距离遥远的高空位置 |
| `low-01` | **low** | adjective | `DimensionNorm` | top_500 | 离地垂直高度小，无需仰头即可触及或俯视 | high-01, tall-01 | 处于贴近地面的低矮垂直位置 |
| `tiny-01` | **tiny** | adjective | `DimensionNorm` | top_1000 | 体积显著小于手掌或参考硬币尺度，细节需放大观察 | small-01, huge-01, microscopic-01 | 整体三维体量极度微小 |
| `huge-01` | **huge** | adjective | `DimensionNorm` | top_1000 | 体积超出单次视野容纳范围，产生压迫感 | tiny-01, large-01, gigantic-01 | 整体三维体量超出常规空间参照 |
| `tight-01` | **tight** | adjective | `DimensionNorm` | top_1000 | 外包容腔尺寸与内含物尺寸几乎1:1锁死，无晃动活动余量 | loose-01, snug-01 | 包裹物紧贴物体表面，无多余空隙 |
| `loose-01` | **loose** | adjective | `DimensionNorm` | top_1000 | 外包容腔尺寸大于内含物，晃动产生位移和空隙 | tight-01, fixed-01 | 包裹或固定不紧，留有明显晃动空隙 |
| `broad-01` | **broad** | adjective | `DimensionNorm` | top_1000 | 连续表面无明显遮挡阻隔，水平延伸面积大 | narrow-01, wide-01 | 表面开阔宽平，横向展开面大 |
| `slender-01` | **slender** | adjective | `DimensionNorm` | top_3000 | 长宽比极高，横截面小但线条流畅优雅 | bulky-01, thin-01, thick-01 | 细长优美，纵横比大且匀称 |
| `bulky-01` | **bulky** | adjective | `DimensionNorm` | top_3000 | 三维外包围盒极大，超出单手抱持搬运的人机工程极限 | compact-01, slender-01, lightweight-01 | 体积庞大笨重，占用大空间难以搬运 |
| `steep-01` | **steep** | adjective | `DimensionNorm` | top_2000 | 坡面法线与水平夹角逼近90度，重力沿坡面分力极大 | gentle-01, flat-01, vertical-01 | 斜坡倾角极大接近垂直，攀爬阻力大 |
| `flat-01` | **flat** | adjective | `DimensionNorm` | top_1000 | 表面各点曲率为零，物体放置其上平稳不倾斜 | bumpy-01, steep-01, curved-01 | 表面水平光滑，无起伏凹凸 |
| `heavy-01` | **heavy** | adjective | `DimensionNorm` | top_500 | 向下重力加速度响应强烈，双手托起产生肌肉紧绷颤抖 | light-01, weightless-01 | 质量大，需施加极大向上支撑力 |
| `light-01` | **light** | adjective | `DimensionNorm` | top_500 | 重力阻抗极微弱，可轻松被指尖抛接 | heavy-01, bulky-01 | 质量小，单手轻微施力即可托起 |
| `hollow-01` | **hollow** | adjective | `DimensionNorm` | top_2000 | 外部有坚固轮廓但敲击发空声，剖面显示内部完全排空 | solid-01, full-01 | 外壳包围而内部空无一物 |
| `solid-01` | **solid** | adjective | `DimensionNorm` | top_1000 | 从表及里完全由均质材料填充，敲击发沉实闷响 | hollow-01, liquid-01, fragile-01 | 内部致密充满，无内部空腔 |
| `messy-01` | **messy** | adjective | `DimensionNorm` | top_2000 | 空间内多个离散物体位置错位、倒伏，打破分类边界 | dirty-01, tidy-01, neat-01 | 物品摆放位置偏离正常秩序，混乱无章 |

## spatial_relation (30 义项)

| ID | Lemma | POS | 微世界 | 词频 | 核心经验不变量 | 最近邻对比 | 释义摘要 |
|---|---|---|---|---|---|---|---|
| `across-01` | **across** | preposition | `SpatialTopology` | top_500 | 轨迹横切二维表面或通道，起始与终止分别位于两侧边界外 | through-01, along-01, around-01 | 从二维区域或表面的一侧横跨到位移到另一侧 |
| `through-01` | **through** | preposition | `SpatialTopology` | top_500 | 主体从入口进入被包围的内部空间，由出口离开 | across-01, around-01, past-01 | 从三维封闭通道内部穿透而过 |
| `along-01` | **along** | preposition | `SpatialTopology` | top_500 | 运动轨迹始终与线性参照物的边缘保持连续平行且方向一致 | across-01, toward-01, away_from-01 | 沿着线性地标的延伸方向平行位移 |
| `past-01` | **past** | preposition | `SpatialTopology` | top_1000 | 主体逼近参照物、平齐穿过并在距离上超越其位置 | through-01, toward-01, behind-01 | 经过参照物并继续向前超越到其后方 |
| `inside-01` | **inside** | preposition | `SpatialTopology` | top_500 | 主体被容器或房间的全封闭实体边界在几何上包围 | outside-01, within-01, onto-01 | 处于三维封闭边界包围的内部空间 |
| `outside-01` | **outside** | preposition | `SpatialTopology` | top_500 | 主体位于封闭物理包围圈之外的开放空间 | inside-01, beyond-01 | 处于封闭边界外部，未进入内部 |
| `between-01` | **between** | preposition | `SpatialTopology` | top_500 | 主体左右或前后被恰好两个独立边界实体夹在当中 | among-01, beside-01, opposite-01 | 处于两个独立参照物构成的中间间隙中 |
| `among-01` | **among** | preposition | `SpatialTopology` | top_1000 | 主体被多个同类离散实体环绕散布在周围 | between-01, surrounded_by-01, inside-01 | 处于三个以上离散群体成员的包围环绕之中 |
| `under-01` | **under** | preposition | `SpatialTopology` | top_500 | 主体处于参照平面正下方的重力投影区内 | over-01, below-01, beneath-01 | 处于参照物正下方，受上方物体遮挡 |
| `over-01` | **over** | preposition | `SpatialTopology` | top_500 | 轨迹在垂直投影上覆盖参照物上方顶点并掠过 | under-01, above-01, across-01 | 从参照物上方越过且未发生物理接触 |
| `above-01` | **above** | preposition | `SpatialTopology` | top_500 | 静态高度坐标显著高于基准参照平面 | below-01, over-01, onto-01 | 垂直位置高于参照平面，无接触 |
| `below-01` | **below** | preposition | `SpatialTopology` | top_500 | 静态高度坐标显著低于水平参考基准线 | above-01, under-01 | 垂直位置低于参照平面 |
| `around-01` | **around** | preposition | `SpatialTopology` | top_500 | 轨迹构成包围中心地标的闭合或半闭合圆弧曲线 | through-01, across-01, past-01 | 环绕参照物外周轨道运动或分布 |
| `behind-01` | **behind** | preposition | `SpatialTopology` | top_500 | 从主视点观察，主体被前方的参照实体遮蔽在后方 | in_front_of-01, beside-01 | 处于参照物背面或视线被遮挡的一侧 |
| `in_front_of-01` | **in front of** | preposition | `SpatialTopology` | top_500 | 主体位于参照物主朝向的正前方，无遮挡直视 | behind-01, beside-01 | 处于参照物正面朝向的视野开阔区 |
| `beside-01` | **beside** | preposition | `SpatialTopology` | top_1000 | 主体紧靠参照实体的左侧或右侧侧翼边缘 | between-01, near-01, behind-01 | 紧邻参照物的侧面边缘 |
| `into-01` | **into** | preposition | `SpatialTopology` | top_500 | 位移向量切入三维边界，终点状态为 inside | out_of-01, inside-01, onto-01 | 从外部跨越边界向内部深入的动态位移 |
| `out_of-01` | **out of** | preposition | `SpatialTopology` | top_500 | 位移向量穿出三维边界，终点状态为 outside | into-01, off-01, outside-01 | 从封闭内部跨越边界来到外部的动态位移 |
| `onto-01` | **onto** | preposition | `SpatialTopology` | top_1000 | 位移向量终止于承重支撑面，建立物理接触 | off-01, into-01, upon-01 | 运动位移的落点落在承载支撑表面上 |
| `off-01` | **off** | preposition | `SpatialTopology` | top_500 | 接触面连接被打破，主体与原表面产生物理间隙 | onto-01, on-01, out_of-01 | 脱离原本附着或支撑的表面向外/向下分离 |
| `toward-01` | **toward** | preposition | `SpatialTopology` | top_500 | 主体与目标物之间的欧氏距离随着时间单调递减 | away_from-01, past-01, along-01 | 运动向量方向明确指向目标参照物 |
| `away_from-01` | **away from** | preposition | `SpatialTopology` | top_500 | 主体与目标物之间的欧氏距离随着时间单调递增 | toward-01, out_of-01 | 运动向量方向背离目标参照物逐渐远离 |
| `against-01` | **against** | preposition | `SpatialTopology` | top_500 | 主体与垂直或斜立表面接触并产生持续的侧向受力 | beside-01, onto-01, with-01 | 紧贴或压迫参照物表面，存在支撑反作用力 |
| `opposite-01` | **opposite** | preposition | `SpatialTopology` | top_1000 | 两者主朝向面对面相互凝视，中间被通路隔开 | beside-01, across-01, behind-01 | 隔着通道与参照物正对面直接相对 |
| `across_from-01` | **across from** | preposition | `SpatialTopology` | top_2000 | 穿过一条物理分割带直接看到对立面的实体 | opposite-01, next_to-01 | 正对着隔着街道或隔断与对方相对 |
| `throughout-01` | **throughout** | preposition | `SpatialTopology` | top_1000 | 实体或现象在整个三维容腔内部均匀密集分布 | partly-01, within-01, inside-01 | 遍布整个空间的每一个角落与区域 |
| `beyond-01` | **beyond** | preposition | `SpatialTopology` | top_1000 | 主体坐标超过了预设的标志性终点线更外侧 | within-01, past-01, outside-01 | 超出特定地标或界限到达更遥远的区域 |
| `within-01` | **within** | preposition | `SpatialTopology` | top_500 | 主体坐标被限制在限定闭合圈内，绝不越过红线 | beyond-01, outside-01, inside-01 | 在明确划定的物理或抽象边界范围之内 |
| `beneath-01` | **beneath** | preposition | `SpatialTopology` | top_1000 | 主体被上一层物质完全覆盖包覆在底面 | under-01, below-01, underneath-01 | 紧贴在覆盖物正下方或隐藏于其下 |
| `upon-01` | **upon** | preposition | `SpatialTopology` | top_1000 | 重力完全由下层表面承托，静态稳定位于其上 | onto-01, above-01, over-01 | 置于上表面且建立稳固的承重接触 |

## temporal_relation (25 义项)

| ID | Lemma | POS | 微世界 | 词频 | 核心经验不变量 | 最近邻对比 | 释义摘要 |
|---|---|---|---|---|---|---|---|
| `before-01` | **before** | preposition | `TemporalRelation` | top_500 | 目标事件在时间轴上的落点严格早于参照事件的起始点 | after-01, during-01, earlier-01 | 在参照事件发生之前的时间区间 |
| `after-01` | **after** | preposition | `TemporalRelation` | top_500 | 目标事件在时间轴上的起始点严格晚于参照事件的终止点 | before-01, during-01, later-01 | 在参照事件结束之后的时间区间 |
| `while-01` | **while** | conjunction | `TemporalRelation` | top_500 | 事件A与事件B在时间轴上的持续区间发生重叠共现 | during-01, until-01, meanwhile-01 | 在两个持续事件并行的重叠时间区间 |
| `during-01` | **during** | preposition | `TemporalRelation` | top_500 | 目标事件的发生时点或区间完全包含于背景事件区间中 | while-01, throughout-01, before-01 | 在某一持续事件的时间跨度内部 |
| `until-01` | **until** | preposition | `TemporalRelation` | top_500 | 初始状态在时间轴上持续维持，直到某一事件触发状态终止 | since-01, by-01, during-01 | 状态持续直至终止时点，随后触发改变 |
| `since-01` | **since** | preposition | `TemporalRelation` | top_500 | 从明确的过去触发点开始，状态无间断延续至今 | until-01, from-01, ever_since-01 | 从过去起始时点持续至当前观察点 |
| `already-01` | **already** | adverb | `TemporalRelation` | top_500 | 事件完成的实际时点明显先于时间表或常识预期 | still-01, yet-01, almost-01 | 事件发生早于预期时点 |
| `still-01` | **still** | adverb | `TemporalRelation` | top_500 | 状态跨越了预期的终止时限依然在继续延续 | already-01, anymore-01, yet-01 | 状态未如预期那样结束而持续存在 |
| `soon-01` | **soon** | adverb | `TemporalRelation` | top_500 | 从当前观察点到事件触发点之间的时间跨度极短 | immediately-01, later-01, eventually-01 | 发生时点距离当前参考点极近 |
| `suddenly-01` | **suddenly** | adverb | `TemporalRelation` | top_500 | 前置平稳节奏被斜率极陡峭的瞬间状态变化打破 | gradually-01, slowly-01, unexpectedly-01 | 无前兆打破平稳节奏的瞬间触发 |
| `finally-01` | **finally** | adverb | `TemporalRelation` | top_500 | 跨越长耗时或多重阻碍序列后，到达预期的终结状态 | initially-01, eventually-01, suddenly-01 | 历经漫长等待或多个步骤后最终到达 |
| `meanwhile-01` | **meanwhile** | adverb | `TemporalRelation` | top_1000 | 在主线时间区间内，另一空间的次级事件同步推进 | while-01, subsequently-01, simultaneously-01 | 与主线事件同时在另一处展开 |
| `eventually-01` | **eventually** | adverb | `TemporalRelation` | top_1000 | 虽然经历未知延宕，但在时间轴尽头确定收敛至该结果 | soon-01, immediately-01, never-01 | 在不确定的未来跨度中终将发生 |
| `immediately-01` | **immediately** | adverb | `TemporalRelation` | top_1000 | 前一事件的终点与后一事件的起点之间时间差为零 | soon-01, later-01, gradually-01 | 紧接前一事件无时间间隔瞬间发生 |
| `gradually-01` | **gradually** | adverb | `TemporalRelation` | top_1000 | 状态变化速率慢且平滑连续，无突兀跳跃 | suddenly-01, instantly-01, rapidly-01 | 在连续时间轴上以平缓斜率平稳变化 |
| `temporarily-01` | **temporarily** | adverb | `TemporalRelation` | top_2000 | 状态被限定在一个非永久区间内，设定了复原预期 | permanently-01, constantly-01, briefly-01 | 仅在有限短暂时间段内有效，终将复原 |
| `permanently-01` | **permanently** | adverb | `TemporalRelation` | top_2000 | 状态改变具有不可逆性，在时间轴未来区间恒定为真 | temporarily-01, briefly-01, momentarily-01 | 状态一旦建立永不复原，无限期持续 |
| `earlier-01` | **earlier** | adverb | `TemporalRelation` | top_500 | 时点坐标小于当前的基准参照时点 | later-01, now-01, before-01 | 在时间轴上更偏向过去的位置 |
| `later-01` | **later** | adverb | `TemporalRelation` | top_500 | 时点坐标大于当前的基准参照时点 | earlier-01, soon-01, after-01 | 在时间轴上更偏向未来的位置 |
| `punctual-01` | **punctual** | adjective | `TemporalRelation` | top_3000 | 到达时点与预定钟表时间完全对齐，时间偏差为零 | late-01, early-01, delayed-01 | 精确在约定时间点到达，既不早也不迟 |
| `simultaneously-01` | **simultaneously** | adverb | `TemporalRelation` | top_2000 | 两个以上独立事件在时间轴上的触发时点完全重合 | sequentially-01, separately-01, meanwhile-01 | 多个事件在同一时钟点精准共同触发 |
| `briefly-01` | **briefly** | adverb | `TemporalRelation` | top_1000 | 事件持续时长极短，闪烁而过 | prolonged-01, constantly-01, temporarily-01 | 仅维持极短时间跨度即告结束 |
| `seldom-01` | **seldom** | adverb | `TemporalRelation` | top_2000 | 在给定时间周期内事件发生的频次接近于零 | frequently-01, often-01, rarely-01 | 在时间跨度中极少出现实例 |
| `frequently-01` | **frequently** | adverb | `TemporalRelation` | top_1000 | 事件实例在时间轴上以较短间隔反复发生 | seldom-01, rarely-01, constantly-01 | 在时间跨度中密集重复出现 |
| `constantly-01` | **constantly** | adverb | `TemporalRelation` | top_1000 | 事件发生的时间间隔为零，构成无缝延续 | intermittently-01, frequently-01, occasionally-01 | 无间断连续不休地持续发生 |

## entity (31 义项)

| ID | Lemma | POS | 微世界 | 词频 | 核心经验不变量 | 最近邻对比 | 释义摘要 |
|---|---|---|---|---|---|---|---|
| `cup-01` | **cup** | noun | `EntityPrototype` | top_500 | 单手持握、开口向上、用于盛装并直接送至嘴边饮用 | mug-01, glass-01, bowl-01 | 饮用容器：小容量、有柄或无柄、盛冷热饮 |
| `mug-01` | **mug** | noun | `EntityPrototype` | top_1000 | 圆柱体厚壁、明显侧柄可容纳多指插入、常盛咖啡/茶 | cup-01, glass-01, jug-01 | 带柄厚壁大容量柱状杯，常盛热饮 |
| `glass-01` | **glass** | noun | `EntityPrototype` | top_500 | 透明易碎材质、无柄、用于观察内部冷饮液体 | cup-01, mug-01, bottle-01 | 透明材质无柄直壁冷饮容器 |
| `bowl-01` | **bowl** | noun | `EntityPrototype` | top_1000 | 半球形或圆锥形深底大口、需用勺舀取或双手托捧 | plate-01, dish-01, cup-01 | 大口深凹盛装流食或颗粒物餐具容器 |
| `plate-01` | **plate** | noun | `EntityPrototype` | top_1000 | 扁平圆盘、边缘略有翘起防止汤汁溢出、盛放固体菜肴 | bowl-01, dish-01, tray-01 | 浅平边缘微翘盛装固体食物容器 |
| `dish-01` | **dish** | noun | `EntityPrototype` | top_500 | 承载烹饪成品供端上餐桌供人取食的容器通称 | plate-01, bowl-01, pot-01 | 泛指各种盛装食物的餐具容器 |
| `chair-01` | **chair** | noun | `EntityPrototype` | top_500 | 四腿支撑、单人座位、有靠背可供后倾支撑脊椎 | stool-01, couch-01, bench-01 | 带靠背的单人坐具 |
| `stool-01` | **stool** | noun | `EntityPrototype` | top_2000 | 三腿或四腿单人坐具，完全无后靠背结构 | chair-01, bench-01 | 无靠背无扶手的简易单人坐具 |
| `couch-01` | **couch** | noun | `EntityPrototype` | top_1000 | 宽大软包、可容纳多人并排乘坐或单人横躺 | chair-01, bench-01, bed-01 | 多座带软垫扶手可供斜靠的沙发坐具 |
| `bench-01` | **bench** | noun | `EntityPrototype` | top_1000 | 狭长横向座板、无软包、置于户外或公园供多人坐 | chair-01, couch-01, stool-01 | 长条形木质或石质多人乘坐坐具 |
| `jacket-01` | **jacket** | noun | `EntityPrototype` | top_1000 | 下摆及腰、前开拉链或纽扣、活动便利的外穿衣物 | coat-01, vest-01, sweater-01 | 短款及腰前开襟上衣外套 |
| `coat-01` | **coat** | noun | `EntityPrototype` | top_500 | 下摆过臀或及膝、材质厚重保暖、穿于所有衣服最外层 | jacket-01, cloak-01, sweater-01 | 长款过臀防寒外衣大衣 |
| `sweater-01` | **sweater** | noun | `EntityPrototype` | top_1000 | 针织毛线纹理、有弹性、套头或开襟保暖 | jacket-01, shirt-01, coat-01 | 针织毛线保暖上衣 |
| `vest-01` | **vest** | noun | `EntityPrototype` | top_2000 | 无袖孔、保护躯干前胸、穿于衬衫之外或西装之内 | jacket-01, shirt-01 | 无袖前开襟贴身上衣马甲 |
| `shoe-01` | **shoe** | noun | `EntityPrototype` | top_500 | 包裹脚掌、鞋口在脚踝下方、硬质鞋底供日常行走 | boot-01, sandal-01, slipper-01 | 不覆盖脚踝的日常硬底步行鞋 |
| `boot-01` | **boot** | noun | `EntityPrototype` | top_1000 | 鞋帮高耸完全覆盖脚踝及部分小腿，防护力强 | shoe-01, sneaker-01 | 包覆脚踝及小腿的高帮防护鞋靴 |
| `sandal-01` | **sandal** | noun | `EntityPrototype` | top_2000 | 仅靠鞋底与几根带子固定在脚上，大部分脚趾和脚面外露 | shoe-01, slipper-01 | 带绑带透气开放式凉鞋 |
| `slipper-01` | **slipper** | noun | `EntityPrototype` | top_2000 | 脚后跟开放无包裹、材质柔软、一踩即穿供室内使用 | shoe-01, sandal-01 | 无后帮易穿脱室内软底拖鞋 |
| `pot-01` | **pot** | noun | `EntityPrototype` | top_1000 | 深圆柱腔体、两侧双耳把手、带盖用于炖煮汤水 | pan-01, kettle-01, bowl-01 | 深腔双耳带盖烹饪煮锅 |
| `pan-01` | **pan** | noun | `EntityPrototype` | top_1000 | 浅底宽面、单根向外延伸长柄、用于高温煎炒 | pot-01, plate-01 | 浅底单长柄煎炒平底锅 |
| `hat-01` | **hat** | noun | `EntityPrototype` | top_500 | 有独立冠部、且四周有一圈完整的突出帽檐 | cap-01, helmet-01, hood-01 | 全圈带帽檐的头部护具帽子 |
| `cap-01` | **cap** | noun | `EntityPrototype` | top_1000 | 紧贴头顶圆顶、无全圈檐、仅在正前方有一块向前突出的硬板 | hat-01, helmet-01 | 贴合头型仅前方有突出硬檐的棒球帽/便帽 |
| `bottle-01` | **bottle** | noun | `EntityPrototype` | top_500 | 瓶身宽大但顶部有明显收缩变细的瓶颈与小口 | jar-01, can-01, cup-01 | 窄颈小口可密封的液体容器瓶子 |
| `jar-01` | **jar** | noun | `EntityPrototype` | top_1000 | 口径与瓶身几乎同宽、带螺纹盖密封、用于存如果酱腌菜 | bottle-01, can-01, pot-01 | 宽口直身带螺旋盖的储存罐 |
| `box-01` | **box** | noun | `EntityPrototype` | top_500 | 平底直壁刚性表面、直角拐角、带盖或翻折闭合 | bag-01, basket-01, drawer-01 | 规则直角六面体硬质容纳盒箱 |
| `bag-01` | **bag** | noun | `EntityPrototype` | top_500 | 无固定刚性外壳、可随内容物变形折叠、带提手或背带 | box-01, pocket-01, pouch-01 | 柔性材质可折叠提携的容纳袋 |
| `ladder-01` | **ladder** | noun | `EntityPrototype` | top_1000 | 平行两梁中间镶嵌阶梯横档、需斜靠墙壁或人字展开 | stairs-01, step_stool-01 | 两根纵梁加横档的可移动登高工具梯子 |
| `stairs-01` | **stairs** | noun | `EntityPrototype` | top_500 | 永久固定于建筑物、连续错层直角台阶、供人逐级步行上下 | ladder-01, ramp-01, escalator-01 | 建筑内部固定的连续阶梯结构 |
| `bucket-01` | **bucket** | noun | `EntityPrototype` | top_1000 | 敞口圆桶、顶部装有活动半圆金属/塑料提梁 | jug-01, pot-01, bowl-01 | 带弧形提手的敞口深筒盛水桶 |
| `jug-01` | **jug** | noun | `EntityPrototype` | top_2000 | 一侧有固定垂直把手、另一侧口沿有突出尖嘴便于倾倒 | bucket-01, bottle-01, kettle-01 | 带把手带导流小嘴的大容量倾倒液体壶 |
| `portion-01` | **portion** | noun | `QuantitySet` | top_1000 | 从大圆饼中切下一角放置于独立餐盘中供个人享用 | whole-01, slice-01, share-01 | 从整体中切分出来的具体一份食物或资源 |

## state_change (25 义项)

| ID | Lemma | POS | 微世界 | 词频 | 核心经验不变量 | 最近邻对比 | 释义摘要 |
|---|---|---|---|---|---|---|---|
| `melt-01` | **melt** | verb | `StateTransition` | top_1000 | 前态保持刚性形状，受热后软化塌陷流淌失去固定形态 | freeze-01, dissolve-01, burn-01 | 固态物质因温度升高转化为流动态液体 |
| `freeze-01` | **freeze** | verb | `StateTransition` | top_1000 | 前态具有流动性，降温后结晶硬化完全失去流动性 | melt-01, solidify-01, cool-01 | 流体物质因降温凝固硬化为固定固态 |
| `boil-01` | **boil** | verb | `StateTransition` | top_1000 | 液体内部剧烈生成向上逸出气泡，蒸汽大量蒸腾 | evaporate-01, simmer-01, melt-01 | 液体受热达到沸点剧烈翻滚产生气泡并汽化 |
| `evaporate-01` | **evaporate** | verb | `StateTransition` | top_2000 | 液面高度随时间缓慢降低，未见剧烈沸腾而完全消失 | boil-01, condense-01, dry-01 | 液体表面缓慢转化为气体消失在空气中 |
| `dissolve-01` | **dissolve** | verb | `StateTransition` | top_2000 | 固体颗粒落入溶剂经搅拌分子分散，液体变透明 | melt-01, mix-01, disappear-01 | 固体溶质在液体中均匀扩散并彻底隐形 |
| `crack-01` | **crack** | verb | `StateTransition` | top_1000 | 连续表面产生不可逆缝隙线，但结构大体保持为一个整体 | shatter-01, snap-01, break-01 | 刚性物体表面受力出现裂纹但主体未完全碎开 |
| `shatter-01` | **shatter** | verb | `StateTransition` | top_2000 | 前态完好，瞬间冲击后炸裂成数十块细小散落碎片 | crack-01, snap-01, break-01 | 脆性物体受强冲击瞬间崩解成众多碎片 |
| `snap-01` | **snap** | verb | `StateTransition` | top_1000 | 杆状物承受弯曲应力超过极限，伴随清脆响声断为两段 | bend-01, crack-01, tear-01 | 细长硬质物体受弯折力清脆折断为两截 |
| `tear-01` | **tear** | verb | `StateTransition` | top_1000 | 纸张或织物受相反方向拉力从边缘撕开纤维分离 | cut-01, snap-01, rip-01 | 柔性薄片材料因拉扯分离边缘破碎 |
| `burn-01` | **burn** | verb | `StateTransition` | top_500 | 火焰附着表面蔓延，原材质碳化发黑崩解冒烟 | melt-01, boil-01, char-01 | 物体受火氧化转变为黑炭灰烬并放出光热 |
| `dry-01` | **dry** | verb | `StateTransition` | top_500 | 表面深色水渍与反光逐渐消退，恢复干燥粗糙原色 | wet-01, soak-01, evaporate-01 | 含水物体失去水分表面水分蒸发变干 |
| `rot-01` | **rot** | verb | `StateTransition` | top_2000 | 果实或木质组织变软发黑塌陷散发异味 | spoil-01, decay-01, dry-01 | 有机物因微生物分解发生变色软化腐烂 |
| `rust-01` | **rust** | verb | `StateTransition` | top_2000 | 金属银亮光滑表面逐步被剥落的红褐色粗糙氧化层覆盖 | tarnish-01, corrode-01, stain-01 | 铁质金属表面受潮氧化生成红褐色锈层 |
| `heal-01` | **heal** | verb | `StateTransition` | top_1000 | 破损创口逐步结痂收缩新生组织填平创面 | injure-01, recover-01, scar-01 | 受损生物组织逐渐修复闭合恢复原状 |
| `bend-01` | **bend** | verb | `StateTransition` | top_1000 | 原本直线形态受力改变曲率形成圆弧弯角而未断裂 | snap-01, straighten-01, twist-01 | 物体受力发生弧度形变但未折断 |
| `wrinkle-01` | **wrinkle** | verb | `StateTransition` | top_2000 | 原本平滑张紧的布料或皮肤表面出现交叉起伏纹理 | smooth-01, flatten-01, fold-01 | 平整表面因挤压产生褶皱起伏 |
| `fade-01` | **fade** | verb | `StateTransition` | top_1000 | 鲜艳饱和的视觉或声音信号强度连续衰减至几乎不可见/听 | darken-01, brighten-01, disappear-01 | 色彩明度或声音强度随时间逐渐降低变淡 |
| `spoil-01` | **spoil** | verb | `StateTransition` | top_2000 | 新鲜可食状态发生酸败浑浊无法再被使用 | preserve-01, rot-01, ruin-01 | 食物或资源变质失去原生效用与价值 |
| `collapse-01` | **collapse** | verb | `StateTransition` | top_1000 | 立体立起结构失去承重支点瞬间向中心凹陷坠落地面 | stand-01, fall-01, crush-01 | 支撑结构突然失效整体向内向下垮塌 |
| `inflate-01` | **inflate** | verb | `StateTransition` | top_2000 | 内部气压增加带动外皮由干瘪褶皱逐渐饱满紧绷膨大 | deflate-01, expand-01, shrink-01 | 内部充入流体气体向外膨胀撑大 |
| `deflate-01` | **deflate** | verb | `StateTransition` | top_2000 | 内部气压消失，饱满球体收缩变小表面起皱塌瘪 | inflate-01, shrink-01 | 内部气体逸出导致外壳收缩干瘪塌陷 |
| `solidify-01` | **solidify** | verb | `StateTransition` | top_3000 | 粘稠可流动状态逐渐凝结形成抗压刚性实体 | liquefy-01, freeze-01, harden-01 | 流体或软质材料固化变硬形成坚固实体 |
| `liquefy-01` | **liquefy** | verb | `StateTransition` | top_3000 | 原本固定形态在外界条件下融化流动成液态 | solidify-01, melt-01 | 固体或气体转变为流动态液体 |
| `tangle-01` | **tangle** | verb | `StateTransition` | top_2000 | 平行独立的线缆相互交叉打结形成混乱结团 | untangle-01, knot-01, straighten-01 | 多根线状物错乱打结缠绕无法顺畅梳理 |
| `untangle-01` | **untangle** | verb | `StateTransition` | top_3000 | 逐个穿出绳结将混乱交织的线绳理顺为平行单根 | tangle-01, loosen-01 | 解开错乱线团恢复单根独立顺畅状态 |

## action (70 义项)

| ID | Lemma | POS | 微世界 | 词频 | 核心经验不变量 | 最近邻对比 | 释义摘要 |
|---|---|---|---|---|---|---|---|
| `crawl-01` | **crawl** | verb | `MotionManner` | top_1000 | 低重心、四肢交替支撑贴地、低速且连续向前蠕动位移 | creep-01, walk-01, slide-01 | 身体贴地或四肢着地低速移动 |
| `rush-01` | **rush** | verb | `MotionManner` | top_500 | 步伐急促、身体前倾、极力缩短路程耗时冲向目标 | stroll-01, dash-01, hurry-01 | 高初速度、强紧迫感向前快速位移 |
| `wander-01` | **wander** | verb | `MotionManner` | top_1000 | 移动轨迹呈无规则弯折、步频缓慢从容、无终点约束 | march-01, stroll-01, stray-01 | 无固定目标方向、路径曲折随机漫步 |
| `stumble-01` | **stumble** | verb | `MotionManner` | top_1000 | 脚尖触碰障碍物导致步态突遭打断，身体前倾踉跄调整平衡 | slip-01, trip-01, stagger-01 | 足部受绊重心失稳瞬间前倾踉跄 |
| `slide-01` | **slide** | verb | `MotionManner` | top_1000 | 接触底面不离开支撑面，依靠惯性在润滑表面顺畅滑动 | glide-01, roll-01, skid-01 | 接触面低摩擦力平滑连续位移 |
| `march-01` | **march** | verb | `MotionManner` | top_1000 | 高抬腿重落脚、固定均匀节拍、身躯挺直直线推进 | walk-01, wander-01, parade-01 | 节奏整齐、步幅固定、姿态挺拔前行 |
| `dash-01` | **dash** | verb | `MotionManner` | top_1000 | 静止或低速瞬间爆发最大加速度，短时间直达目标 | rush-01, sprint-01, jog-01 | 短距离爆发式极速直线冲刺 |
| `creep-01` | **creep** | verb | `MotionManner` | top_2000 | 身体蜷缩降低轮廓、每一步轻慢落脚消除振动 | sneak-01, crawl-01, tiptoe-01 | 压低身形、极轻脚步隐蔽缓慢移动 |
| `sneak-01` | **sneak** | verb | `MotionManner` | top_1000 | 借障碍物遮挡、不断观察他人视线盲区、悄声转移 | creep-01, hide-01, slip-01 | 刻意躲避视线与声响的潜行移动 |
| `stroll-01` | **stroll** | verb | `MotionManner` | top_2000 | 步态舒缓随意、双臂自然摆动、环顾四周景观 | rush-01, wander-01, walk-01 | 步伐从容放松、无时间压力的闲适散步 |
| `stagger-01` | **stagger** | verb | `MotionManner` | top_2000 | 重心不稳剧烈左右偏摆、步伐紊乱随时面临倒伏 | stumble-01, limp-01, teeter-01 | 身体左右摇晃、步履蹒跚难持平衡 |
| `limp-01` | **limp** | verb | `MotionManner` | top_2000 | 健侧腿落地时间长、患侧腿一触即离产生明显节拍不对称 | walk-01, stagger-01, hobble-01 | 单腿受力不均导致不对称单侧跛行 |
| `tiptoe-01` | **tiptoe** | verb | `MotionManner` | top_2000 | 脚后跟高高悬空提起、仅前脚掌着地、小心翼翼 | sneak-01, creep-01, stomp-01 | 仅脚尖着地、极力消除落脚声移动 |
| `glide-01` | **glide** | verb | `MotionManner` | top_2000 | 在空中或冰面无剧烈肢体摆动、平稳顺畅向前滑行 | slide-01, float-01, fly-01 | 无明显外显动力动作、平稳优雅顺滑移动 |
| `bounce-01` | **bounce** | verb | `MotionManner` | top_1000 | 冲击受阻表面瞬间受压压缩形变，随后释放弹性反弹升空 | rebound-01, leap-01, drop-01 | 碰撞弹性表面后向反方向弹起 |
| `leap-01` | **leap** | verb | `MotionManner` | top_1000 | 蓄力深蹲后剧烈爆发腾空、跨越巨大空间距离后落地 | jump-01, hop-01, plunge-01 | 双足或后肢强力蹬地腾空大跨度跳跃 |
| `hop-01` | **hop** | verb | `MotionManner` | top_1000 | 单脚支撑轻盈点地、起跳高度和跨度均较小而连续 | jump-01, leap-01, skip-01 | 单足或小动作连续小幅度轻跳 |
| `flee-01` | **flee** | verb | `MotionManner` | top_1000 | 运动方向绝对背离危险源、姿态慌乱、全力加速逃跑 | chase-01, escape-01, retreat-01 | 因面临危险背离危险源头仓皇逃窜 |
| `chase-01` | **chase** | verb | `MotionManner` | top_1000 | 跟随前方目标轨迹高速运动，极力缩短与前车间距 | flee-01, follow-01, pursue-01 | 以捕获前方移动目标为目的的跟随追踪 |
| `dodge-01` | **dodge** | verb | `MotionManner` | top_2000 | 迎面威胁逼近时，身体重心瞬间向侧方横移躲开弹道 | avoid-01, duck-01, block-01 | 在极短时间内侧身避开迎面来物 |
| `plunge-01` | **plunge** | verb | `MotionManner` | top_2000 | 从高处受重力加速急速向下俯冲穿入水体激起水花 | dive-01, drop-01, sink-01 | 头朝下急速坠入流体或深处 |
| `drift-01` | **drift** | verb | `MotionManner` | top_1000 | 无主动动力输出、轨迹完全顺应外界水流或气流缓慢漂动 | steer-01, float-01, glide-01 | 受流体或风力带动无自主方向漂移 |
| `stride-01` | **stride** | verb | `MotionManner` | top_2000 | 每一步跨度极大、动作干脆有力、头部平稳向前直视 | stroll-01, march-01, tiptoe-01 | 步幅极大、充满自信坚定大步前行 |
| `trudge-01` | **trudge** | verb | `MotionManner` | top_3000 | 每一步深陷地面、需费力拔脚、身体前倾沉重挪动 | stride-01, stroll-01, drag-01 | 脚步沉重吃力、克服泥雪阻力艰难前行 |
| `waddle-01` | **waddle** | verb | `MotionManner` | top_3000 | 由于双腿短或身体胖，每走一步躯干向承重腿一侧大幅倾斜 | stagger-01, walk-01, strut-01 | 短腿宽体左右大幅摇摆步态前行 |
| `borrow-01` | **borrow** | verb | `EventRolePerspective` | top_1000 | 物品从提供者流入自身手中，自身承诺未来原物归还 | lend-01, take-01, buy-01 | 临时物品转移：接收者视角，享有临时使用权且负有归还义务 |
| `lend-01` | **lend** | verb | `EventRolePerspective` | top_1000 | 物品从自身手中流向接收者，保留最终所有权并等待返还 | borrow-01, give-01, sell-01 | 临时物品转移：提供者视角，让渡临时使用权并期待归还 |
| `buy-01` | **buy** | verb | `EventRolePerspective` | top_500 | 货币流出自身账户/口袋，对应商品流入自身所有权归属 | sell-01, pay-01, rent-01 | 商业对价交换：支付货币获得物品或服务所有权 |
| `sell-01` | **sell** | verb | `EventRolePerspective` | top_500 | 商品流出自身库存移交买家，货币流入自身收益账户 | buy-01, give-01, trade-01 | 商业对价交换：让渡物品所有权换取等价货币 |
| `give-01` | **give** | verb | `EventRolePerspective` | top_500 | 物体从自身主动递交他人手中，完全放弃占有权无附带对价 | take-01, lend-01, receive-01 | 无偿单向让渡控制权与所有权：源头视角 |
| `take-01` | **take** | verb | `EventRolePerspective` | top_500 | 伸手触碰物体并将其从外在位置转移至自身随身控制 | give-01, receive-01, bring-01 | 主动抓取并纳入自身占有控制：发起方视角 |
| `send-01` | **send** | verb | `EventRolePerspective` | top_500 | 在本端打包交付信道，使其向远端目的地发生位移 | receive-01, bring-01, fetch-01 | 从本处向远端目标发射/传递物品或信息 |
| `receive-01` | **receive** | verb | `EventRolePerspective` | top_500 | 在接收端接住外来递送物，确认物权到达自身掌控 | send-01, give-01, accept-01 | 在终点处接纳远端送达的物品或信息 |
| `teach-01` | **teach** | verb | `EventRolePerspective` | top_500 | 自身示范讲解知识步骤，指导另一方逐步掌握该范式 | learn-01, instruct-01, demonstrate-01 | 知识与技能单向传授：施教者视角 |
| `learn-01` | **learn** | verb | `EventRolePerspective` | top_500 | 观察他人示范并亲自模仿练习，由不会变为能够独立完成 | teach-01, study-01, master-01 | 知识与技能吸收内化：学习者视角 |
| `hire-01` | **hire** | verb | `EventRolePerspective` | top_1000 | 雇主付出薪酬，换取雇员在特定时间段内提供劳动服务 | rent-01, fire-01, employ-01 | 支付对价雇佣劳动力或设备临时使用权 |
| `rent-01` | **rent** | verb | `EventRolePerspective` | top_1000 | 承租人定期支付费用获得房屋/车辆居住使用权，所有权归房东 | buy-01, borrow-01, lease-01 | 支付定期租金获得资产或不动产临时使用权 |
| `pass-01` | **pass** | verb | `EventRolePerspective` | top_500 | 从自身单手递出交给身边伸手接应的同伴，形成链式接力 | catch-01, throw-01, hand_over-01 | 接力式将手中物体转移给顺位相邻的下一人 |
| `catch-01` | **catch** | verb | `EventRolePerspective` | top_500 | 伸出双手在空中精准截停飞行物，五指并拢合死控制 | throw-01, drop-01, miss-01 | 用手拦截并锁死空中飞来的物体或动物 |
| `pay-01` | **pay** | verb | `EventRolePerspective` | top_500 | 自身向收款方交出纸币或扫码转移资金以结算账单 | charge-01, receive_payment-01, refund-01 | 履行金钱对价转移义务：付款方视角 |
| `earn-01` | **earn** | verb | `EventRolePerspective` | top_1000 | 付出时间劳动成果后，按约定获得资金流入收益 | spend-01, pay-01, win-01 | 通过劳动或提供价值获得报酬回报：收益方视角 |
| `supply-01` | **supply** | verb | `EventRolePerspective` | top_1000 | 仓库或源头源源不断将物资分发输出给多个消耗终端 | consume-01, demand-01, provide-01 | 作为资源源头持续向需求方输送物资储备 |
| `demand-01` | **demand** | verb | `EventRolePerspective` | top_1000 | 以高压态度向供给方施压，要求必须即刻交付特定成果 | request-01, supply-01, beg-01 | 作为需求端以强硬态度索要资源或行动 |
| `import-01` | **import** | verb | `EventRolePerspective` | top_2000 | 货物从外境穿过海关边界进入本土市场流转 | export-01, produce-01 | 跨越边界从外部管辖区采购引入商品或资源 |
| `export-01` | **export** | verb | `EventRolePerspective` | top_2000 | 本土产物装船穿过海关边界输送到海外买家 | import-01, domestic_trade-01 | 跨越边界向外部管辖区发送销售本国商品 |
| `push-01` | **push** | verb | `ForceDynamics` | top_500 | 手臂向前伸直发力，外力方向指向远离自身前方 | pull-01, press-01, drag-01 | 施加背离自身的正向推力使物体位移 |
| `pull-01` | **pull** | verb | `ForceDynamics` | top_500 | 握住手柄手臂向身体内收发力，外力方向朝向自身 | push-01, drag-01, tug-01 | 施加朝向自身的拉力使物体位移 |
| `drag-01` | **drag** | verb | `ForceDynamics` | top_1000 | 重物贴地产生大摩擦阻力，施力者身体后倾用力拖动 | carry-01, lift-01, pull-01 | 克服地面强摩擦力在表面强行拖拽重物 |
| `hold-01` | **hold** | verb | `ForceDynamics` | top_500 | 肌肉持续收缩抵抗重力或外力扰动，使物体相对位置不变 | release-01, drop-01, grab-01 | 施加持续约束力保持物体空间状态静止 |
| `release-01` | **release** | verb | `ForceDynamics` | top_1000 | 手指瞬间张开发力松开，被约束物体立即恢复自由轨迹 | hold-01, trap-01, clasp-01 | 解除外部约束力使物体受重力或弹力自由运动 |
| `block-01` | **block** | verb | `ForceDynamics` | top_1000 | 在运动轨迹正前方位插入不可逾越的实体障碍消除通路 | allow-01, open-01, clear-01 | 设置实体屏障强行截断通道与运动路径 |
| `resist-01` | **resist** | verb | `ForceDynamics` | top_1000 | 受到外力压迫时，主动输出相等或相抗衡的反作用力拒不退让 | yield-01, submit-01, give_in-01 | 施加反方向阻力对抗外来推力或侵蚀 |
| `press-01` | **press** | verb | `ForceDynamics` | top_500 | 指尖或手掌垂直向平面发力，使按键或弹性面下陷 | push-01, squeeze-01, touch-01 | 垂直于表面施加持续的向内挤压力 |
| `squeeze-01` | **squeeze** | verb | `ForceDynamics` | top_1000 | 手掌四周向内收拢挤压柔性物体，迫使其内部流体喷出 | press-01, stretch-01, crush-01 | 从多侧或对立两方向向内对物体施加压缩力 |
| `drop-01` | **drop** | verb | `ForceDynamics` | top_500 | 托举力瞬间归零，物体沿重力加速度方向竖直向下坠落 | lift-01, hold-01, throw-01 | 停止向上托举外力，使物体受重力自然坠落 |
| `carry-01` | **carry** | verb | `ForceDynamics` | top_500 | 将重物承载在身，自身移动时物体与自身保持相对静止 | drag-01, push-01, drop-01 | 持续托举物体克服重力并伴随自身整体位移 |
| `lift-01` | **lift** | verb | `ForceDynamics` | top_500 | 向上发力使物体脱离地面支撑面，垂直坐标单调上升 | lower-01, drop-01, hold-01 | 施加向上垂直拉力克服重力提升物体高度 |
| `grab-01` | **grab** | verb | `ForceDynamics` | top_500 | 手臂迅捷出击、五指在极短时间内合拢紧扣物体表面 | touch-01, hold-01, release-01 | 快速伸手并拢五指瞬间锁死物体控制权 |
| `crush-01` | **crush** | verb | `ForceDynamics` | top_1000 | 过载压力迫使物体外部结构崩塌扁平化，无法复原 | squeeze-01, press-01, flatten-01 | 施加过量压力破坏物体原有立体几何形态 |
| `stretch-01` | **stretch** | verb | `ForceDynamics` | top_1000 | 两手向外拉拽，弹性材质长度增加截面变窄张力增大 | compress-01, squeeze-01, relax-01 | 向两端施加背离方向拉力使弹性材料延伸变长 |
| `twist-01` | **twist** | verb | `ForceDynamics` | top_1000 | 两端受相反方向旋转力矩，柱状物沿轴心产生螺旋形变 | bend-01, straighten-01, rotate-01 | 施加相反旋转扭矩使物体沿轴线旋转受扭 |
| `prop_up-01` | **prop up** | verb | `ForceDynamics` | top_2000 | 在重力倾倒方向一侧插入斜撑支柱，提供平衡反作用力 | knock_down-01, support-01 | 在下方设置斜向支撑点防止倾斜倒塌 |
| `shove-01` | **shove** | verb | `ForceDynamics` | top_2000 | 瞬间爆发粗暴推力，受力主体突遭重推跌撞后退 | push-01, nudge-01, punch-01 | 施加粗暴突然的大推力使人或物失衡位移 |
| `tug-01` | **tug** | verb | `ForceDynamics` | top_2000 | 施加单次或多次短促爆发性拉力，绳索瞬间张紧 | pull-01, drag-01, yank-01 | 短促用力拉扯绳索或衣物 |
| `clasp-01` | **clasp** | verb | `ForceDynamics` | top_2000 | 两端环扣相互咬合锁死，形成封闭闭合环 | unclasp-01, hold-01, grip-01 | 双手或卡扣紧密扣合固定不放 |
| `wedge-01` | **wedge** | verb | `ForceDynamics` | top_2000 | 斜面物体强行嵌入两壁缝隙，产生侧向挤压摩擦固定不动 | loosen-01, insert-01, remove-01 | 将楔形物强行塞入狭小缝隙形成摩擦卡死 |
| `loosen-01` | **loosen** | verb | `ForceDynamics` | top_1000 | 旋转螺丝或解开系带，消除原本紧贴的压迫力 | tighten-01, fasten-01 | 减小紧固约束力使物体获得活动余量 |
| `tighten-01` | **tighten** | verb | `ForceDynamics` | top_1000 | 顺时针旋拧或用力抽紧绳带，使连接处达到无缝锁死 | loosen-01, release-01 | 增大约束紧固力消除所有晃动间隙 |
| `withstand-01` | **withstand** | verb | `ForceDynamics` | top_2000 | 强风或撞击持续施加破坏力，防线结构无破损岿然不动 | yield-01, collapse-01, surrender-01 | 持续承受强大外力冲击而结构保持完好不垮塌 |
| `yield-01` | **yield** | verb | `ForceDynamics` | top_1000 | 外力超过自身承受上限，支撑结构弯曲变形放弃阻挡 | withstand-01, resist-01, hold_firm-01 | 承受不住外力压迫而屈服变形让路 |

## cognitive_change (20 义项)

| ID | Lemma | POS | 微世界 | 词频 | 核心经验不变量 | 最近邻对比 | 释义摘要 |
|---|---|---|---|---|---|---|---|
| `notice-01` | **notice** | verb | `InformationUpdate` | top_500 | 视线扫过背景时被突出线索捕获，注意力焦点瞬间跳转 | realize-01, overlook-01, see-01 | 外界信息偶然进入视觉/感知视野引发注意 |
| `realize-01` | **realize** | verb | `InformationUpdate` | top_500 | 多条已有线索在脑中串联，瞬间推导领悟出隐藏的核心逻辑 | notice-01, remember-01, discover-01 | 经由线索拼接在脑中推理领悟出事实真相 |
| `discover-01` | **discover** | verb | `InformationUpdate` | top_500 | 揭开隐藏表面或探索新区域，首次接触未曾知晓的客观存在 | invent-01, realize-01, search-01 | 经由主动探索首次发现先前未知的事物或规律 |
| `recognize-01` | **recognize** | verb | `InformationUpdate` | top_500 | 提取长期记忆特征库，与眼前目标特征100%对齐唤起身份 | identify-01, confuse-01, forget-01 | 将当前所见与已有记忆图式匹配确认身份 |
| `overlook-01` | **overlook** | verb | `InformationUpdate` | top_1000 | 重要细节清晰位于视野中，但观察者视线直接跳过遗漏 | notice-01, spot-01, ignore-01 | 关键信息明明在场但因注意力疏漏未曾感知 |
| `ignore-01` | **ignore** | verb | `InformationUpdate` | top_500 | 信息已成功进入意识，但主体主动转头或维持原行为不作反应 | overlook-01, notice-01, heed-01 | 明确感知到信息但主观选择刻意不予理会 |
| `spot-01` | **spot** | verb | `InformationUpdate` | top_1000 | 在海量混乱背景噪点中，目光如探针般瞬间锁定隐藏目标 | miss-01, search-01, notice-01 | 在复杂嘈杂背景干扰中精准定位微小目标 |
| `reveal-01` | **reveal** | verb | `InformationUpdate` | top_500 | 揭开遮盖布幔或展示证据，使秘密信息瞬间转为公共已知 | hide-01, conceal-01, disclose-01 | 移开遮挡物使原本隐藏的信息对全场可见 |
| `hide-01` | **hide** | verb | `InformationUpdate` | top_500 | 将物体置于掩体后方或使用迷彩，阻断他人视线传播路径 | reveal-01, show-01, seek-01 | 设置物理遮挡或伪装使目标不可见 |
| `detect-01` | **detect** | verb | `InformationUpdate` | top_1000 | 微弱不可见的蛛丝马迹经仪器放大或警觉分析被确凿捕获 | miss-01, overlook-01, find-01 | 借助微弱信号或敏感工具捕捉隐蔽线索 |
| `examine-01` | **examine** | verb | `InformationUpdate` | top_500 | 靠近目标、借助放大镜逐寸巡视扫描，寻找异常线索 | glance-01, inspect-01, scan-01 | 近距离系统性搜寻检查物体细节特征 |
| `identify-01` | **identify** | verb | `InformationUpdate` | top_500 | 核对独有特征（指纹/标号），从混杂候选中唯一确定其身份 | confuse-01, recognize-01, distinguish-01 | 在多个候选中精准判定目标属于何物或何人 |
| `distinguish-01` | **distinguish** | verb | `InformationUpdate` | top_1000 | 并置两物深入比对，挑出区分两者范畴边界的微小异同 | confuse-01, differentiate-01, compare-01 | 找出两个高度相似对象之间的决定性差异判据 |
| `confuse-01` | **confuse** | verb | `InformationUpdate` | top_1000 | 两物特征重叠度高，脑中特征映射发生错配误判 | distinguish-01, clarify-01, identify-01 | 因线索混杂无法区分两者的身份归属产生混淆 |
| `recall-01` | **recall** | verb | `InformationUpdate` | top_1000 | 脑中搜寻索引，使沉睡的过去画面重新在意识中清晰浮现 | forget-01, remember-01, recognize-01 | 从长期记忆库中检索提取先前经验到工作记忆 |
| `forget-01` | **forget** | verb | `InformationUpdate` | top_500 | 试图检索记忆时线索断裂，脑中对应区域呈现空白 | remember-01, recall-01, memorize-01 | 记忆线索断裂无法在意识中提取对应经验信息 |
| `misunderstand-01` | **misunderstand** | verb | `InformationUpdate` | top_2000 | 听取言语后在大脑中建立起与事实发生偏差的错误认知图式 | understand-01, clarify-01, misinterpret-01 | 接收到信息但构建了与原意相反的错误心智模型 |
| `clarify-01` | **clarify** | verb | `InformationUpdate` | top_1000 | 出示清晰图表或定义，使原本混乱的理解瞬间条理分明 | confuse-01, obscure-01, explain-01 | 补充关键信息判据消除原有歧义和认知模糊 |
| `suspect-01` | **suspect** | verb | `InformationUpdate` | top_1000 | 根据局部可疑线索，在脑中心智模型中预设某种假说 | confirm-01, know-01, doubt-01 | 在证据不全时基于蛛丝马迹倾向于假定某种可能 |
| `confirm-01` | **confirm** | verb | `InformationUpdate` | top_500 | 决定性硬证据出现，心智模型中的概率假说收敛为100%确定事实 | suspect-01, deny-01, verify-01 | 获取决定性铁证彻底排除其他假说锁定事实 |

## mental_state (19 义项)

| ID | Lemma | POS | 微世界 | 词频 | 核心经验不变量 | 最近邻对比 | 释义摘要 |
|---|---|---|---|---|---|---|---|
| `reluctant-01` | **reluctant** | adjective | `GoalConflict` | top_1000 | 内心存在负面意愿抗拒，但受外部压力不得不慢吞吞动作 | willing-01, eager-01, hesitant-01 | 愿望与外部要求冲突导致的不情愿执行与行为迟滞 |
| `willing-01` | **willing** | adjective | `GoalConflict` | top_500 | 面对提议没有任何内部抗拒阻力，爽快点头同意接受 | reluctant-01, unwilling-01, eager-01 | 内心毫无阻力欣然接受并准备执行 |
| `eager-01` | **eager** | adjective | `GoalConflict` | top_1000 | 内驱力极高、甚至身体抢跑向前、渴望立即开始享受过程 | reluctant-01, willing-01, indifferent-01 | 愿望极其强烈迫不及待渴望启动行动 |
| `relieved-01` | **relieved** | adjective | `AppraisalShift` | top_1000 | 紧绷防备的身体瞬间松弛长舒一口气，危机警报解除 | anxious-01, disappointed-01, grateful-01 | 预期的巨大危机或负面结果未发生带来的如释重负 |
| `disappointed-01` | **disappointed** | adjective | `AppraisalShift` | top_1000 | 高涨期待落空，视线向下垂落嘴角下弯充满遗憾 | satisfied-01, proud-01, surprised-01 | 实际结果远低于先前高预期带来的落差与失落 |
| `proud-01` | **proud** | adjective | `AppraisalShift` | top_500 | 胸膛挺起、仰起头面带自信微笑、向众人展示荣誉 | ashamed-01, embarrassed-01, humble-01 | 自身或亲近者取得卓越成就带来的自我肯定与光荣 |
| `embarrassed-01` | **embarrassed** | adjective | `AppraisalShift` | top_1000 | 在众人目光聚焦下脸红、低头用手遮挡面部试图退避 | proud-01, confident-01, guilty-01 | 在公众注视下发生失误暴露尴尬带来的局促不安 |
| `surprised-01` | **surprised** | adjective | `AppraisalShift` | top_500 | 双眼睁大、嘴巴张开成圆形、动作骤停凝固 | shocked-01, expecting-01, indifferent-01 | 出现完全超出日常经验预期的突发事件带来的震颤 |
| `regret-01` | **regret** | verb | `AppraisalShift` | top_1000 | 双手抱头回想过去错误时刻，懊悔未能选择另一条路径 | rejoice-01, satisfy-01, repent-01 | 对过去自身作出的错误抉择产生悔恨与自责 |
| `satisfied-01` | **satisfied** | adjective | `AppraisalShift` | top_1000 | 仔细核对清单各项全部达标后，露出惬意点头赞许神情 | disappointed-01, frustrated-01, content-01 | 实际产出完全符合甚至略超需求标准的心满意足 |
| `upset-01` | **upset** | adjective | `AppraisalShift` | top_500 | 平静节奏被打破，眉头紧锁、焦躁踱步无法安坐 | calm-01, relieved-01, angry-01 | 正常秩序或平静被突发事件打乱引发的烦躁不安 |
| `nervous-01` | **nervous** | adjective | `AppraisalShift` | top_1000 | 等待叫号上台前手心出汗、指尖微颤、反复吞咽口水 | calm-01, confident-01, relaxed-01 | 面对即将到来的高压评估产生的心跳紧绷与焦虑 |
| `grateful-01` | **grateful** | adjective | `AppraisalShift` | top_1000 | 双手握住施援者的手真诚道谢，内心渴望寻找机会回馈 | ungrateful-01, indebted-01, relieved-01 | 感知到他人无私帮助后产生的由衷感恩与回馈心愿 |
| `guilty-01` | **guilty** | adjective | `AppraisalShift` | top_1000 | 看到受损现场或受害者，不敢直视对方眼睛，内心愧疚 | innocent-01, proud-01, shameless-01 | 意识到自身违规或伤害他人产生的内心道德重负 |
| `jealous-01` | **jealous** | adjective | `AppraisalShift` | top_2000 | 侧目紧盯同伴手中的奖赏，面色阴沉握紧拳头 | envious-01, generous-01, admiring-01 | 见他人拥有自身渴望之物时产生的酸楚与排他敌意 |
| `envious-01` | **envious** | adjective | `AppraisalShift` | top_2000 | 羡慕注视他人的优秀技能，眼中闪烁向往与渴望光芒 | jealous-01, admiring-01 | 单纯羡慕并渴望自身也能拥有他人具备的优越特质 |
| `confident-01` | **confident** | adjective | `AppraisalShift` | top_1000 | 站姿挺拔目光如炬，面对难题毫无惧色从容出手 | nervous-01, doubtful-01, hesitant-01 | 对自身能力能否胜任挑战持有坚定确凿的信念 |
| `frustrated-01` | **frustrated** | adjective | `AppraisalShift` | top_1000 | 反复尝试均告失败，双手抱头或砸向桌面表达无力愤怒 | satisfied-01, patient-01, disappointed-01 | 连续多次尝试均被不可控障碍阻断产生的挫败愤怒 |
| `trust-01` | **trust** | verb | `SocialContract` | top_500 | 将贵重钥匙直接交予对方，不派人监视亦放心其处置 | doubt-01, suspect-01, betray-01 | 在缺乏强制抵押约束下相信对方会忠实履行约定 |

## intentional_behavior (18 义项)

| ID | Lemma | POS | 微世界 | 词频 | 核心经验不变量 | 最近邻对比 | 释义摘要 |
|---|---|---|---|---|---|---|---|
| `hesitant-01` | **hesitant** | adjective | `GoalConflict` | top_1000 | 由于预估风险或缺乏信息，在行动触发点前后反复停顿迟疑 | decisive-01, reluctant-01, confident-01 | 因不确定性或顾虑而在启动行动前徘徊停顿 |
| `refuse-01` | **refuse** | verb | `GoalConflict` | top_500 | 面对递来的要求坚定摇头摆手并后退，坚决不接纳 | accept-01, agree-01, decline-01 | 面对他人请求明确表达排斥并采取阻断行动拒绝 |
| `avoid-01` | **avoid** | verb | `GoalConflict` | top_500 | 提前观察到前方潜在危险或麻烦人物，提前转向绕道而行 | confront-01, encounter-01, evade-01 | 预判到负面后果主动调整路径远离潜在冲突源 |
| `insist-01` | **insist** | verb | `GoalConflict` | top_1000 | 面对外界一致劝阻，依然重复声明自身既定意向坚决执行 | compromise-01, give_in-01, yield-01 | 面对阻力或反对意见依然维持原有主张毫不退让 |
| `quit-01` | **quit** | verb | `GoalConflict` | top_1000 | 放下手中工具并转身离开工作台，永久停止后续操作 | continue-01, persist-01, finish-01 | 在遭遇困难或成本过高时主动终止既定目标任务 |
| `accept-01` | **accept** | verb | `GoalConflict` | top_500 | 伸出双手接过物品或协议并签署确认，确认合作成立 | refuse-01, reject-01, decline-01 | 克服初始顾虑欣然接纳既定现实或他人提议 |
| `dare-01` | **dare** | verb | `GoalConflict` | top_1000 | 深吸一口气压抑心跳，勇敢迈出跨越危险边界的一步 | cower-01, shrink-01, hesitate-01 | 克服恐惧心理冒险执行高风险挑战动作 |
| `struggle-01` | **struggle** | verb | `GoalConflict` | top_1000 | 用尽全力与持续的强阻力拉锯角力，缓慢艰苦推进 | succeed_easily-01, surrender-01, glide-01 | 在目标与巨大阻力之间艰难对抗维持推进 |
| `compromise-01` | **compromise** | verb | `GoalConflict` | top_2000 | 双方各自从极限要求线上后撤一段距离，在中点握手 | insist-01, dominate-01, deadlock-01 | 双方各自让步部分诉求达成中间平衡方案 |
| `resist_temptation-01` | **resist** | verb | `GoalConflict` | top_1000 | 收回伸向诱人物品的手，强迫视线移开以守住底线 | indulge-01, succumb-01, give_in-01 | 抵御眼前即时快感诱惑以维持长远目标 |
| `give_in-01` | **give in** | verb | `GoalConflict` | top_1000 | 防线被长时间攻势瓦解，叹气后垂下双手顺从对方要求 | resist-01, withstand-01, insist-01 | 在持续施压或诱惑下耗尽抵抗意志妥协顺从 |
| `postpone-01` | **postpone** | verb | `GoalConflict` | top_2000 | 在日历上将今日事项划掉并平移重新标注到下周日期 | expedite-01, advance-01, cancel-01 | 主动将原定行动执行时点推迟到未来某一时刻 |
| `rush_decision-01` | **rush** | verb | `GoalConflict` | top_1000 | 在时间紧迫警报下未仔细阅读条款便匆忙按下确认键 | deliberate-01, hesitate-01, pause-01 | 在信息未收集齐全前仓促轻率做出决定 |
| `hesitate-01` | **hesitate** | verb | `GoalConflict` | top_1000 | 手指在两个选项按钮之间来回晃动悬空，迟迟不按下 | decide_instantly-01, act-01 | 在两种选择之间反复权衡无法果断下定决心 |
| `compel-01` | **compel** | verb | `GoalConflict` | top_2000 | 周围环境堵死所有退路，主体别无选择只能顺应单行道 | volunteer-01, allow-01, dissuade-01 | 强大外部力量迫使主体别无选择只能执行 |
| `volunteer-01` | **volunteer** | verb | `GoalConflict` | top_1000 | 当组织寻求人手时，无强迫下主动第一个举起手出列 | compel-01, refuse-01, evade-01 | 在无外部强迫下主动举手承担额外责任 |
| `withdraw-01` | **withdraw** | verb | `GoalConflict` | top_1000 | 收拾属于自身的个人物品，走出圈子回到独立观察位置 | join-01, participate-01, engage-01 | 从已介入的局势或组织中主动抽身退出 |
| `obey-01` | **obey** | verb | `SocialContract` | top_1000 | 听到口令后立即做出标准规定动作，无个人擅自变更 | disobey-01, defy-01, rebel-01 | 顺从权威指令，抑制个人偏好严格执行命令 |

## causal_logic (11 义项)

| ID | Lemma | POS | 微世界 | 词频 | 核心经验不变量 | 最近邻对比 | 释义摘要 |
|---|---|---|---|---|---|---|---|
| `owe-01` | **owe** | verb | `SocialContract` | top_1000 | 账本记录赤字标记，在还清前时刻背负必须向对方给付的约束 | repay-01, lend-01, forgive_debt-01 | 因先前接受好处或借用而对他人承担法定或道德给付义务 |
| `steal-01` | **steal** | verb | `SocialContract` | top_1000 | 避开主人视线悄悄取走属于他人的物品塞入自身口袋 | borrow-01, buy-01, rob-01 | 未经许可违背规则秘密转移他人合法财产所有权 |
| `permit-01` | **permit** | verb | `SocialContract` | top_1000 | 闸机在出示许可证后升起栏杆，原本锁死的红线转为绿灯 | forbid-01, allow-01, ban-01 | 权威主体解除通行禁令，向他人颁发合法行动许可证 |
| `forbid-01` | **forbid** | verb | `SocialContract` | top_1000 | 设立醒目红叉禁止标志，并声明违规者将遭受严厉惩处 | permit-01, allow-01, prescribe-01 | 权威主体颁布禁令，严禁任何人逾越规则红线 |
| `allow-01` | **allow** | verb | `SocialContract` | top_500 | 门保持敞开未加锁，旁观者点头未进行任何阻拦 | forbid-01, block-01, permit-01 | 不设物理或规则阻碍，默许或准许他人执行某项行为 |
| `belong-01` | **belong** | verb | `SocialContract` | top_500 | 物品上刻有所有者专属姓名标签，其使用权归该主体独占 | own-01, possess-01, alien-01 | 物体与特定主体之间建立合法的排他性归属关系 |
| `fair-01` | **fair** | adjective | `SocialContract` | top_500 | 蛋糕被等分为完全相同大小，每人按均等规则抽取无偏袒 | unfair-01, biased-01, equal-01 | 规则制定与资源分配对所有参与者一视同仁无偏私 |
| `cheat-01` | **cheat** | verb | `SocialContract` | top_1000 | 在裁判视线盲区偷偷藏牌或篡改分数，破坏公认公平线 | play_fair-01, follow_rules-01, deceive-01 | 秘密破坏公认规则以谋取不对称不正当竞争优势 |
| `reward-01` | **reward** | verb | `SocialContract` | top_1000 | 完成艰巨任务后，从权威手中接获金牌、奖状或丰厚酬劳 | punish-01, penalize-01, compensate-01 | 因主体作出杰出贡献而授予正向激励奖品 |
| `punish-01` | **punish** | verb | `SocialContract` | top_1000 | 违规行为被抓现行，被剥夺自由禁足或没收关键资产 | reward-01, forgive-01, pardon-01 | 因主体违反既定规则而施加负向剥夺或惩戒措施 |
| `betray-01` | **betray** | verb | `SocialContract` | top_1000 | 表面上与同伴握手结盟，暗中将防线密匙递给对手 | trust-01, defend-01, support-01 | 违背彼此信任，在暗中向敌对阵营出卖对方核心利益 |

## discourse_function (2 义项)

| ID | Lemma | POS | 微世界 | 词频 | 核心经验不变量 | 最近邻对比 | 释义摘要 |
|---|---|---|---|---|---|---|---|
| `promise-01` | **promise** | verb | `SocialContract` | top_500 | 举手立誓或拉钩承诺，将自身的未来行动牢固锁定于承诺条款 | break_promise-01, declare-01, guarantee-01 | 通过言语宣告自愿设定未来的强约束性给付义务 |
| `forgive-01` | **forgive** | verb | `SocialContract` | top_1000 | 撕毁债务借条或微笑着握住致歉者的手，宣告过错归零 | punish-01, blame-01, resent-01 | 主动放弃追究他人过错造成的伤害与赔偿诉求 |
