class_name Codex

# КОДЕКС (GAMEDESIGN §30) — статьи для меню «Кодекс», заменившего слайды
# Справки. Данные держим ОТДЕЛЬНО от menu.gd: тот и без этого 3300+ строк, а
# текст статей — самая объёмная и самая часто правимая часть игры.
#
# Каждая статья: раздел (sec), id, заголовок RU/EN, идентификатор картинки
# (собирается в menu.gd::_codex_figure) и текст RU/EN. Тексты — многострочные
# литералы с настоящими переводами строк: никаких \n-эскейпов, чтобы не
# ловить двойное экранирование при правках через инструменты.
#
# Порядок разделов и статей внутри раздела = порядок чтения. Первый раздел
# намеренно «Начни отсюда»: игрок, открывший кодекс впервые, должен получить
# работающую картину за три статьи.

const SECTIONS := [
	{"id": "start",    "title": "Начни отсюда",   "title_en": "Start here",         "color": Color(0.55, 1.00, 0.70)},
	{"id": "light",    "title": "Свет и Воля",    "title_en": "Light and Will",     "color": Color(1.00, 0.86, 0.35)},
	{"id": "skills",   "title": "Навыки",         "title_en": "Skills",             "color": Color(0.45, 0.85, 1.00)},
	{"id": "maze",     "title": "Лабиринт",       "title_en": "The Maze",           "color": Color(0.75, 0.65, 1.00)},
	{"id": "biomes",   "title": "Биомы",          "title_en": "Biomes",             "color": Color(0.40, 0.95, 0.85)},
	{"id": "enemies",  "title": "Враги и гости",  "title_en": "Enemies & Guests",   "color": Color(1.00, 0.45, 0.40)},
	{"id": "bosses",   "title": "Боссы",          "title_en": "Bosses",             "color": Color(1.00, 0.35, 0.60)},
	{"id": "modes",    "title": "Режимы",         "title_en": "Modes",              "color": Color(0.95, 0.70, 0.30)},
	{"id": "progress", "title": "Прогресс",       "title_en": "Progression",        "color": Color(0.65, 0.85, 1.00)},
	{"id": "versions", "title": "Что нового",     "title_en": "What's new",         "color": Color(0.60, 0.68, 0.85)},
]

const ARTICLES := [
{
	"sec": "start", "id": "goal", "fig": "goal",
	"title": "Цель игры", "title_en": "The goal",
	"body": """Ты — огонёк света в тёмном лабиринте. У каждого уровня одна задача: собрать все осколки света, дождаться, пока откроется ПОРТАЛ-выход, и уйти в него.

Портал заперт, пока на уровне остаётся хотя бы один несобранный осколок. Видно его издалека — большая воронка со втягивающимися частицами, её не спутать ни с чем другим. Пока он заперт, зайти в него нельзя: игра просто скажет, сколько осколков осталось.

Мешают тебе две вещи. Первая — тьма: твой Свет тает, пока ты двигаешься, и если погаснет совсем, ты теряешь жизнь. Вторая — враги: контакт с ними гасит часть Света, а некоторые пьют ещё и Волю.

Всё остальное в этом кодексе — про то, как управлять этими двумя угрозами.""",
	"body_en": """You are a spark of light in a dark maze. Every level has one task: collect all the shards of light, wait for the exit PORTAL to unseal, and step through it.

The portal stays sealed while even one shard remains uncollected. It is visible from afar — a large funnel drawing particles inward, impossible to mistake for anything else. While sealed you cannot enter: the game simply tells you how many shards are left.

Two things stand in your way. First, the dark: your Light fades as you move, and if it goes out completely you lose a life. Second, enemies: contact drains some Light, and a few of them drink your Will as well.

Everything else in this codex is about managing those two threats.""",
},
{
	"sec": "start", "id": "controls", "fig": "controls",
	"title": "Управление", "title_en": "Controls",
	"body": """ДВИЖЕНИЕ — стрелки или WASD. Отсчёт времени и все процессы уровня запускаются с твоего первого шага, так что осмотреться можно спокойно.

СТОЙКА СВЕТА — Z и X, либо колесо мыши. Это главная ручка выживания, о ней отдельная статья в разделе «Свет и Воля».

НАВЫКИ — по одной клавише на каждый: Q вспышка, Shift или Space рывок, R тление, E сонар, C щит, G искра-проводник, F озарение, B пульс, H апекс, T мираж, Y разлом, V хронос, N призыв. Часть открывается за SP, часть — за победы над боссами.

ПАУЗА — P или Esc. Перезапуск уровня есть только в меню паузы и на экране результатов: горячих клавиш рестарта нет намеренно, чтобы случайное нажатие не стёрло удачный забег.""",
	"body_en": """MOVEMENT — arrow keys or WASD. The timer and every level process start with your first step, so you can look around first.

LIGHT STANCE — Z and X, or the mouse wheel. This is your main survival dial; it has its own article in the «Light and Will» section.

SKILLS — one key each: Q flash, Shift or Space dash, R smother, E sonar, C shield, G guide spark, F reveal, B pulse, H apex, T mirage, Y breach, V chrono, N summon. Some unlock for SP, others by beating bosses.

PAUSE — P or Esc. Restarting a level is only possible from the pause menu or the results screen: there are deliberately no restart hotkeys, so a stray keypress cannot wipe a good run.""",
},
{
	"sec": "start", "id": "first_run", "fig": "first_run",
	"title": "Первые пять минут", "title_en": "Your first five minutes",
	"body": """Если читать больше нечего, вот короткий план на первый уровень.

1. Иди и собирай осколки. Их количество видно в правом верхнем углу: «Осколки: 2 / 5».

2. Держи Свет выше трети шкалы. Когда он падает низко, полоса резко краснеет и по краям экрана появляется красная кромка — это значит «ищи станцию».

3. Синие кристаллы-станции восполняют Свет глотком и дают Волю. Пока стоишь рядом, Свет НЕ тает вовсе — станция это укрытие, а не только заправка.

4. Увидел врага — не геройствуй. Рывок сквозь него бьёт его, а не тебя; вспышка в упор тоже наносит урон; тление прячет тебя, пока он не потерял след.

5. Собрал всё — иди в портал.

Первые уровни намеренно щедрые: лабиринты небольшие, врагов мало. Сложность растянута так, что уровень 40 примерно равен тому, чем когда-то был уровень 20.""",
	"body_en": """If you read nothing else, here is a short plan for level one.

1. Walk and collect shards. The count sits in the top-right corner: «Shards: 2 / 5».

2. Keep Light above a third of the bar. When it drops low the bar turns sharply red and a red rim appears at the screen edges — that means «find a station».

3. Blue crystal stations refill Light in one sip and grant Will. While you stand next to one, Light does NOT drain at all — a station is shelter, not just a fuel pump.

4. Spotted an enemy? Don't play hero. A dash through it damages it, not you; a point-blank flash also hurts it; smother hides you until it loses your trail.

5. Collected everything? Head for the portal.

The early levels are deliberately generous: small mazes, few enemies. The difficulty curve is stretched so that level 40 is roughly what level 20 used to be.""",
},
{
	"sec": "light", "id": "two_bars", "fig": "bars",
	"title": "Свет и Воля — два разных ресурса", "title_en": "Light and Will — two resources",
	"body": """Это самое важное различие в игре, и его легко перепутать.

СВЕТ (жёлтая полоса) — твоя ЖИЗНЬ. Тает, пока ты двигаешься во тьме, и от ударов врагов. Погас совсем — минус жизнь. Восполняется глотком у станции и с осколков. Рядом со станцией не тает вовсе.

ВОЛЯ (циановая полоса) — ТОПЛИВО НАВЫКОВ. Копится сама собой (пустой пул наполняется примерно за 36 секунд), плюс с каждого осколка и с каждого глотка на станции. Тьма её не трогает — Волю нельзя потерять от того, что ты долго идёшь.

Зачем так сделано: раньше это был один пул, и получалось противоестественно — чем активнее ты играешь, тем быстрее умираешь. Теперь навыки не приближают смерть: их ограничивает только собственный запас Воли и кулдауны.""",
	"body_en": """This is the most important distinction in the game, and an easy one to confuse.

LIGHT (yellow bar) is your LIFE. It fades as you move through the dark and when enemies hit you. Out completely — you lose a life. It refills with a sip at a station and from shards. Next to a station it does not drain at all.

WILL (cyan bar) is SKILL FUEL. It builds on its own (an empty pool fills in about 36 seconds), plus a little from every shard and every station sip. The dark never touches it — you cannot lose Will just by walking a long way.

Why it works this way: it used to be a single pool, which was perverse — the more actively you played, the faster you died. Now skills never bring death closer: they are limited only by your Will and their cooldowns.""",
},
{
	"sec": "light", "id": "stance", "fig": "stance",
	"title": "Стойка света — главная ручка", "title_en": "Light stance — the main dial",
	"body": """Свет — не таймер, а ВАЛЮТА, которой ты платишь за возможность видеть. Стойка — то, как ты этой валютой распоряжаешься. Переключается Z и X или колесом мыши, ничего не стоит и работает постоянно.

ТУСКЛЫЙ — расход Света падает до 0.45 от обычного, враги замечают тебя почти вдвое хуже. Взамен радиус света примерно вдвое меньше — идёшь почти вслепую и на 12% медленнее. Режим экономии и скрытности.

РОВНЫЙ — базовые значения, ничего не меняется.

ЯРКИЙ — радиус света в 1.6 раза больше: раньше находишь осколки, портал, развилки и врагов. Цена высокая: Свет горит в 2.4 раза быстрее, а враги видят тебя в 1.75 раза дальше.

В HUD рядом с полосами стоит индикатор: три сегмента и текущий множитель расхода — цену решения видно сразу, гадать не нужно.

ЭТО НЕ ТЛЕНИЕ. Тление (R) — короткий рывок в невидимость за Волю и с кулдауном, аварийная кнопка. Стойка — режим, в котором ты живёшь между станциями. Тление сильнее любой стойки и перебивает её, так что аварийный побег работает и из Яркой.""",
	"body_en": """Light is not a timer — it is CURRENCY you spend on being able to see. The stance is how you spend it. Switch with Z and X or the mouse wheel; it is free and always on.

DIM — Light drain drops to 0.45 of normal and enemies notice you almost twice as poorly. In exchange your light radius is about halved — you walk near-blind and 12% slower. The economy and stealth mode.

EVEN — baseline values, nothing changes.

BRIGHT — light radius 1.6x larger: you find shards, the portal, junctions and enemies sooner. The price is steep: Light burns 2.4x faster and enemies see you 1.75x farther.

The HUD carries an indicator next to the bars: three segments and the current drain multiplier — the cost of the decision is visible, no guessing.

THIS IS NOT SMOTHER. Smother (R) is a short burst of invisibility for Will and on cooldown — the panic button. The stance is how you live between stations. Smother is stronger than any stance and overrides it, so the emergency escape works out of Bright too.""",
},
{
	"sec": "light", "id": "visibility", "fig": "visibility",
	"title": "Заметность: свет = уязвимость", "title_en": "Visibility: light is vulnerability",
	"body": """Враги видят тебя не на фиксированной дистанции, а пропорционально тому, насколько ты ярок. Базовый радиус обнаружения умножается на твою заметность, и она меняется постоянно.

Что повышает заметность: Яркая стойка (×1.75), активная вспышка (до +35%), несомый Накал в режиме забега (до +45%). Всё это складывается, потолок — 2.2.

Что понижает: Тусклая стойка (×0.55) и особенно Тление (0.2 — тебя почти нет).

Практический вывод: вспышка это не бесплатная разведка. Ты осветил коридор — и коридор увидел тебя. То же с Накалом: чем больше несёшь, тем ты жирнее как цель. Именно поэтому Тление существует как отдельный навык, а не как «просто потуши свет».

Важная деталь: враг должен ещё и ВИДЕТЬ тебя по прямой. Стена между вами обнуляет обнаружение независимо от того, насколько ты ярок.""",
	"body_en": """Enemies do not spot you at a fixed distance — they spot you in proportion to how bright you are. Their base detection radius is multiplied by your visibility, and that value changes constantly.

What raises visibility: the Bright stance (x1.75), an active flash (up to +35%), carried ember in run mode (up to +45%). These stack, capped at 2.2.

What lowers it: the Dim stance (x0.55) and especially Smother (0.2 — you are barely there).

The practical lesson: a flash is not free reconnaissance. You lit the corridor, and the corridor saw you. Same with ember: the more you carry, the fatter a target you are. This is exactly why Smother exists as its own skill rather than as «just turn the light down».

One important detail: an enemy must also have LINE OF SIGHT. A wall between you nullifies detection no matter how bright you are.""",
},
{
	"sec": "skills", "id": "base", "fig": "skills_base",
	"title": "Базовые навыки", "title_en": "Base skills",
	"body": """Три навыка есть у тебя всегда, с первого уровня и в любом режиме.

ВСПЫШКА (Q) — резко расширяет свет вокруг. В упор наносит урон врагу. Главный инструмент разведки и главный способ выдать себя.

РЫВОК (Shift или Space) — короткий бросок по направлению взгляда. Спасает из окружения, проносит СКВОЗЬ врага (это таран: урон ему, не тебе) и — единственный способ пересечь яму-провал.

ТЛЕНИЕ (R) — гасит тебя до искры на 2.6 секунды: скорость падает почти вдвое, зато заметность падает до 0.2 и враги теряют след. Аварийная кнопка, а не режим передвижения.

Все три тратят Волю и имеют кулдаун. Мастерство (см. раздел «Прогресс») удлиняет и усиливает их.""",
	"body_en": """Three skills are always yours, from level one and in every mode.

FLASH (Q) — sharply expands the light around you. Point-blank it damages an enemy. Your main scouting tool and your main way of giving yourself away.

DASH (Shift or Space) — a short burst along your facing. Saves you from being surrounded, carries you THROUGH an enemy (that is a tackle: damage to it, not you) and is the only way across a chasm.

SMOTHER (R) — dims you to a spark for 2.6 seconds: speed nearly halves, but visibility drops to 0.2 and enemies lose your trail. A panic button, not a travel mode.

All three cost Will and have cooldowns. Mastery (see «Progression») makes them longer and stronger.""",
},
{
	"sec": "skills", "id": "bought", "fig": "skills_buy",
	"title": "Покупаемые навыки", "title_en": "Purchasable skills",
	"body": """Четыре навыка открываются либо за SP в Магазине навыков, либо САМИ — по достижению вехи в статистике. Что случится раньше, то и откроет.

СОНАР (E) — кольцо расходится сквозь стены и показывает планировку и врагов; послесвечение держится ещё несколько секунд. Чистая разведка, урона нет.

ЩИТ (C) — следующий контакт с врагом не бьёт тебя, а ЗАМОРАЖИВАЕТ его. Замороженный враг получает +1 урона от любого удара — это ключ против брони Стража.

ИСКРА-ПРОВОДНИК (G) — летит по кратчайшему маршруту: сперва к ближайшему несобранному осколку, а когда все собраны — к открывшемуся порталу.

ОЗАРЕНИЕ (F) — раздвигает тьму на весь этаж на несколько секунд. Заряжается постепенно, от осколков и станций.

Повторная покупка уже открытого навыка — это не трата впустую, а УСИЛЕНИЕ: +1★ мастерства.""",
	"body_en": """Four skills unlock either for SP in the Skill Shop or ON THEIR OWN when you hit a statistical milestone. Whichever comes first.

SONAR (E) — a ring spreads through walls revealing layout and enemies; the afterglow lingers for a few seconds. Pure reconnaissance, no damage.

SHIELD (C) — the next enemy contact does not hit you, it FREEZES it. A frozen enemy takes +1 damage from any hit — the key to cracking a Sentinel's armour.

GUIDE SPARK (G) — flies the shortest route: first to the nearest uncollected shard, and once all are collected, to the unsealed portal.

REVEAL (F) — pushes the dark off the entire floor for a few seconds. It charges gradually, from shards and stations.

Buying an already-unlocked skill again is not wasted — it is a REINFORCEMENT: +1 star of mastery.""",
},
{
	"sec": "skills", "id": "combos", "fig": "skills_combo",
	"title": "Комбо", "title_en": "Combos",
	"body": """Некоторые навыки, применённые вместе, дают отдельный, более сильный эффект. Игра сообщает о срабатывании комбо сообщением — если увидел его, значит попал в окно.

СВЕТОВОЕ КОПЬЁ — рывок во время активной вспышки: дальность рывка ×1.5. Единственный способ нанести супербоссу настоящий урон.

ЩИТ + РЫВОК — рывок под щитом и замораживает врага, и бьёт тараном, а не только замораживает вхолостую.

ВСЕВИДЕНИЕ — сонар во время озарения: открытый этаж плюс помеченные враги.

ЗАМОРОЖЕННЫЙ + ЛЮБОЙ УДАР — общее правило, а не комбо конкретной пары: враг в заморозке (от щита, хроноса, тишины) получает +1 урона. Против Стража с его шестью очками здоровья это единственный разумный подход.

НАКАЛ-СИНЕРГИИ (только в режиме забега) — при высоком жаре рывок оставляет огненный след, замедляющий врагов, а сонар подсвечивает ближайшую станцию сквозь стены.""",
	"body_en": """Some skills used together produce a separate, stronger effect. The game announces a combo with a message — if you saw it, you hit the window.

SPEAR OF LIGHT — dash during an active flash: dash range x1.5. The only way to deal real damage to the superboss.

SHIELD + DASH — dashing while shielded both freezes the enemy AND rams it, instead of freezing for nothing.

ALL-SEEING — sonar during reveal: the whole floor open plus every enemy tagged.

FROZEN + ANY HIT — a general rule rather than a specific pair: an enemy under freeze (from shield, chrono, hush) takes +1 damage. Against a Sentinel and its six hit points this is the only sensible approach.

EMBER SYNERGIES (run mode only) — at high heat your dash leaves a fire trail that slows enemies, and sonar highlights the nearest station through walls.""",
},
{
	"sec": "skills", "id": "noise", "fig": "noise",
	"title": "Шум: тебя не только видят", "title_en": "Noise: they don't only see you",
	"body": """У навыков есть громкость. Враг в радиусе слышимости идёт ПРОВЕРЯТЬ источник — даже если между вами стена, даже если он тебя не видел. Заметность отвечает за «видно ли тебя», шум — за «слышно ли», и это два разных канала угрозы.

В момент каста от тебя расходится кольцо: это и есть радиус слышимости. Оранжевое — кто-то услышал и пошёл; голубое — никого в радиусе не оказалось. Так видно цену каждого нажатия, а не приходится догадываться.

Громко: СОНАР (620) и РАЗЛОМ (700) — самые шумные, ОЗАРЕНИЕ (560) и ВСПЫШКА (520) чуть тише. Для сравнения: базовый радиус, на котором враг тебя ВИДИТ, — 330. То есть Сонар зовёт вдвое дальше, чем ты успеешь заметить пришедшего.

Тихо: ХРОНОС (300), ПУЛЬС (260), ПРИЗЫВ (240), РЫВОК (200), ЩИТ (150), ИСКРА (120).

Бесшумно совсем: ТЛЕНИЕ и МИРАЖ. Тление — кнопка «спрятаться», шум сделал бы её бессмысленной. У Миража своя приманка, и шум в твоей точке перебивал бы двойника, ради которого его и ставят.

Громкость не фиксированная. Тление глушит любой каст до 0.45. Стойка света тоже слышна: Тусклая ×0.7, Ровная ×1.0, Яркая ×1.35 — раздутый свет гудит.

Кого шум не трогает: того, кто уже гонится за тобой (ему нечего проверять), напуганного, эскорт босса на посту и замороженного.

Практический вывод: Сонар больше не бесплатная разведка. Он покажет планировку — и позовёт Стража. Иногда правильный ход это пройти вслепую в Тусклой стойке.""",
	"body_en": """Skills have loudness. An enemy within earshot goes to INVESTIGATE the source — even through a wall, even if it never saw you. Visibility governs «can they see you», noise governs «can they hear you», and those are two separate threat channels.

At the moment of a cast a ring spreads out from you: that is the hearing radius. Orange means someone heard it and is coming; blue means nobody was in range. The cost of every keypress is visible instead of guessed.

Loud: SONAR (620) and BREACH (700) are the noisiest, REVEAL (560) and FLASH (520) slightly quieter. For comparison, the base radius at which an enemy SEES you is 330. So Sonar calls from twice as far as you can spot whoever answers.

Quiet: CHRONO (300), PULSE (260), SUMMON (240), DASH (200), SHIELD (150), GUIDE (120).

Completely silent: SMOTHER and MIRAGE. Smother is the «hide» button and noise would make it pointless. Mirage has its own lure, and noise at your own position would drown out the decoy you placed it for.

Loudness is not fixed. Smother muffles any cast to 0.45. The light stance is audible too: Dim x0.7, Even x1.0, Bright x1.35 — an inflated light hums.

Who ignores noise: anyone already chasing you (nothing to investigate), the frightened, a boss escort on duty, and the frozen.

The practical lesson: Sonar is no longer free reconnaissance. It will show you the layout — and call a Sentinel. Sometimes the right play is to walk blind in the Dim stance.""",
},
{
	"sec": "skills", "id": "gifts", "fig": "skills_gift",
	"title": "Дары боссов и Апекс", "title_en": "Boss gifts and Apex",
	"body": """Три навыка нельзя купить ни за какие SP — они выдаются по одному за победу над дверь-боссом (багровая дверь с черепом на уровнях, кратных пяти).

МИРАЖ (T) — ложная светящаяся цель: враги поблизости бросают тебя и идут проверять её.
РАЗЛОМ (Y) — проламывает стену по направлению взгляда. Работает и как срезка, и как аварийный выход.
ХРОНОС (V) — замораживает всех врагов на этаже на несколько секунд.

АПЕКС (H) — отдельная надстройка. У него нет своей формы: апекс принимает форму того навыка, в котором у тебя больше всего мастерства, из пула девяти (базовые шесть плюс три дара). Требует активного преследователя — это ультимейт для момента, когда за тобой уже гонятся, а не кнопка «сделать хорошо».

Колесо апекса в Магазине навыков показывает текущую форму: самая яркая пульсирующая нить к центру и есть она.

ПРИЗЫВ (N) — тоже открывается победой над дверь-боссом, но живёт в своём колесе. Зеркальный союзник следует за тобой и сам бьёт ближайшего врага.""",
	"body_en": """Three skills cannot be bought for any amount of SP — they are granted one at a time for beating a door boss (the crimson skull door on levels divisible by five).

MIRAGE (T) — a false glowing target: nearby enemies drop you and go check it.
BREACH (Y) — smashes the wall you are facing. Works both as a shortcut and as an emergency exit.
CHRONO (V) — freezes every enemy on the floor for a few seconds.

APEX (H) — a separate layer on top. It has no form of its own: apex takes the shape of whichever skill you have the most mastery in, out of a pool of nine (the six base ones plus the three gifts). It requires an active pursuer — this is an ultimate for the moment you are already being chased, not a «make things nice» button.

The apex wheel in the Skill Shop shows your current form: the brightest pulsing thread to the centre is the one.

SUMMON (N) — also unlocked by beating a door boss, but lives in its own wheel. The Mirror Ally follows you and strikes the nearest enemy on its own.""",
},
{
	"sec": "maze", "id": "shards", "fig": "shards",
	"title": "Осколки, ключи и двери", "title_en": "Shards, keys and doors",
	"body": """Осколок света и ключ — ОДИН И ТОТ ЖЕ предмет, а не два разных бонуса. Именно поэтому у них одинаковый янтарный цвет: собранный осколок отпирает запертые двери между этажами.

Что даёт осколок: глоток Света, каплю Воли и +1 ключ. Плюс он снимает один пункт с условия открытия портала-выхода.

ДВЕРИ между этажами: первая, фиолетовая, всегда открыта. Остальные янтарные и требуют ключ. Запертая дверь светится ярче, если ключ у тебя уже есть — это подсказка «просто дойди».

ПОРТАЛ-ВЫХОД заперт, пока на уровне остаётся хоть один несобранный осколок, включая осколки на этажах, куда ты ещё не спускался.

Искра-проводник (G) знает этот порядок: сначала ведёт к осколкам, потом к порталу.""",
	"body_en": """A shard of light and a key are THE SAME item, not two different bonuses. That is exactly why they share the same amber colour: a collected shard unlocks the locked doors between floors.

What a shard gives: a sip of Light, a drop of Will and +1 key. It also removes one item from the exit portal's unlock condition.

DOORS between floors: the first, violet one is always open. The rest are amber and need a key. A locked door glows brighter if you already hold a key — a hint that says «just walk over».

THE EXIT PORTAL stays sealed while even one shard remains uncollected anywhere on the level, including floors you have not descended to yet.

The guide spark (G) knows this order: shards first, portal second.""",
},
{
	"sec": "maze", "id": "stations", "fig": "stations",
	"title": "Станции и тёмные станции", "title_en": "Stations and dark stations",
	"body": """СТАНЦИЯ (синий кристалл) делает четыре вещи разом: даёт разовый глоток Света, добавляет Воли, работает точкой возврата и — главное — служит УКРЫТИЕМ: пока ты в её зоне, Свет не тает вообще. Бесконечно заряжаться нельзя, глоток один за цикл, но стоять и переводить дух — можно и нужно.

В режиме забега станции служат ещё и АЛТАРЯМИ: там ты банкуешь Накал и покупаешь навыки.

ТЁМНАЯ СТАНЦИЯ (с 10-го уровня, тема Споровых пустот) — противоположность: воронка, которая ТЯНЕТ твой Свет, пока ты рядом, и подпитывает окрестных врагов фиолетовым ореолом. Гасится вспышкой или сонаром. Стоящая рядом станция света подавляет её сама.

Если враг вдруг стал заметно злее без видимой причины — поищи глазами фиолетовый ореол, скорее всего он кормится.""",
	"body_en": """A STATION (blue crystal) does four things at once: grants a one-off sip of Light, adds Will, acts as a checkpoint and — most importantly — serves as SHELTER: while you are in its zone, Light does not drain at all. You cannot charge indefinitely, the sip is once per cycle, but standing and catching your breath is both allowed and advisable.

In run mode stations double as ALTARS: that is where you bank ember and buy skills.

A DARK STATION (from level 10, the Spore Wastes theme) is the opposite: a funnel that DRAINS your Light while you are near and feeds nearby enemies with a violet aura. Douse it with flash or sonar. A light station standing close by suppresses it on its own.

If an enemy suddenly got noticeably meaner for no visible reason — look for a violet aura, it is probably feeding.""",
},
{
	"sec": "maze", "id": "hazards", "fig": "hazards",
	"title": "Ямы, срезки, зоны", "title_en": "Chasms, shortcuts, zones",
	"body": """ЯМА-ПРОВАЛ (с 15-го уровня, тема Багровых недр) — не стена и не проход. Пройти сквозь неё нельзя, обойти можно, но единственный способ пересечь напрямую — РЫВОК. Это и есть смысл ям: рывок перестаёт быть кнопкой «убежать» и становится инструментом прохода.

ПОРТАЛ-СРЕЗКА (с 8-го уровня, тема Лазурных шахт) — редкая пара бирюзовых порталов НА ОДНОМ этаже. Не путать с дверями: те ведут между этажами и требуют ключ, а срезка — секрет, который надо найти, и работает сразу.

РАЗМЕЧЕННЫЕ ЗОНЫ (с 5-го уровня) — этаж поделён на четверти, у каждой свой акцентный цвет и свои декоративные блики. Это чистая читаемость: пространство запоминается как последовательность мест, а не как однородный шум коридоров.

Плотность стен внутри одного этажа тоже неоднородна: где-то теснее, где-то простор с петлями.""",
	"body_en": """A CHASM (from level 15, the Crimson Depths theme) is neither wall nor passage. You cannot walk through it; you can walk around it; but the only way straight across is a DASH. That is the whole point of chasms: dash stops being the «escape» button and becomes a means of passage.

A SHORTCUT PORTAL (from level 8, the Azure Mines theme) is a rare pair of teal portals ON THE SAME floor. Do not confuse them with doors: doors lead between floors and need a key, while a shortcut is a secret to find and works immediately.

MARKED ZONES (from level 5) — the floor is split into quarters, each with its own accent colour and decorative highlights. This is purely about readability: space is remembered as a sequence of places rather than uniform corridor noise.

Wall density also varies within a single floor: tighter in one place, open with loops in another.""",
},
{
	"sec": "maze", "id": "events", "fig": "events",
	"title": "События и особые комнаты", "title_en": "Events and special rooms",
	"body": """СЛУЧАЙНЫЕ СОБЫТИЯ идут по ходу уровня и всегда предупреждают заранее: за пару секунд в углу экрана появляется тусклый пульсирующий значок именно того события, которое случится.

Землетрясение рушит часть внутренних стен. Сдвиг перестраивает планировку. Просвет расширяет обзор. Пятна тумана глушат видимость локально. Утечка света ускоряет расход. Перебой заставляет свет мигать.

ОСОБЫЕ КОМНАТЫ (с 6-го уровня) предупреждают золотистым мерцанием пола за несколько клеток. Внутри одно из пяти: алтарный осколок под охраной врага; ловушка тьмы, гасящая свет на пару секунд; два неотличимых портала — один к станции, другой к выходу; безопасная комната-эхо с указателем на выход; прилив сил, восполняющий Свет ценой пробуждения врагов рядом.

МАЯК — сигнальная вышка, загорается раз в уровень на 20-30 секунд. Добежал — получил случайный бонус: осколки, полный Свет, заморозка врагов, сброс кулдауна, Накал.

ЖИВОЙ ЛАБИРИНТ — если ты застрял в долгом обходе, раз в уровень соседняя стена сама растворяется.""",
	"body_en": """RANDOM EVENTS occur as the level goes on and always warn you first: a couple of seconds ahead, a dim pulsing icon of that exact event appears in the corner.

An earthquake collapses some inner walls. A shift rebuilds the layout. A clearing widens your view. Fog patches muffle visibility locally. A light leak speeds up drain. A flicker makes your light stutter.

SPECIAL ROOMS (from level 6) warn you with a golden shimmer on the floor a few tiles ahead. Inside is one of five: an altar shard under guard; a darkness trap that snuffs your light for a couple of seconds; two identical portals — one to a station, one to the exit; a safe echo room pointing at the exit; a surge that refills Light at the cost of waking nearby enemies.

A BEACON — a signal tower that lights up once per level for 20-30 seconds. Reach it for a random bonus: shards, full Light, frozen enemies, a cooldown reset, ember.

LIVING MAZE — if you are stuck in a long detour, once per level a nearby wall dissolves on its own.""",
},
{
	"sec": "maze", "id": "escalation", "fig": "escalation",
	"title": "Эскалация: лабиринт не ждёт", "title_en": "Escalation: the maze won't wait",
	"body": """У уровня три стадии, и они зависят только от того, сколько ты на нём находишься. Порог считается от нормы времени этого уровня — той же, по которой ранг решает, быстро ты прошёл или нет. Поэтому «долго» на 50-м уровне и на 1-м это разные числа секунд, а не одна константа.

ТИШИНА — исследуй спокойно. Ничего не происходит, лабиринт тебя терпит.

ТЬМА ГУСТЕЕТ (после нормы времени) — обзор ужимается до 0.9, по краям экрана появляется холодная кромка. Лабиринт замечает, что ты задержался. Ещё не смертельно, но идти становится тяжелее.

ОХОТА (примерно вдвое дольше нормы) — обзор падает до 0.8, и просыпается ЛОВЧИЙ.

Ловчий — не обычный враг. Он крупнее, светится розовым, и главное: он НЕ ТЕРЯЕТ СЛЕД. Обычный преследователь, потеряв тебя из виду, идёт несколько секунд к последнему месту и забывает. Ловчий знает, где ты, всегда — стены, темнота и Тление на это не влияют.

Уравновешивает его ровно одно: он медленный, на четверть медленнее обычного. От Ловчего можно УЙТИ, но нельзя СПРЯТАТЬСЯ. Заморозка (Щит, Хронос) на него действует как на любого врага, так что окно на побег себе сделать можно.

Зачем это: раньше единственным давлением была ровная утечка Света, и первая минута ощущалась как четвёртая. Ковырять уровень бесконечно было бесплатно. Теперь у прохождения есть ритм: сначала исследуй, потом уходи.

Терпение лабиринта зависит от БИОМА. В Лазурных шахтах уровень про поиск маршрута, и время дают с запасом — пороги отодвинуты на четверть. В Споровых пустотах наоборот: там тебя видно издалека и без всякой эскалации, поэтому давление приходит на пятую часть раньше. Багровые недра — базовый темп.

Стадии только растут — уровень не успокаивается обратно. На новом уровне отсчёт начинается заново. В обучении и на аренах боссов эскалации нет.""",
	"body_en": """A level has three stages, and they depend only on how long you have been in it. The threshold is derived from that level's par time — the same one the rank uses to decide whether you were fast. So «a long time» means different numbers of seconds on level 50 and level 1, not one constant.

SILENCE — explore in peace. Nothing happens; the maze tolerates you.

THE DARK THICKENS (past par time) — your view shrinks to 0.9 and a cold rim appears at the screen edges. The maze has noticed you lingering. Not lethal yet, but going gets harder.

THE HUNT (roughly twice par) — view drops to 0.8, and the STALKER wakes up.

The Stalker is not an ordinary enemy. It is larger, glows pink, and crucially: it DOES NOT LOSE YOUR TRAIL. A normal pursuer that loses sight of you walks to your last known spot for a few seconds and forgets. The Stalker always knows where you are — walls, darkness and Smother do not change that.

Exactly one thing balances it: it is slow, a quarter slower than normal. You can OUTRUN the Stalker but you cannot HIDE from it. Freezes (Shield, Chrono) work on it like on any enemy, so you can buy yourself a window to escape.

Why: previously the only pressure was the flat Light drain, and the first minute felt like the fourth. Picking a level apart forever was free. Now a run has rhythm: explore first, then leave.

The maze's patience depends on the BIOME. The Azure Mines are about finding a route, so you get a quarter more time. The Spore Wastes are the opposite: you are visible from afar there anyway, so pressure arrives a fifth earlier. The Crimson Depths run at the base tempo.

Stages only escalate — a level never calms back down. On a new level the count starts over. There is no escalation in the tutorial or in boss arenas.""",
},
{
	"sec": "biomes", "id": "rules", "fig": "biomes",
	"title": "Биом — это набор правил", "title_en": "A biome is a rule set",
	"body": """Биом меняется каждые пять уровней и это НЕ просто перекраска. Биом — набор правил: он владеет своими механиками на всю свою пятёрку уровней, его механики гарантированы, а чужих в нём нет вовсе.

Зачем так: раньше каждая механика катала свою независимую лотерею, и игрок за уровень видел одну-две случайные вспышки из пула примерно в пятнадцать штук. Выучить не успевал ни одну — контента много, а мастерства строить не над чем. Теперь тема живёт пять уровней подряд, её успеваешь освоить, а смена биома реально меняет игру.

При входе в новый биом лабиринт сам говорит, по каким правилам ты играешь дальше.

Биомы циклятся, и второй заход в ту же тему плотнее первого: с 16-го уровня ям и тёмных станций больше, а порталов-срезок две пары вместо одной.""",
	"body_en": """The biome changes every five levels, and this is NOT merely a repaint. A biome is a rule set: it owns its mechanics for its whole five-level stretch, its mechanics are guaranteed, and other biomes' mechanics do not appear in it at all.

Why: every mechanic used to roll its own independent lottery, so per level a player saw one or two random flashes out of a pool of roughly fifteen. You never learned any of them — lots of content, nothing to build mastery on. Now a theme lives for five levels straight, long enough to master, and a biome change genuinely changes the game.

On entering a new biome the maze itself tells you which rules you are playing by next.

Biomes cycle, and the second pass through a theme is denser than the first: from level 16 there are more chasms and dark stations, and two portal pairs instead of one.""",
},
{
	"sec": "biomes", "id": "three", "fig": "biomes3",
	"title": "Три биома", "title_en": "The three biomes",
	"body": """ЛАЗУРНЫЕ ШАХТЫ — тема срезок. Топология рукотворная: крупные залы, соединённые ходами. Порталы-срезки есть всегда, ям и тёмных станций нет. Чаще приходит Вор, чаще сбоит свет, комнаты — «выбор» и «эхо». Биом учит читать маршрут.

БАГРОВЫЕ НЕДРА — тема провалов. Узкие извилистые коридоры. Ямы есть всегда, срезок и тёмных станций нет. Землетрясение втрое чаще обычного, охотится Беглец, комнаты — алтарный осколок и ловушка тьмы. Здесь рывок это не «убежать», а «пройти».

СПОРОВЫЕ ПУСТОТЫ — тема тьмы. Разреженная сетка, почти открытая пещера: враги видят издалека. Тёмные станции есть всегда, правит туман, чаще Огонёк и Кроты. Единственная полоса, где Тусклая стойка и Тление важнее скорости.

Практический вывод: стойку света стоит держать разной в разных биомах. В Пустотах Яркая опасна, в Шахтах — ценна.""",
	"body_en": """AZURE MINES — the shortcut theme. Man-made topology: large halls joined by passages. Shortcut portals are always present; chasms and dark stations are not. The Thief visits more often, lights glitch more, rooms tend to be «choice» and «echo». This biome teaches you to read a route.

CRIMSON DEPTHS — the chasm theme. Narrow winding corridors. Chasms are always present; shortcuts and dark stations are not. Earthquakes hit three times as often, the Runner shows up, rooms are the altar shard and the darkness trap. Here a dash is not «escape» but «pass».

SPORE WASTES — the darkness theme. A sparse grid, almost an open cavern: enemies see you from afar. Dark stations are always present, fog rules, the Wisp and the Moles are common. The one stretch where the Dim stance and Smother matter more than speed.

The practical lesson: keep a different light stance in different biomes. In the Wastes, Bright is dangerous; in the Mines, valuable.""",
},
{
	"sec": "enemies", "id": "types", "fig": "enemies",
	"title": "Типы врагов", "title_en": "Enemy types",
	"body": """Все враги ходят строго по сетке своего этажа и ищут путь к тебе заново, когда теряют след. Пока между вами стена, они тебя не видят, как бы ярко ты ни горел.

МЕДЛИТЕЛЬНЫЙ — 3 очка здоровья, спокойная скорость. Именно он может испугаться и убежать после нескольких неудачных погонь.
БЫСТРЫЙ — 2 очка, заметно резвее тебя на прямой. Убегать по коридору бесполезно, нужны углы и рывок.
ЦИКЛИЧНЫЙ — 3 очка, при контакте накладывает замедление.

Элита появляется глубже:
СТРАЖ (с 25-го) — 6 очков здоровья и зрение в 1.4 раза дальше. В лоб вспышкой не берётся: заморозь щитом и бей, замороженный получает +1 урона.
ФАНТОМ (с 30-го) — всего 1 очко, но скорость 1.3. Умирает с одного удара, если успеешь.
ПИЯВКА (с 35-го) — контакт высасывает ВОЛЮ, а не Свет. Опасна тем, что оставляет тебя без навыков.

Счётчики встреч и побед по каждому типу ведёт Бестиарий — там же лор и тактика.""",
	"body_en": """Every enemy moves strictly on its floor's grid and re-searches for a path to you whenever it loses the trail. While a wall stands between you, they cannot see you, however brightly you burn.

SLOW — 3 hit points, unhurried. This is the one that can get scared and flee after several failed chases.
FAST — 2 hit points, noticeably quicker than you in a straight line. Running down a corridor is pointless; you need corners and a dash.
CYCLIC — 3 hit points, applies a slow on contact.

Elites appear deeper:
SENTINEL (from 25) — 6 hit points and 1.4x sight range. A frontal flash will not do: freeze it with the shield and strike, since frozen takes +1 damage.
PHANTOM (from 30) — only 1 hit point, but speed 1.3. Dies in one hit if you are quick enough.
LEECH (from 35) — contact drains WILL, not Light. Dangerous because it leaves you without skills.

The Bestiary tracks encounters and kills per type, along with lore and tactics.""",
},
{
	"sec": "enemies", "id": "roles", "fig": "roles",
	"title": "Роли: загонщик и мимик", "title_en": "Roles: herder and mimic",
	"body": """Типы врагов отличаются цифрами — здоровьем, скоростью, дальностью зрения. Роли отличаются ПОВЕДЕНИЕМ: статы у них те же, что у их типа, но делают они принципиально другое.

ЗАГОНЩИК (с 8-го уровня, жёлтая подсветка) идёт НЕ К ТЕБЕ. Он вычисляет клетку, через которую ты собирался уйти в открытую часть лабиринта, и занимает её. Ты бежишь — а выход перекрыт, и остаётся только тупик.

Против него бесполезно бежать быстрее: он не отстаёт по маршруту, он его отрезает. Работает другое — ломать сам маршрут. Рывок сквозь него (это ещё и урон ему), Разлом сквозь стену в стороне, срезка-портал, или просто пойти туда, куда он тебя гонит, и выйти оттуда через ход, которого он не считал. Если ты уже в тупике и отрезать нечего, загонщик ведёт себя как обычный враг и идёт добивать.

Чаще всего он в Багровых недрах — узкие извилистые коридоры это его стихия. В Споровых пустотах встречается вдвое реже: там открытая пещера, перекрывать почти нечего.

МИМИК (с 12-го уровня) — подделка под станцию зарядки. Тот же синий кристалл, то же дыхание, тот же силуэт: на глаз не отличить, и это не оплошность рисовки, а вся суть. Подойдёшь близко — он багровеет, вздрагивает, и через мгновение на его месте стоит быстрый враг.

Мимик не бьёт в момент превращения и даёт тебе долю секунды на реакцию: это ловушка, а не наказание за то, что ты вообще подошёл к кристаллу. Но станция перестала быть безусловно безопасной, и на низком Свете к ней теперь идёшь с оглядкой.

С 30-го уровня роль загонщика может достаться СТРАЖУ — из трёх элит только ему. Он медленный и бронированный, «стена», и перекрывать выход это ровно его работа: убить его на бегу не выйдет, а обойти он не даст. Фантому роль не достаётся намеренно (со скоростью 1.3 он не оставил бы выхода вовсе), Пиявке тоже — она ест Волю, и вместе с загоном это было бы два наказания в одном враге.

Мимики стоят среди НАСТОЯЩИХ станций — иначе подделку выдавало бы место. Живут в Лазурных шахтах: биом обмана, там же ходит Вор. В Пылающем их нет вовсе — там станций не бывает, и подделка выдала бы себя мгновенно.""",
	"body_en": """Enemy types differ by numbers — health, speed, sight range. Roles differ by BEHAVIOUR: their stats are exactly those of their type, but what they do is fundamentally different.

THE HERDER (from level 8, yellow tint) does NOT come at you. It works out the cell you were going to escape through into the open part of the maze, and takes it. You run — and the way out is blocked, leaving only the dead end.

Running faster is useless against it: it is not trailing your route, it is cutting it. What works is breaking the route itself. Dash through it (which also damages it), Breach through a wall to the side, a shortcut portal, or simply go where it herds you and leave through a passage it did not count. If you are already in a dead end and there is nothing to cut off, the herder behaves like an ordinary enemy and comes to finish you.

It is most common in the Crimson Depths — narrow winding corridors are its element. In the Spore Wastes it appears half as often: an open cavern leaves little to block.

THE MIMIC (from level 12) is a fake charge station. Same blue crystal, same breathing, same silhouette: indistinguishable by eye, and that is not sloppy art but the entire point. Come close and it flushes crimson, shudders, and a moment later a fast enemy stands where it was.

The mimic does not strike as it transforms and gives you a fraction of a second to react: it is a trap, not a punishment for approaching a crystal at all. But a station has stopped being unconditionally safe, and on low Light you now approach one with care.

From level 30 the herder role can fall to a SENTINEL — of the three elites, only to it. It is slow and armoured, a wall, and blocking the way out is exactly its job: you will not kill it on the run, and it will not let you past. The Phantom is deliberately excluded (at speed 1.3 it would leave no way out at all), and so is the Leech — it eats Will, which together with herding would be two punishments in one enemy.

Mimics stand among REAL stations — placed anywhere else, their location would give them away. They live in the Azure Mines: the biome of deception, where the Thief also roams. In Blazing there are none at all — there are no stations there, so a fake would expose itself instantly.""",
},
{
	"sec": "enemies", "id": "guests", "fig": "guests",
	"title": "Гости лабиринта", "title_en": "Maze guests",
	"body": """Гости — необязательные мини-события, не больше одного за уровень, с третьего уровня. О приходе гостя лабиринт сообщает сам. Какой именно придёт — зависит от биома.

БЕГЛЕЦ — светящаяся комета, которая не трогает тебя, а убегает. Догони и убей до того, как исчезнет — получишь щедрую награду. Чаще всего в Багровых недрах.

ОГОНЁК-СОЮЗНИК — дружественный дух на время: отвлекает тьму от тебя. Чаще в Споровых пустотах.

КРОТЫ — норы, из которых периодически высовываются кроты. Клетка над норой на время блокируется, попал под момент выхода — получил урон. Превращает участок в мини-игру на тайминг.

ВОР — быстрый и безвредный, но при касании крадёт несомый Накал или Свет и убегает. Догонишь и убьёшь — вернёт с процентами. Чаще в Лазурных шахтах.""",
	"body_en": """Guests are optional mini-events, no more than one per level, from level three onwards. The maze announces a guest's arrival itself. Which one shows up depends on the biome.

RUNNER — a glowing comet that does not attack you, it flees. Catch and kill it before it vanishes for a generous reward. Most common in the Crimson Depths.

WISP ALLY — a friendly spirit for a while: it draws the dark away from you. More common in the Spore Wastes.

MOLES — burrows out of which moles periodically poke. The tile above a burrow is blocked for a time, and being caught as one emerges costs you damage. Turns a patch of maze into a timing mini-game.

THIEF — fast and harmless, but on contact it steals carried ember or Light and runs. Catch and kill it and it pays back with interest. More common in the Azure Mines.""",
},
{
	"sec": "bosses", "id": "door", "fig": "boss_door",
	"title": "Дверь-босс и дары", "title_en": "The door boss and its gifts",
	"body": """На уровнях, кратных пяти, где-то в лабиринте стоит багровая дверь с черепом. Она НЕОБЯЗАТЕЛЬНА: уровень можно пройти обычным путём, дверь просто стоит и ждёт.

За дверью арена с Тёмным Ядром. Победа даёт следующий по порядку дар: Мираж, потом Разлом, потом Хронос. Каждый дар постоянный, входит в пул форм Апекса, и первая же победа открывает Навыки призыва. После победы тебя возвращают в лабиринт, и уровень продолжается с того же места.

Ядро проходит фазы: сперва медленный охотник, потом расщепление на части при половине здоровья, в конце — гасит станции на арене, чтобы твой Свет таял быстрее.

Смысл в том, что дверь-босс это единственное место в кампании, где ты получаешь ПРАВИЛА, а не цифры: три новых глагола вместо «побольше урона».""",
	"body_en": """On levels divisible by five, somewhere in the maze stands a crimson door bearing a skull. It is OPTIONAL: you can finish the level the normal way and the door simply waits.

Behind it is an arena with the Dark Core. Victory grants the next gift in order: Mirage, then Breach, then Chrono. Each gift is permanent, joins the Apex form pool, and the very first victory unlocks the Summon skills. After the win you are returned to the maze and the level continues where you left it.

The Core moves through phases: first a slow hunter, then a split into fragments at half health, and finally it starts snuffing the arena's stations so your Light drains faster.

The point is that the door boss is the one place in the campaign where you gain RULES rather than numbers: three new verbs instead of «more damage».""",
},
{
	"sec": "bosses", "id": "final", "fig": "boss_final",
	"title": "Финал: страж лабиринта", "title_en": "The finale: the maze guardian",
	"body": """Уровни 48 и 49 меняют форму на ДВОЙНОЙ ОВАЛ: кольцевой коридор между двумя эллипсами. Центр недостижим, срезки через середину физически нет — кольцо нужно пройти почти целиком. Порталов-срезок там намеренно не бывает, иначе весь смысл формы пропадает.

Уровень 50 — тот же овал, но крупнее, и в конце кольца одна-единственная дверь. За ней арена механического стража.

Как его бить. Обычная вспышка почти не ранит: это сделано специально, чтобы финал нельзя было раздеть одним заученным трюком. Раз в несколько лазерных выстрелов ядро стража открывается — вот тогда рывок во время вспышки (Световое копьё) наносит настоящий урон.

Лазер РУШИТ стены арены, но стальные серые пилоны держатся — прятаться нужно за ними, и отличать их по холодному оттенку надо заранее, а не когда стена уже исчезла.

Эскорт стража питается от тёмных антистанций. Погаси антистанции — охрана ослабнет. Гоняться за тобой по всей арене они не станут: у них короткий агр вокруг босса.""",
	"body_en": """Levels 48 and 49 warp into a DOUBLE OVAL: a ring corridor between two ellipses. The centre is unreachable and there is physically no shortcut through the middle — you must walk almost the whole ring. Shortcut portals deliberately never appear there, or the shape would lose its point.

Level 50 is the same oval but bigger, with a single door at the end of the ring. Behind it is the mechanical guardian's arena.

How to fight it. A plain flash barely scratches it: this is deliberate, so the finale cannot be stripped with one memorised trick. Every few laser shots the guardian's core opens up — that is when a dash during a flash (the Spear of Light) does real damage.

The laser BREAKS the arena's walls, but the steel-grey pillars hold — those are your cover, and you need to tell them apart by their cold tint in advance, not once a wall has already vanished.

The guardian's escort feeds on dark anti-stations. Douse the anti-stations and the guard weakens. They will not chase you across the whole arena: their aggro radius around the boss is short.""",
},
{
	"sec": "modes", "id": "levels", "fig": "modes_levels",
	"title": "Уровни и сложности", "title_en": "Levels and difficulties",
	"body": """УРОВНИ — основная кампания на 50 уровней. Прогресс банкуется навсегда, навыки покупаются и усиливаются за SP. С 30-го уровня начинается мега-лабиринт: размеры и число этажей растут, а точка входа больше не в углу, а случайная.

Три сложности переключаются на экране «Играть»:

ТЛЕЮЩИЙ — мягче, награды ×0.75.
ГОРЯЩИЙ — базовый баланс.
ПЫЛАЮЩИЙ — станций НЕТ вовсе. Взамен стартовый запас Света удвоен, а осколки дают двойной глоток и заряжают Озарение. Награды ×1.5. Это не «то же самое, но больнее», а другая экономика: весь Свет теперь идёт из осколков, и маршрут строится вокруг них.

В Пылающем биомы не теряют свои темы: ямы и порталы-срезки там есть, как и везде. А вот тёмных станций и мимиков нет — первым нечем восполнить вытянутый Свет, когда станций не бывает вовсе, а подделке под станцию нечем маскироваться среди пустоты.

Режимы открываются по мере прохождения: Спуск дня после 5-го уровня, Накал после 10-го, Логово после 20-го. Сделано, чтобы не валить на новичка четыре режима сразу.""",
	"body_en": """LEVELS — the main 50-level campaign. Progress banks permanently; skills are bought and reinforced with SP. From level 30 the mega-maze begins: sizes and floor counts grow, and the entry point is no longer the corner but random.

Three difficulties switch on the «Play» screen:

SMOULDERING — gentler, rewards x0.75.
BURNING — the baseline balance.
BLAZING — there are NO stations at all. In exchange your starting Light is doubled, and shards give a double sip and charge Reveal. Rewards x1.5. This is not «the same but more painful», it is a different economy: all Light now comes from shards, and your route is built around them.

In Blazing the biomes keep their themes: chasms and shortcut portals are there as everywhere. Dark stations and mimics are not — the first have no way to refund the Light they drain when no stations exist at all, and a fake station has nothing to hide among in an empty world.

Modes unlock as you progress: Daily Dive after level 5, Ember after level 10, Lair after level 20. This exists so a newcomer is not handed four modes at once.""",
},
{
	"sec": "modes", "id": "ember", "fig": "modes_ember",
	"title": "Накал — спуск за огнём", "title_en": "Ember — a descent for fire",
	"body": """Накал это рогалик-спуск, а не продолжение кампании. Три слота, каждый забег начинается с нуля: только вспышка, рывок и тление. Три жизни на весь спуск, глубина бесконечная.

НАКАЛ — твоя ставка. Несомый Накал горит при смерти (теряется половина), забанканный сохраняется навсегда. В этом и весь выбор: нести дальше и рисковать или дойти до алтаря и обезопасить. Если бы банк тоже горел, решение потеряло бы смысл.

ЖАР — обратная сторона: чем больше несёшь, тем ярче горишь, тем дальше тебя видят и тем агрессивнее враги. Жар читается телом — оранжевая кромка-сердцебиение по краям экрана.

Станции здесь работают алтарями: банк плюс магазин.

ГОРИЗОНТЫ — каждые пять глубин у спуска новое имя, это лестница целей вместо безликого счётчика. КОНТРАКТЫ выбираются на старте забега: модификатор в обмен на награду. ОБЕТЫ — долгосрочная цель слота, её выполнение даёт награду уже в профиле Уровней.""",
	"body_en": """Ember is a roguelite descent, not a continuation of the campaign. Three slots; each run starts from nothing: only flash, dash and smother. Three lives for the whole descent, endless depth.

EMBER is your stake. Carried ember burns on death (you lose half); banked ember is kept forever. That is the entire decision: carry on and risk it, or reach an altar and secure it. If the bank burned too, the decision would be meaningless.

HEAT is the flip side: the more you carry, the brighter you burn, the farther you are seen and the more aggressive enemies get. Heat is read through the body — an orange heartbeat rim at the screen edges.

Stations here act as altars: bank plus shop.

HORIZONS — every five depths the descent gets a new name, a ladder of goals instead of a faceless counter. CONTRACTS are chosen at the start of a run: a modifier in exchange for a reward. VOWS are a slot's long-term goal, and completing one pays out in your Levels profile.""",
},
{
	"sec": "modes", "id": "other", "fig": "modes_other",
	"title": "Спуск дня, Логово, обучение", "title_en": "Daily Dive, Lair, tutorial",
	"body": """СПУСК ДНЯ — ежедневный забег по правилам Накала. Сид генерации складывается из даты и номера уровня, то есть лабиринт сегодня одинаковый у всех. Одна попытка в день; результаты и серия дней хранятся в Дневнике.

ЛОГОВО — отдельная ветка из 10 уровней со своим прогрессом. Один этаж на уровень, а в геометрическом центре лабиринта — расчищенный тронный зал с владыкой тьмы. Победа это смерть босса, а не золотой выход: указатели, искра и минимап целятся в него так же, как обычно целятся в портал.

Население в Логове гуще, чем в кампании на том же номере уровня, а с шестого логова подступы к залу охраняет пара Стражей.

ОБУЧЕНИЕ — три коротких этапа: основы и настоящая встреча с врагом; продвинутые навыки и комбо; новые механики лабиринта. Проиграть обучение нельзя: если Свет погаснет, тебя просто бесплатно подзарядят.""",
	"body_en": """DAILY DIVE — a daily run under Ember rules. The generation seed combines the date and the level number, which means today's maze is the same for everyone. One attempt per day; results and your day streak live in the Journal.

THE LAIR — a separate 10-level branch with its own progress. One floor per level, and at the maze's geometric centre sits a cleared throne room with a dark lord. Victory means the boss's death, not a golden exit: pointers, the guide spark and the minimap all target it the same way they normally target the portal.

The Lair is more densely populated than the campaign at the same level number, and from Lair 6 onward a pair of Sentinels guards the approaches to the hall.

THE TUTORIAL — three short stages: basics and a real enemy encounter; advanced skills and combos; newer maze mechanics. You cannot lose the tutorial: if your Light goes out, you are simply recharged for free.""",
},
{
	"sec": "progress", "id": "sp", "fig": "progress_sp",
	"title": "SP, мастерство и пассивки", "title_en": "SP, mastery and passives",
	"body": """SP — очки навыков, копятся с опытом. Тратятся в Магазине навыков.

Первая покупка ОТКРЫВАЕТ навык. Повторная покупка того же навыка — не трата впустую, а УСИЛЕНИЕ: +1★ мастерства, до пяти звёзд. Каждая звезда даёт примерно +15% к силе навыка, и в магазине для каждой звезды написано, что конкретно изменится: не «стало лучше», а «×N → ×M».

Мастерство растёт и само, от применения: примерно одна звезда за десяток использований. То есть навык, которым ты действительно играешь, крепнет без вложений.

ПАССИВКИ не покупаются вообще и всегда включены. Их шесть, и каждая растёт от 0 до 5 сама, от твоих действий: пройденного расстояния, глотков на станциях, времени выживания, собранных осколков, пройденных уровней и применённых навыков. Сбрасываются только вместе со статистикой.

Часть навыков открывается ещё и вехами: например, Сонар откроется сам за 25 собранных осколков, даже если ты не потратишь ни одного SP.""",
	"body_en": """SP — skill points, accumulated with experience. Spent in the Skill Shop.

The first purchase UNLOCKS a skill. Buying the same skill again is not wasted spending but a REINFORCEMENT: +1 star of mastery, up to five. Each star adds roughly 15% to the skill's power, and the shop spells out what each star changes: not «better» but «xN -> xM».

Mastery also grows on its own through use: roughly one star per ten uses. So a skill you actually play with strengthens without investment.

PASSIVES cannot be bought at all and are always on. There are six, each growing from 0 to 5 by itself from your actions: distance walked, station sips, time survived, shards collected, levels cleared and skills cast. They reset only together with your statistics.

Some skills also unlock through milestones: Sonar, for instance, unlocks itself at 25 shards collected even if you never spend a single SP.""",
},
{
	"sec": "progress", "id": "streak", "fig": "streak",
	"title": "Серия осколков и награда на месте", "title_en": "Shard streak and on-the-spot reward",
	"body": """Осколки, собранные подряд БЕЗ УРОНА, идут в серию. Каждый следующий осколок в серии дороже предыдущего: множитель опыта растёт на 0.25 за осколок и упирается в ×2.5. Серия видна в HUD справа от счётчика осколков — там же написан текущий множитель, так что гадать не нужно.

Любой удар врага серию обрывает, и игра об этом прямо говорит: «серия ×5 прервана». Раньше множитель просто исчезал бы молча, и связь с полученным ударом не читалась.

Считай это ставкой: пройти уровень аккуратно выгоднее, чем пройти его быстро и с тычками. Первые два-три осколка почти ничего не добавляют, а вот серия из шести-семи заметно ускоряет прокачку.

НАГРАДА НА МЕСТЕ. Раньше вся награда игры — опыт, SP, ранг, множители — раскрывалась только в меню и на экране результатов, то есть после того, как момент уже прошёл. Теперь у самого места события всплывает надпись: «+94 XP» у подобранного осколка, «+Воля» рядом, «+30 XP» у убитого врага (в Накале ещё и сколько добавилось жара).

Это не новая механика, а исправление читаемости: числа были и раньше, просто игрок их не видел в тот момент, когда принимал решение.

В забеге серия множит не только опыт, но и НАКАЛ с каждого осколка: там аккуратность — главная валюта, и было бы странно, если бы она влияла на опыт и не влияла на твою ставку.

Серия живёт внутри уровня и обнуляется на новом. Не путай её с серией рангов, которая работает МЕЖДУ уровнями и даёт Благословение или Снисхождение — про неё в статье «Ранг и награды».""",
	"body_en": """Shards collected in a row WITHOUT DAMAGE form a streak. Each next shard in the streak is worth more than the last: the experience multiplier grows by 0.25 per shard and caps at x2.5. The streak is shown in the HUD right of the shard counter, along with the current multiplier, so there is nothing to guess.

Any enemy hit breaks the streak, and the game says so outright: «streak x5 broken». Previously the multiplier would simply vanish in silence and the connection to the hit you took was unreadable.

Treat it as a wager: clearing a level carefully pays better than clearing it fast while taking pokes. The first two or three shards add almost nothing, but a streak of six or seven noticeably speeds up progression.

ON-THE-SPOT REWARD. Previously every reward in the game — experience, SP, rank, multipliers — was revealed only in menus and on the results screen, that is, after the moment had passed. Now a label floats up at the place it happened: «+94 XP» at a collected shard, «+Will» beside it, «+30 XP» at a killed enemy (in Ember mode, plus how much heat it added).

This is not a new mechanic but a readability fix: the numbers existed before, the player just never saw them at the moment of deciding.

In a run the streak multiplies not just experience but the EMBER from every shard: care is the main currency there, and it would be odd for it to affect experience but not your stake.

The streak lives inside a level and resets on the next one. Don't confuse it with the rank streak, which works BETWEEN levels and grants the Blessing or Mercy — that one is covered in «Rank and rewards».""",
},
{
	"sec": "progress", "id": "rank", "fig": "progress_rank",
	"title": "Ранг и награды", "title_en": "Rank and rewards",
	"body": """После каждого уровня считается ранг от S до D по четырём критериям: доля собранных осколков, прошёл ли ты без урона, обошёлся ли без способностей и уложился ли в норму времени. На экране результатов написана не просто буква, а расшифровка: что зачлось, а чего не хватило.

Ранг — не украшение, он МНОЖИТ награды: S даёт ×1.5 к опыту и Накалу, A ×1.25, B ×1.0, C ×0.85, D ×0.7. Чистая игра ощутимо ускоряет прокачку.

Серии работают в обе стороны и обе помогают. Несколько рангов A или S подряд дают Благословение лабиринта — небольшой стартовый бонус на следующем уровне. Несколько D подряд дают Снисхождение: лабиринт ставит рядом со стартом гарантированную станцию (в Пылающем — просто добавляет Света).

Лучший ранг по каждому уровню помнится и показывается на кнопке уровня в меню выбора — есть смысл перепройти на S.

Экран результатов даёт ещё и теплокарту блужданий: где ты потратил больше всего времени, там ярче. Сразу видно, где именно ты заблудился.""",
	"body_en": """After every level a rank from S to D is computed from four criteria: the fraction of shards collected, whether you took no damage, whether you used no abilities, and whether you beat the par time. The results screen shows not just a letter but a breakdown: what counted and what fell short.

Rank is not decoration, it MULTIPLIES rewards: S gives x1.5 to experience and ember, A x1.25, B x1.0, C x0.85, D x0.7. Clean play noticeably accelerates progression.

Streaks work both ways and both help you. Several A or S ranks in a row grant the Maze's Blessing — a small starting bonus on the next level. Several D ranks in a row grant Mercy: the maze places a guaranteed station near your start (in Blazing it simply adds Light).

Your best rank per level is remembered and shown on that level's button in the select screen — there is a point in replaying for an S.

The results screen also gives a wander heatmap: the more time you spent somewhere, the brighter it glows. You can see at a glance exactly where you got lost.""",
},
{
	"sec": "progress", "id": "journal", "fig": "progress_journal",
	"title": "Дневник, Бестиарий, профили", "title_en": "Journal, Bestiary, profiles",
	"body": """ДНЕВНИК — карусель слайдов, каждый читается одним взглядом. Обзор с цифрами и полоской рангов; Твой стиль с иконками навыков, их применениями и прогнозом формы Апекса; Путь мастерства — коуч-программа, которая не комментирует игру, а учит шаг за шагом; история последних уровней столбиками; Голос лабиринта с наблюдениями о твоей игре; результаты Спуска дня и забегов Накала.

БЕСТИАРИЙ — досье на каждого врага: портрет, лор, конкретная тактика и твои счётчики «встречено / убито / погиб от него». Карточка скрыта под «???», пока ты врага не встретил, и раскрывается полностью после первой победы. Отдельный слайд «Текущая угроза» объясняет, почему враги стали злее именно у тебя: сколько ты несёшь Накала, какая глубина.

ПРОФИЛИ — на одной машине может играть несколько человек. Профиль это полностью отдельное сохранение, включая настройки. Сброс прогресса действует только на текущего игрока. Переключение — в настройках.""",
	"body_en": """THE JOURNAL — a carousel of slides, each readable at a glance. Overview with numbers and a rank strip; Your Style with skill icons, use counts and an Apex form forecast; Path of Mastery — a coaching programme that does not comment on your play but teaches step by step; recent level history as bars; Voice of the Maze with observations about your play; Daily Dive results and Ember runs.

THE BESTIARY — a dossier on every enemy: portrait, lore, concrete tactics and your «met / killed / died to» counters. A card stays hidden behind «???» until you have met that enemy, and opens fully after your first kill. A separate «Current threat» slide explains why enemies got meaner specifically for you: how much ember you carry, what depth you are at.

PROFILES — several people can play on one machine. A profile is a fully separate save, settings included. Resetting progress affects only the current player. Switching is in the settings.""",
},
]

# Заголовок раздела или статьи на текущем языке.
static func title_of(d: Dictionary) -> String:
	return str(d["title_en"]) if GameConfig.locale == "en" else str(d["title"])

static func body_of(d: Dictionary) -> String:
	return str(d["body_en"]) if GameConfig.locale == "en" else str(d["body"])

# Индексы статей раздела sid в порядке объявления.
static func articles_in(sid: String) -> Array:
	var out: Array = []
	for i in ARTICLES.size():
		if str((ARTICLES[i] as Dictionary)["sec"]) == sid:
			out.append(i)
	return out
