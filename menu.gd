extends Control

# Главное меню: Играть / Настройки / Выход.
# Настройки правят синглтон GameConfig, который читает игра.

var _menu_box: VBoxContainer
var _settings_box: VBoxContainer
var _settings_scroll: ScrollContainer
var _level_box: ScrollContainer
var _level_inner: VBoxContainer
var _level_grid: GridContainer
var _boss_section: VBoxContainer  # секция тест-боссов в выборе уровней

# Режим «Логово»: выбор одного из 10 уровней с боссом в центре лабиринта.
var _lair_box: ScrollContainer
var _lair_grid: GridContainer
# [CODEX §30] Кодекс — двухколоночный экран вместо прежней карусели слайдов
# Справки: слева навигация (разделы и статьи), справа сама статья с картинкой.
# Данные статей — в codex.gd, здесь только UI и сборка картинок.
var _codex_root: HBoxContainer      # корень экрана (скрыт, пока не открыт)
var _codex_nav: ScrollContainer     # левая колонка со списком статей
var _codex_nav_box: VBoxContainer
var _codex_article: ScrollContainer # правая колонка — тело статьи
var _codex_body: VBoxContainer
var _codex_entries: Array = []      # плоский список статей (данные + версии)
var _codex_buttons: Array = []      # кнопки навигации, индекс = индекс статьи
var _codex_idx: int = -1

# [CAROUSEL-BOUNDS] Обёртки-ScrollContainer карточек каруселей — высоту им
# считает _fit_carousel (по контенту, но не выше окна).
var _root_col: VBoxContainer       # центрированная колонка всей страницы меню
var _journal_slide_scroll: ScrollContainer
var _bestiary_slide_scroll: ScrollContainer
var _back_btn: Button

# Режим «Накал»: панель выбора слота-забега и брифинг.
# Оба — ScrollContainer (не голый VBoxContainer): на низких окнах список
# слотов/текст брифинга длиннее экрана, а CenterContainer центрирует
# несворачиваемый контент — верх и низ (в т.ч. кнопка «Назад») уезжают за
# кадр (см. жалобу «кнопки за пределами экрана» — та же причина, что была
# у settings/help/journal, отсюда и общий приём с _fit_panels()).
var _runs_box: ScrollContainer
var _runs_slots_box: VBoxContainer
var _briefing_box: ScrollContainer
var _briefing_slot: int = 0
var _briefing_contracts_box: VBoxContainer
var _briefing_contract: String = ""   # выбранный контракт спуска ("" — без)

# [JOURNAL-CAROUSEL] Дневник лабиринта — карусель слайдов (тот же паттерн,
# что у Кодекса: раньше был один длинный скролл из 8
# текстовых панелей подряд — чтобы увидеть общую картину, нужно было долго
# скроллить, и цифры/инфографика тонули в тексте. Теперь один слайд = один
# самодостаточный визуальный раздел. _journal_scroll — внешняя обёртка
# (заголовок + стрелки), _journal_box — контейнер ТЕКУЩЕГО
# слайда. Состав и число слайдов зависят от прогресса игрока
# («Путь к навыкам»/«Спуск дня» не показываются, если там нечего показывать),
# поэтому список пересобирается при каждом открытии — см. _journal_rebuild_slides.
var _journal_scroll: VBoxContainer
var _journal_box: VBoxContainer
var _journal_nav_label: Label
var _journal_prev_btn: Button
var _journal_next_btn: Button
var _journal_slide_idx: int = 0
var _journal_slides: Array = []   # [{title:String, build:Callable}]

# Спуск дня: ежедневный забег с сидом от даты, одна попытка в день.
var _daily_box: ScrollContainer
var _daily_inner: VBoxContainer

# [BESTIARY-CAROUSEL] Бестиарий «Досье лабиринта» — карусель слайдов (тот же
# паттерн, что у Дневника): раньше один длинный скролл (шапка + угроза
# + 6 карточек врагов подряд) тонул в тексте. Теперь один слайд = «Текущая
# угроза» + по одному слайду на каждого врага, крупнее и просторнее.
var _bestiary_scroll: VBoxContainer
var _bestiary_box: VBoxContainer
var _bestiary_nav_label: Label
var _bestiary_prev_btn: Button
var _bestiary_next_btn: Button
var _bestiary_slide_idx: int = 0
var _bestiary_slides: Array = []   # [{title:String, build:Callable}]

# Выбор режима после «Играть»: Уровни (продолжить/выбрать) или Накал.
var _mode_scroll: ScrollContainer
var _mode_box: VBoxContainer

const LEVEL_COUNT := 50
const SETTINGS_W := 560   # единая ширина строк в настройках

# История версий — раздел «Что нового» в Кодексе и окно «О версиях» (настройки).
# Короткие порции новостей; та же RU/EN пара функций
# (_changelog_text) собирает из них полный текст для модального окна «О версиях».
const CHANGELOG_112_A := """• Свет перестал быть таймером — теперь это ручка, которой ты управляешь. СТОЙКА СВЕТА: Z / X или колесо мыши.
• ЯРКИЙ — видишь заметно дальше: раньше находишь осколки, портал и развилки. Но Свет горит в 2.4 раза быстрее, и враги замечают тебя почти вдвое дальше.
• ТУСКЛЫЙ — расход падает до 0.45, тебя почти не видят. Взамен идёшь вслепую и чуть медленнее."""
const CHANGELOG_112_B := """• Стойка бесплатна и работает постоянно — это НЕ Тление: Тление по-прежнему короткий рывок в невидимость за Волю и с кулдауном, аварийная кнопка. Стойка — то, как ты живёшь между станциями.
• В HUD рядом с полосами Света и Воли появился индикатор стойки: три сегмента и текущий множитель расхода — цену решения видно сразу, гадать не нужно.
• Тление перебивает любую стойку, так что аварийный побег работает и из Яркой."""
const CHANGELOG_113_A := """• У навыков появилась ГРОМКОСТЬ. Враг в радиусе слышимости идёт проверять источник — даже через стену, даже если тебя не видел. Заметность это «видно ли тебя», шум — «слышно ли».
• В момент каста расходится кольцо: оранжевое — услышали и пошли, голубое — рядом никого. Цену нажатия видно сразу.
• Громче всех Разлом и Сонар, тише всех Искра и Щит. Тление и Мираж бесшумны совсем: одно прячет, у второго своя приманка.
• Тление глушит любой каст, а стойка света слышна: Тусклая тише, Яркая громче — раздутый свет гудит.
• Сонар больше не бесплатная разведка: он покажет планировку и позовёт Стража. Иногда верный ход — пройти вслепую."""
const CHANGELOG_113_B := """• СЕРИЯ ОСКОЛКОВ: собранные подряд без урона осколки идут в серию, и каждый следующий дороже — множитель опыта растёт на 0.25 за осколок, до ×2.5. Серия и текущий множитель видны в HUD рядом со счётчиком.
• Удар врага серию обрывает, и игра прямо говорит «серия ×5 прервана» — раньше множитель исчезал бы молча.
• НАГРАДА НА МЕСТЕ: у осколка всплывает «+94 XP» и «+Воля», у убитого врага «+30 XP». Раньше вся награда раскрывалась только в меню и на экране результатов, то есть уже после момента, когда ты принимал решение."""
const CHANGELOG_114_A := """• ЭСКАЛАЦИЯ: у уровня появились стадии по времени. Порог считается от нормы времени уровня, поэтому «долго» на 50-м и на 1-м — разные числа секунд.
• После нормы времени тьма густеет: обзор ужимается, по краям экрана холодная кромка.
• Примерно вдвое дольше нормы просыпается ЛОВЧИЙ — крупный розовый враг, который НЕ ТЕРЯЕТ СЛЕД. Стены, темнота и Тление на него не влияют: от него можно уйти, но нельзя спрятаться.
• Уравновешивает его только скорость — он на четверть медленнее обычного, а заморозка действует как на всех.
• Смысл: раньше давила только ровная утечка Света, и первая минута ощущалась как четвёртая. Теперь у прохождения есть ритм — сначала исследуй, потом уходи."""
const CHANGELOG_115_A := """• РОЛИ ВРАГОВ: враг теперь отличается не только цифрами, но и поведением. Статы у роли те же, что у её типа — другое ДЕЙСТВИЕ.
• ЗАГОНЩИК (с 8-го уровня, жёлтая подсветка) идёт не к тебе, а к клетке, через которую ты собирался уйти. Перекрывает выход и выдавливает в тупик. Бежать быстрее бесполезно — надо ломать маршрут: рывок сквозь него, Разлом в стороне, срезка. В тупике ведёт себя как обычный враг.
• МИМИК (с 12-го уровня) — подделка под станцию: тот же кристалл, то же дыхание, на глаз не отличить. Подойдёшь — багровеет и превращается в быстрого врага. Не бьёт в момент превращения: это ловушка, а не наказание за подход к станции.
• Мимики стоят среди настоящих станций и живут в Лазурных шахтах; загонщик — в Багровых недрах, в Пустотах вдвое реже. В Пылающем мимиков нет: там станций не бывает, и подделка выдала бы себя."""
const CHANGELOG_116_A := """• В «Пылающем» вернулись темы биомов: ямы и порталы-срезки теперь есть и там. Раньше самая сложная сложность играла беднее лёгкой — биомы теряли темы. Тёмных станций и мимиков там по-прежнему нет: первым нечем восполнить вытянутый Свет, вторым нечем маскироваться, если станций не бывает.
• Биом задаёт терпение лабиринта: в Лазурных шахтах эскалация приходит позже (уровень про поиск маршрута), в Споровых пустотах раньше (там тебя и так видно издалека).
• Серия чистых осколков теперь множит не только опыт, но и НАКАЛ: в забеге аккуратность — главная валюта.
• Роль загонщика с 30-го уровня может достаться СТРАЖУ: медленный и бронированный, перекрывать выход — ровно его работа.
• Исправлено: бросок на роль загонщика делался на каждого врага, из-за чего при шансе 50% он появлялся почти всегда, а Страж не мог получить роль вовсе. Теперь бросок один на уровень."""
const CHANGELOG_32_A := """• СПОРОВЫЕ ПУСТОТЫ ПОЛУЧИЛИ СВОЙ МАТЕРИАЛ — третий и последний пилот плана материалов биомов. Стены заросли: мох поверх породы, редкие светящиеся споры-крапинки, вьющаяся плеть через панель.
• Все три биома теперь визуально самостоятельны и держат три разных приёма: Багровые недра — резкий шум и рваный край (§49), Лазурные шахты — целочисленная сетка и заклёпки (§50), Споровые пустоты — мягкий низкочастотный шум и растушёванный край (§51).
• Геометрия снова не тронута — другой только рисунок поверх той же клетки."""
const CHANGELOG_32_A_EN := """• THE SPORE WASTES GOT THEIR OWN MATERIAL — the third and final pilot of the biome-materials plan. The walls are overgrown: moss over rock, rare glowing spore flecks, a vine curling across each panel.
• All three biomes are now visually distinct and hold three different techniques: the Crimson Depths — sharp noise and a ragged edge (§49), the Azure Mines — an integer grid and rivets (§50), the Spore Wastes — soft low-frequency noise and a feathered edge (§51).
• Geometry is untouched again — only the artwork over the same cell differs."""
const CHANGELOG_31_A := """• ЛАЗУРНЫЕ ШАХТЫ ПОЛУЧИЛИ СВОЙ МАТЕРИАЛ — второй пилот плана материалов биомов (§49 сделал Багровые недра органикой). Стены здесь теперь инопланетный техноцех: разметка на пластины по строгой сетке, заклёпки на стыках, тонкая энергетическая жила через панель.
• В отличие от Багровых недр (шум, рваный край, нарост) тут всё ровно и целочисленно: техника размечена, а не выросла — два материала теперь читаются как противоположные полюса одной идеи.
• Геометрия (столкновения, тени) снова не тронута — другой только рисунок поверх той же формы клетки."""
const CHANGELOG_31_A_EN := """• THE AZURE MINES GOT THEIR OWN MATERIAL — the second pilot of the biome-materials plan (§49 made the Crimson Depths organic). The walls here are now alien tech-works: a strict grid of panel seams, rivets at the joints, a thin energy vein running through each plate.
• Unlike the Crimson Depths (noise, ragged edge, growth), everything here is straight and on-grid: engineering, not growth — the two materials now read as opposite poles of the same idea.
• Geometry (collisions, shadows) is untouched again — only the artwork over the same cell shape differs."""
const CHANGELOG_30_A := """• БАГРОВЫЕ НЕДРА ПОЛУЧИЛИ СВОЙ МАТЕРИАЛ. Первый пилот плана «текстуры вместо оттенка» (идея записана 01.08.2026): стены этого биома больше не техно-панель другого цвета — теперь это сегментированный панцирь с тёплыми прожилками, будто выращенный, а не построенный.
• Рваный светящийся край вместо гладкой фаски: у каждой открытой стороны своя ширина оплыва, «дрожащая» шумом — контур читается как нарост, а не станок с ЧПУ.
• Тело стены — сегменты панциря (ячеистый узор) поверх бугров и мелкой ряби: тёмные швы между пластинами, разная яркость внутри каждой.
• Геометрия (столкновения, тени) не изменилась ни на пиксель — другой только рисунок поверх той же формы."""
const CHANGELOG_30_A_EN := """• THE CRIMSON DEPTHS GOT THEIR OWN MATERIAL. First pilot of the «textures instead of tint» plan (idea recorded 01.08.2026): this biome's walls are no longer a tech panel in a different colour — now a segmented carapace with warm veins, as if grown rather than built.
• A ragged glowing edge instead of a clean bevel: each open side gets its own bloom width, «trembling» with noise — the outline reads as an outgrowth, not a CNC-milled panel.
• The wall body is carapace segments (a cellular pattern) over bumps and fine grain: dark seams between plates, uneven brightness within each.
• Geometry (collisions, shadows) is unchanged down to the pixel — only the artwork over the same shape differs."""
const CHANGELOG_29_A := """• ИСПРАВЛЕН СТОЛП ЗАЛА-ОРИЕНТИРА. С версии 2.1 его масштаб (0.42, 3.4) на текстуре 110px давал видимую высоту 374px — почти 8 клеток, и он простреливал стены на несколько тайлов вверх и вниз (жалоба игрока со скриншотом: свет как будто протекал сквозь сплошную стену). Высота ограничена площадкой зала — столп больше не выходит за её пределы.
• У СТАНЦИИ УБРАНО КОЛЬЦО-ШКАЛА. Заряд и передача теперь читаются ЧИСТЫМ СВЕЧЕНИЕМ: заряжена — горит ярко и заметно, отдаёт или восстанавливается — едва тлеет.
• Свет и ореол станции сделаны короче: она читается только вблизи, а не через весь этаж, — в отличие от столпов залов, которые специально яркие и дальнобойные, потому что у них противоположная роль (ориентир, а не укрытие). Когда играешь с Озарением или Сонаром, увидеть станцию издалека и сквозь стены получится всё равно — вместе с общим расширением обзора."""
const CHANGELOG_29_A_EN := """• FIXED THE LANDMARK HALL PILLAR. Since version 2.1 its scale (0.42, 3.4) on a 110px texture gave a visible height of 374px — nearly 8 tiles — and it pierced through walls several tiles up and down (player's screenshot: light seemed to leak through solid rock). Height is now capped to the hall's own footprint.
• THE STATION'S GAUGE RING IS GONE. Charge and transfer now read through PURE GLOW alone: full means it burns bright and noticeable, giving or recharging means it barely smoulders.
• The station's light and halo were shortened: it only reads up close, not across the whole floor — unlike the landmark hall pillars, which are deliberately bright and far-reaching because their job is the opposite (a landmark, not a shelter). Playing with Reveal or Sonar still lets you see the station from afar and through walls — it comes along with the wider view for free."""
const CHANGELOG_28_A := """• СТАНЦИЯ ПЕРЕДАЁТ СВЕТ, А НЕ ВЫДАЁТ ЕГО ЩЕЛЧКОМ. Раньше весь глоток приходил в момент входа за один кадр. Теперь между кристаллом и тобой тянется луч, и передача идёт около секунды: кристалл тускнеет по мере того, как отдаёт, а ты получаешь Свет постепенно.
• Уйдёшь раньше конца передачи — луч обрывается, а станция остаётся такой же тусклой, какой успела стать: вернуться и дожать бесплатно нельзя.
• Итоговое количество Света, Воли и заряда Озарения не изменилось — платит тот же «глоток», просто он теперь растянут во времени и виден глазами."""
const CHANGELOG_28_A_EN := """• A STATION TRANSFERS LIGHT INSTEAD OF SNAPPING IT OVER. The whole sip used to arrive in a single frame on entry. Now a beam stretches between the crystal and you, and the transfer takes about a second: the crystal dims as it gives, and you receive Light gradually.
• Leave before the transfer finishes and the beam snaps — the crystal stays as dim as it got, so you cannot come back and finish it for free.
• The total Light, Will and Reveal charge you receive is unchanged — it is the same «sip», just spread out over time and visible."""
const CHANGELOG_27_A := """• Исправлены станции зарядки: они были втрое-вчетверо крупнее клетки и налезали друг на друга. Ошибка версии 2.4 — уменьшение спрайта выставлялось один раз при создании, а анимация «дыхания» каждый кадр перезаписывала масштаб целиком и стирала его.
• Заодно станция уменьшена по существу: даже без этой ошибки она была 40×67 при клетке 48, то есть выше клетки и вылезала за сетку. Теперь 28×47 — вписывается целиком.
• Ореол и свет станции ужаты под новый размер: вокруг маленькой капсулы больше не висит облако в четыре клетки."""
const CHANGELOG_27_A_EN := """• Fixed the charge stations: they were three to four times larger than a grid cell and overlapped each other. A bug from version 2.4 — the sprite downscale was applied once on creation, while the breathing animation overwrote the scale wholesale every frame and erased it.
• The station was also made smaller on its own merits: even without that bug it was 40×67 against a 48 cell, taller than the tile and sticking out of the grid. It is now 28×47 and fits entirely.
• The station halo and light were tightened to the new size: a small capsule no longer sits inside a four-tile cloud of glow."""
const CHANGELOG_26_A := """• СВЕТ СТАЛ ЛУЧОМ. Раньше видимость была ровным кругом вокруг тебя. Теперь ты видишь заметно дальше туда, куда идёшь, и хуже по сторонам: развернуться — это действие, а не бесплатное движение мыши.
• Оказалось, что фонарь-конус у игрока был всё это время (он и тени бросал) — но круглая виньетка срезала ровно то, что он освещал. Направленный СВЕТ существовал, направленной ВИДИМОСТИ не было.
• Стойка света теперь меняет ФОРМУ луча, а не только расход. ТУСКЛАЯ — узкий и самый дальний фонарь-щуп: один коридор далеко вперёд. ЯРКАЯ — широкая заливка: во все стороны, но недалеко. РОВНАЯ — компромисс."""
const CHANGELOG_26_B := """• Тление гасит и луч: крадёшься — видишь только под ногами. Иначе Тление было бы ещё и бесплатной разведкой.
• Озарение и Сонар раскрывают обзор кругом, поэтому на их время луч почти отключается — «увидеть всё вокруг» не должно превращаться в «увидеть всё впереди».
• Направление и дальность луча сглаживаются: резкий скачок при развороте читался бы как рывок камеры."""
const CHANGELOG_26_A_EN := """• LIGHT IS NOW A BEAM. Visibility used to be an even circle around you. You now see noticeably further where you are heading and worse to the sides: turning is an action, not a free mouse flick.
• It turned out the player had a cone flashlight all along (it even cast shadows) — but the circular vignette cut off exactly what it lit. Directional LIGHT existed; directional VISIBILITY did not.
• The light stance now changes the SHAPE of the beam, not just the drain. DIM — a narrow, longest-reaching probe: one corridor far ahead. BRIGHT — a wide wash: every direction, but not far. EVEN — a compromise."""
const CHANGELOG_26_B_EN := """• Smother dims the beam too: while creeping you see only underfoot. Otherwise smother would also be free scouting.
• Reveal and Sonar open your view in a circle, so the beam nearly switches off while they last — «see everything around» must not become «see everything ahead».
• Beam direction and reach are smoothed: a hard snap on turning would read as a camera jerk."""
const CHANGELOG_25_A := """• КЛЮЧИ НАКОНЕЦ РАБОТАЮТ. Оказалось, что запертых дверей в игре не бывало ВООБЩЕ: пара дверей на этаж была всего одна, а первая пара по коду всегда открыта. Ключи копились, тратить их было не на что, а Кодекс и обучение при этом обещали «осколок — это ключ от дверей между этажами».
• С 4-го уровня на этаже появляется ВТОРАЯ пара дверей — запертая, с замком. Обычная открытая дверь никуда не девается, поэтому застрять без ключей невозможно: запертая дверь это короткий путь, то есть выбор, а не преграда.
• Так у осколков появилась вторая причина существовать помимо улик о выходе."""
const CHANGELOG_25_B := """• ОЗАРЕНИЕ И СОНАР ТЕПЕРЬ ИЩУТ. Радиус, в котором засчитывается «увидел портал», был константой в 5 клеток — Озарение могло осветить полэтажа с порталом на экране, а игра считала, что ты его не видел. Теперь Озарение расширяет этот радиус вчетверо, Сонар вдвое.
• Веха Сонара снижена с 25 осколков до 12: она ставилась, когда осколки были обязательными и набирались по 10-15 за уровень. После версии 2.0 сбор необязателен, и старый порог держал главный инструмент разведки запертым впятеро дольше задуманного.
• Экономика забега «Накал» подтянута под новые правила: улика о выходе приносит Накал (12), бонус за пройденный этаж поднят с 25 до 35. Доход просел вместе с необязательностью осколков, хотя риск не изменился."""
const CHANGELOG_25_A_EN := """• KEYS FINALLY DO SOMETHING. It turned out locked doors never existed at all: there was only one door pair per floor, and the first pair is always unlocked by design. Keys piled up with nothing to spend them on, while the Codex and the tutorial promised «a shard is a key for doors between floors».
• From level 4 a SECOND door pair appears on the floor — locked, with a padlock. The ordinary open door remains, so you can never be stranded without keys: a locked door is the short way, a choice rather than an obstacle.
• Shards now have a second reason to exist besides clues about the exit."""
const CHANGELOG_25_B_EN := """• REVEAL AND SONAR NOW SEARCH. The radius that counts as «you saw the portal» was a constant 5 cells — Reveal could light up half the floor with the portal on screen and the game still considered it unseen. Reveal now widens that radius fourfold, Sonar twofold.
• The Sonar milestone dropped from 25 shards to 12: it was set when shards were mandatory and came in at 10-15 per level. Since 2.0 collecting is optional, and the old threshold kept the main scouting tool locked five times longer than intended.
• Ember run economy adjusted to the new rules: a clue about the exit pays Ember (12), and the per-floor bonus rose from 25 to 35. Income had dropped along with shards becoming optional, while the risk stayed the same."""
const CHANGELOG_24_A := """• ЛАБИРИНТЫ СНОВА ЛАБИРИНТЫ. На первых уровнях стен почти не оставалось: на сетке 16×10 вырезалось до ПЯТИ комнат (одни в общем карвинге, ещё две-три в теме Лазурных шахт), каждая до 4×4, плюс до 22% лишних проходов. Замер открытости показывал 0.71 при норме лабиринта ~0.50 — это были комнаты, а не лабиринт.
• Теперь число и размер комнат считаются от площади этажа: на уровнях 1-2 комнат нет вовсе, дальше они растут вместе с лабиринтом. Открытость первых уровней вернулась к 0.55-0.58 — как на уровнях, которые игрались нормально.
• Артерия и залы-ориентиры (2.1) больше не режутся на мелких этажах: на 16×10 сквозной коридор с залами был не скелетом, а сносом лабиринта."""
const CHANGELOG_24_B := """• Обучение больше не просит нажать навык, которого у тебя нет. Этап 2 требовал C (Щит) и E (Сонар) — они покупаются за SP, и у новичка их не было: шаг становился непроходимым, а кнопка молча не работала. В обучении все навыки считаются открытыми (сейв при этом не меняется).
• Осколок больше не ложится поверх станции зарядки. Осколки выбирали клетки независимо и не знали о станциях — два предмета сливались в один.
• СТАНЦИЯ ПЕРЕРИСОВАНА. Пиксельная лесенка была от разрешения: картинка ~24×48 растягивалась на клетку 48px. Теперь рендер в 4× с уменьшением, вокруг — мягкий ореол. Силуэт тоже сменился: вместо двух усов-антенн (из-за них станция и читалась как жук) — клемма сверху и энергетические пояса поперёк капсулы.
• Запертая дверь между этажами показывает ЗАМОК. Раньше это был янтарный кружок того же цвета, что осколок-ключ, и он читался как предмет, который почему-то нельзя подобрать."""
const CHANGELOG_24_A_EN := """• MAZES ARE MAZES AGAIN. Early levels had almost no walls left: on a 16×10 grid up to FIVE rooms were carved (some by the general pass, two or three more by the Azure Mines theme), each up to 4×4, plus up to 22% extra openings. The measured openness was 0.71 against a maze norm of ~0.50 — those were rooms, not a maze.
• Room count and size now scale with floor area: levels 1-2 get no rooms at all, and rooms grow together with the maze. Early-level openness is back to 0.55-0.58 — the same range as levels that played fine.
• The artery and landmark halls (2.1) are no longer carved on small floors: on 16×10 a through-corridor with halls was not a skeleton but a demolition."""
const CHANGELOG_24_B_EN := """• The tutorial no longer asks you to press a skill you do not have. Stage 2 required C (Shield) and E (Sonar), which are bought with SP: the step was impossible and the key silently did nothing. In the tutorial every skill counts as unlocked (your save is not modified).
• Shards no longer spawn on top of charge stations. Shards picked cells independently and knew nothing about stations — two objects merged into one.
• THE STATION WAS REDRAWN. The pixel staircase came from resolution: a ~24×48 image stretched onto a 48px tile. It is now rendered at 4× and scaled down, with a soft halo around it. The silhouette changed too: instead of two antenna prongs (which made it read as a bug) it has a terminal on top and energy bands across the capsule.
• A locked door between floors now shows a LOCK. It used to be an amber circle in the exact colour of the shard-key, so it read as an item that for some reason could not be picked up."""
const CHANGELOG_23_A := """• РАНГ ТЕПЕРЬ НАГРАЖДАЕТ ИГРУ, А НЕ ВОЗДЕРЖАНИЕ. Раньше S математически требовал НЕ ПОЛЬЗОВАТЬСЯ навыками: премия «без способностей» давала +15, а без неё максимум был 85 при пороге 95. Оптимальная игра была скучной игрой.
• Новые четыре критерия: СКОРОСТЬ (30), БЕЗ ПОТЕРЬ (25), СВОЯ ЗЕМЛЯ (25 — доля времени на захваченной территории), НАВЫКИ (20 — за применение, а не за отказ).
• Осколки на ранг больше не влияют. Они необязательны с версии 2.0, и половина шкалы за их долю штрафовала ровно за то, ради чего всё делалось: найти выход, не подметая этаж."""
const CHANGELOG_23_B := """• НОРМА ВРЕМЕНИ пересчитана под поиск. Раньше это была формула от номера уровня (20 + уровень×12), придуманная под обязательный сбор всех осколков. Теперь она считается от длины оптимального маршрута, площади этажа и числа этажей — то есть от того, сколько уровень ЧЕСТНО занимает.
• ОБУЧЕНИЕ переписано под нынешние правила. Оно учило «собери все осколки, и портал откроется» — правила, которого в игре больше нет. Теперь урок про осколок объясняет улики, добавлен шаг про захваченную землю, а финальный шаг честно называется «НАЙДИ выход — он не отмечен на карте».
• В обучении портал больше не заперт, улики работают, след захваченной земли виден — обучение и игра наконец про одно и то же."""
const CHANGELOG_23_A_EN := """• RANK NOW REWARDS PLAYING, NOT ABSTAINING. An S used to mathematically require NOT USING skills: the «no abilities» bonus gave +15, and without it the maximum was 85 against a threshold of 95. Optimal play was boring play.
• Four new criteria: SPEED (30), NO LOSSES (25), HELD GROUND (25 — share of time on claimed territory), SKILLS (20 — for using them, not for refusing).
• Shards no longer affect the rank. They have been optional since 2.0, and half the scale riding on their fraction punished exactly what the change was for: finding the exit without sweeping the floor."""
const CHANGELOG_23_B_EN := """• PAR TIME recalculated for searching. It used to be a formula on the level number (20 + level×12), designed around collecting every shard. It is now derived from the optimal route length, the floor area and the number of floors — that is, from how long the level HONESTLY takes.
• THE TUTORIAL has been rewritten for the current rules. It taught «collect all shards and the portal opens» — a rule the game no longer has. The shard lesson now explains clues, a step about held ground was added, and the final step is honestly called «Now FIND the exit — it is not marked on your map».
• In the tutorial the portal is no longer sealed, clues work and the smouldering trail is visible — the tutorial and the game are finally about the same thing."""
const CHANGELOG_22_A := """• ТЬМА ОТБИРАЕТ ТЕРРИТОРИЮ. Клетки, по которым ты прошёл, остаются тлеть — это твоя земля. Тьма отвоёвывает её обратно, и тем быстрее, чем ярче ты горишь: в Яркой стойке коридор за спиной гаснет за ~23 секунды, в Ровной за 40, в Тусклой за 70 с лишним. Тление держит тыл дольше всего.
• У земли есть ЦЕНА: на своей Свет течёт медленнее (×0.85), на отвоёванной тьмой — быстрее (×1.15).
• Зачем: до сих пор тьма ничего не ДЕЛАЛА — она была декорацией и таймером расхода. Бороться можно только с тем, что давит в ответ. Теперь свет — не только то, что ты тратишь, но и то, что ты удерживаешь."""
const CHANGELOG_22_B := """• Появилось решение, которого не было: разогнать свет и видеть дальше, теряя тыл, — или пригаситься и удержать коридор за спиной.
• На миникарте своя земля светится, отвоёванная тускнеет до серого. Память о карте при этом не стирается НИКОГДА — иначе Пульс гнал бы тебя назад по уже пройденному, и поиск превратился бы в бег по кругу.
• В обучении, на аренах и в Логове механика выключена — там своя режиссура."""
const CHANGELOG_22_A_EN := """• THE DARK TAKES GROUND BACK. The cells you walk through keep smouldering — that ground is yours. The dark reclaims it, and the brighter you burn the faster: in the Bright stance the corridor behind you goes out in ~23 seconds, in Even 40, in Dim over 70. Smother holds your rear the longest.
• Ground has a PRICE: Light drains slower on your own (×0.85) and faster on reclaimed ground (×1.15).
• Why: until now the dark DID nothing — it was scenery and a drain timer. You can only fight something that pushes back. Now light is not only what you spend but also what you hold."""
const CHANGELOG_22_B_EN := """• A decision that did not exist before: burn bright and see further while losing your rear, or dim down and hold the corridor behind you.
• On the minimap your ground glows and reclaimed ground fades to grey. Map memory is NEVER erased — otherwise the Pulse would drive you back over ground you already walked, and searching would become running in circles.
• The mechanic is off in the tutorial, in arenas and in the Lair — those have their own staging."""
const CHANGELOG_21_A := """• СКЕЛЕТ ЭТАЖА. У каждого этажа появилась АРТЕРИЯ — сквозной прямой коридор с тусклой разметкой по полу — и ЗАЛЫ на ней: две-три открытые площадки со СТОЛПАМИ СВЕТА своего цвета (бирюзовый, янтарный, аметистовый).
• Столп видно ИЗДАЛЕКА — сквозь тьму пробивается его зарево на краю зрения. Появились приметы: «иду от янтарного к бирюзовому» — это уже маршрут, а не блуждание.
• Зачем: искать выход можно только там, где о пространстве можно построить догадку. В однородном случайном лабиринте улика «выход в северо-восточной части» оставалась числом — идти всё равно приходилось наугад. Теперь зарево ориентира отвечает, где северо-восток ОТСЮДА."""
const CHANGELOG_21_B := """• Артерия работает и как магистраль: по ней быстро попадаешь в любую часть этажа. Заблудился — выходи на артерию.
• Скелет режется поверх уже связного лабиринта и только ОТКРЫВАЕТ стены, поэтому проходимость и достижимость выхода не могут пострадать (проверено харнессом на шести уровнях)."""
const CHANGELOG_21_A_EN := """• THE FLOOR'S SKELETON. Every floor now has an ARTERY — a straight through-corridor with dim floor marks — and HALLS along it: two or three open plazas with PILLARS OF LIGHT in their own colours (teal, amber, amethyst).
• A pillar is visible FROM AFAR — its glow cuts through the dark at the edge of your vision. You finally have landmarks: «walking from the amber one to the teal one» is a route, not wandering.
• Why: you can only search a space you can form a guess about. In a uniform random maze the clue «the exit lies north-east» stayed a number — you still had to walk blind. Now a landmark's glow answers where north-east is FROM HERE."""
const CHANGELOG_21_B_EN := """• The artery doubles as a highway: it takes you quickly to any part of the floor. Lost? Get back to the artery.
• The skeleton is carved on top of an already-connected maze and only OPENS walls, so connectivity and the reachability of the exit cannot break (verified by a harness across six levels)."""
const CHANGELOG_20_A := """• ВЫХОД ТЕПЕРЬ НАДО ИСКАТЬ. Портал больше не заперт осколками — он открыт всегда, но где он, ты не знаешь. Раньше выход отпирался только после сбора ВСЕХ осколков уровня, поэтому ответ на вопрос «куда идти» всегда был один — «везде», и уровень сводился к подметанию сетки.
• Осколок стал УЛИКОЙ. Первый называет этаж выхода, второй — сторону света, третий — примерное расстояние, четвёртый сводит всё в точку на карте. Осколки необязательны: они покупают знание, а не очки.
• Осколок остаётся ключом от дверей между этажами. Поэтому «сколько собрать» — это решение: и знание, и открытые двери стоят осколков."""
const CHANGELOG_20_B := """• Можно набрести на портал самому — подошёл близко, и он отмечен на карте без всяких улик. Быстро и вслепую против медленно и наверняка — это и есть выбор, которого уровню не хватало.
• Искра (G) ведёт к порталу только после того, как выход найден; до этого — к осколкам, то есть к уликам. Пульс (B) молчит, пока искать нечего, и честно об этом говорит.
• Метка выхода на миникарте появляется только когда он найден.
• В обучении всё по-старому: там «собери всё и уходи» — нормальный первый урок."""
const CHANGELOG_20_A_EN := """• THE EXIT NOW HAS TO BE FOUND. The portal is no longer sealed by shards — it is always open, but you do not know where it is. Previously it unsealed only after collecting EVERY shard on the level, so the answer to «where do I go» was always «everywhere», and a level came down to sweeping the grid.
• A shard is now a CLUE. The first names the exit floor, the second the compass side, the third the rough distance, the fourth pins it on your map. Shards are optional: they buy knowledge, not points.
• A shard remains the key to doors between floors. So «how many to collect» is a decision: both knowledge and open doors cost shards."""
const CHANGELOG_20_B_EN := """• You can stumble onto the portal yourself — get close and it is marked on your map with no clues at all. Fast and blind versus slow and certain: that is the choice the level was missing.
• The Guide spark (G) leads to the portal only once the exit is located; until then it leads to shards, that is, to clues. The Pulse (B) stays silent while there is nothing to measure, and says so honestly.
• The exit marker appears on the minimap only once the exit is found.
• The tutorial keeps the old rules: there, «collect everything and leave» is a fine first lesson."""
const CHANGELOG_118_A := """• ЛЕСТНИЦА ОТКРЫТИЙ. Механики больше не появляются молча и вразнобой: у каждой есть свой уровень входа, а в момент входа лабиринт показывает карточку «Новое: …» с одной строкой о том, что это такое. Один раз за всё время, не в каждом забеге.
• Порядок выправлен по биомам. Раньше Шахты на уровнях 1-5 обещали порталы-срезки, которые открывались только на 8-м, а Недра 6-10 — провалы, ждавшие 15-го уровня: игра говорила о правилах, которых ещё не было. Теперь механика входит ВНУТРИ полосы своего биома.
• Срезки — с 3-го уровня, провалы — с 6-го, событийные комнаты — с 9-го, тёмные станции — с 11-го. Мимики, наоборот, отодвинуты на 16-й: подделка под станцию имеет смысл только после того, как станциям пятнадцать уровней доверяли не глядя."""
const CHANGELOG_118_B := """• Тема биома теперь собирается из того, что на этом уровне РЕАЛЬНО может встретиться. Пока тем нет, лабиринт честно говорит, что правит только тьма, — вместо обещания, которое он не может выполнить.
• В Кодексе, раздел «Прогресс», появилась статья «Лестница открытий»: весь порядок ввода механик одним списком — что уже открылось (с описанием), что следующее и на каком уровне.
• Под капотом: пороги механик собраны в один реестр вместо россыпи констант по коду. Биом физически не может пообещать то, чего ещё нет."""
const CHANGELOG_118_A_EN := """• THE LADDER OF DISCOVERY. Mechanics no longer appear silently and out of order: each has its own entry level, and on that level the maze shows a «New: …» card with one line explaining what it is. Once ever, not once per run.
• The order is aligned to the biomes. The Azure Mines used to promise shortcut portals on levels 1-5 while the gate stood at 8, and the Crimson Depths promised chasms on 6-10 while they waited for level 15: the game described rules that did not exist yet. Now a mechanic enters INSIDE the stretch of its own biome.
• Shortcuts from level 3, chasms from 6, event rooms from 9, dark stations from 11. Mimics moved the other way, to 16: a fake station only means something after you have trusted stations blindly for fifteen levels."""
const CHANGELOG_118_B_EN := """• A biome's theme line is now built from what can ACTUALLY show up at this level. While no theme is live yet, the maze honestly says only the dark rules here — instead of a promise it cannot keep.
• The Codex, «Progression» section, has a new article «The ladder of discovery»: the whole introduction order as one list — what has opened (with descriptions), what comes next and at which level.
• Under the hood: mechanic thresholds now live in one registry instead of constants scattered across the code. A biome physically cannot promise what does not exist yet."""
const CHANGELOG_117_A := """• Теперь СЛЫШНО И ИХ. Враг, который уже за тобой охотится, рычит — и его слышно сквозь стены: с той стороны, откуда он идёт, вспыхивает багровая метка.
• Метка даёт только НАПРАВЛЕНИЕ. Она рисуется рядом с тобой, а не на враге, и не говорит ни сколько их, ни как далеко — иначе это был бы вечный бесплатный сонар, и тьма перестала бы что-то значить.
• Рычит только охотящийся. Патрулирующий молчит, так что тишина честно значит «меня пока не ищут». Замороженный (Щит, Хронос) тоже молкнет — стало тихо, значит заморозка сработала.
• Слух зависит от стойки света: в Тусклой слышишь на треть дальше, в Яркой на пятую часть хуже (раздутый свет гудит), лучше всего — в Тлении."""
const CHANGELOG_117_B := """• Исправлено: на 50-м уровне переход через дверь мог высадить в темноту. Этаж-арена там меньше овального этажа и добит стенами — если дверь стояла вне арены, игрок оказывался внутри монолита стен.
• Исправлено: портал между этажами иногда «не срабатывал» — если войти в него, пока идёт задержка после предыдущего перехода, сигнал терялся и приходилось отходить и возвращаться. Теперь портал дожимает сам.
• В тест-режим боссов добавлена кнопка 50 — страж лабиринта. Раньше тест давал только рядового дверь-босса."""
const CHANGELOG_111_A := """• Биом — больше не только цвет и форма коридоров, а НАБОР ПРАВИЛ: каждая пятёрка уровней играется по-своему, и её механики теперь гарантированы, а не выпадают раз в несколько уровней случайно.
• Лазурные шахты — биом срезок: парные порталы есть всегда, чаще приходит Вор, чаще сбоит свет. Учись читать маршрут.
• Багровые недра — биом провалов: ямы есть всегда, землю трясёт втрое чаще, охотится Беглец. Рывок здесь не «убежать», а «пройти»."""
const CHANGELOG_111_B := """• Споровые пустоты — биом тьмы: тёмные станции есть всегда, правит туман, тебя видно издалека. Единственная полоса, где Тление важнее скорости.
• При входе в новый биом лабиринт говорит, по каким правилам ты играешь ближайшие пять уровней.
• Второй заход в тему плотнее первого: на уровнях 16+ ям и тёмных станций больше, а срезок — две пары вместо одной.
• Овальные уровни 48-50 остались без срезок — кольцо нужно пройти целиком, как и задумано."""
const CHANGELOG_19_A := """• Выход теперь настоящий портал, а не золотой ромбик — виден издалека, но заперт, пока не собраны ВСЕ осколки уровня.
• Осколки стали кристаллами-ключами — их цвет совпадает с цветом запертых дверей: это один и тот же предмет, не разные бонусы."""
const CHANGELOG_19_B := """• Искра-проводник (навык G) теперь сначала ведёт к непойманным осколкам и только потом — к открывшемуся порталу.
• Маяк получил собственный силуэт — сигнальная вышка, её больше не спутать с выходом."""
const CHANGELOG_19_C := """• Уровень 50 стал настоящим финалом: механический страж лабиринта — лазер рушит стены, стальные укрытия держатся, эскорт питается от антистанций.
• Победа над стражем открывает «Навыки призыва» — отдельное колесо в Магазине навыков, рядом с колесом Апекса.
• Несколько игроков на одном компьютере: свой прогресс и настройки у каждого, сброс — только для текущего.
• Станции зарядки, гости лабиринта и сам страж перерисованы — у каждого объекта теперь свой узнаваемый силуэт вместо одинаковых «ромбиков»."""
const CHANGELOG_19_D := """• Навыки призыва теперь открываются победой над обычным дверь-боссом (☠, уровни кратные 5) — раньше только финальным стражем, и навык было почти негде опробовать.
• Зеркальный союзник получил мастерство ★ — усиливает его живучесть и урон, растёт применением навыка или покупкой звёзд за SP.
• Эскорт-Стражи стража держатся рядом с ним и гонятся только на близкой дистанции — отогнал их подальше, вернутся охранять, а не будут преследовать по всей арене.
• Враги теперь бьют и Зеркального союзника при контакте, а не игнорируют его.
• Тёмные станции (с уровня 10) — воронки, тянущие Свет и подпитывающие врагов фиолетовым ореолом рядом; гасятся Вспышкой/Сонаром или подавляются близкой станцией света.
• Комбо «Щит + Рывок»: рывок под щитом замораживает врага И бьёт тараном, а не только замораживает вхолостую.
• Случайные события теперь предупреждают заранее — тусклый пульсирующий значок того же события за пару секунд до срабатывания.
• Полоса Света резче переходит в красный на низком заряде; полоса Воли перекрашена в циан; у обеих появились тултипы с объяснением механики.
• «Живой лабиринт»: застрял в долгом обходе — раз в уровень соседняя стена сама растворяется, открывая короткий путь."""
const CHANGELOG_19_E := """• Один из преследователей теперь может испугаться и убежать («Зеркало») — после нескольких неудачных погонь подряд, или изредка без причины.
• Ямы-провалы (с уровня 15): блокируют проход, как стена, — Рывок проносит сквозь них насквозь.
• Обучение переделано в 3 коротких этапа подряд (основы+встреча с врагом, продвинутые навыки+комбо Щит-Рывок, новые механики) вместо одного длинного лабиринта — попапы-уроки теперь ставят игру на паузу, пока читаешь.
• Эхо осколка иногда обманывает: 18% шанс вместо второго осколка — засада, и все враги на этаже чуют неладное.
• Особые комнаты (с уровня 6): золотистое мерцание предупреждает заранее — алтарный осколок под охраной, ловушка тьмы, два неотличимых портала (станция или выход), безопасная комната-эхо с указателем на выход, или прилив сил ценой пробуждения врагов рядом.
• Порталы-срезки (с уровня 8): редкая пара бирюзовых порталов на одном этаже — секрет, который нужно найти, а не открыть.
• Лабиринт (с уровня 5) делится на четверти со своим акцентным цветом — читается как последовательность мест, а не однородный шум коридоров.
• Биомы теперь меняют не только цвет, но и характер пространства: шахты — крупные залы, пустоши — разреженная почти-пещера.
• Уровни 48-49 стали двойным овалом — кольцевой коридор почти по всему кругу до выхода. Уровень 50 — овал ещё крупнее, а в конце кольца дверь открывает арену стража."""
const CHANGELOG_18_A := """• Вход в мега-лабиринты (уровни 30+) и выход в меню — почти мгновенно, без секундных зависаний.
• Дверь-босс на уровнях, кратных 5, больше не грузит арену заранее — только когда действительно входишь в неё."""
const CHANGELOG_18_B := """• Землетрясение и разрушаемые Бреши пересчитывают стены мгновенно даже на самых больших уровнях.
• Стены и их коллизии полностью переработаны изнутри (TileMap) — играется так же, но заметно быстрее."""
const CHANGELOG_18_C := """• Лабиринты стали разнообразнее: внутри уровня иногда попадаются открытые залы и петляющие развилки — не только сплошные тесные коридоры.
• Плотность стен теперь может отличаться по разным частям одного этажа: где-то теснее, где-то — простор с петлями."""
const CHANGELOG_18_D := """• Дневник лабиринта переделан в карусель слайдов: обзор-цифры, стиль игры, история, советы — каждый экран читается одним взглядом, без долгого скролла.
• Экран «Играть» теперь открывает режимы постепенно: «Спуск дня»/«Накал»/«Логово» открываются по мере прохождения кампании, а не вываливаются все сразу новичку."""
const CHANGELOG_18_E := """• Бестиарий тоже стал каруселью слайдов — «Текущая угроза» и по одному экрану на каждого врага, портреты крупнее.
• Исправлена сетка выбора уровня: кнопки уровней прилипали к левому краю на широких окнах — теперь центрированы под текстом, как задумано."""
const CHANGELOG_17_A := """• Английская локализация: меню, HUD, все режимы, магазин навыков.
• Дневник с Бестиарием — тоже на английском, включая «Голос лабиринта».
• Переключатель «Язык» — в настройках, две кнопки: Русский / English."""
const CHANGELOG_17_B := """• Исправлен баг: босс мог проходить сквозь стены арены на рывке.
• Теперь у босса настоящая физическая коллизия — как у игрока."""
const CHANGELOG_16_A := """• Бестиарий «Досье лабиринта»: карточки врагов, лор, тактика, твои счётчики встреч/побед.
• Ранги заработали: ранг множит награды (S ×1.5 … D ×0.7), серии дают Благословение/Снисхождение.
• «Гости лабиринта»: Охота, Огонёк-союзник, Норы кротов, Вор — редкие мини-события.
• Накал — «спуск за огнём»: горизонты глубины, контракты спуска, обеты слотов."""
const CHANGELOG_16_B := """• Новый режим «Логово»: 10 уровней, владыка тьмы — в центре лабиринта.
• Дневник: «Путь мастерства» — не комментирует игру, а учит, шаг за шагом.
• Обучение переработано: попапы-указатели, стрелка к цели, проиграть нельзя.
• Автопауза и тишина при сворачивании; настройки очищены от старых ползунков."""
const CHANGELOG_15_A := """• Кампания выросла до 50 уровней (сложность растянута вдвое).
• Дверь-босс ☠ на уровнях кратных 5: арена, победа — дар Ядра.
• Элита глубин: Страж (броня), Фантом (скорость), Пиявка (пьёт Волю).
• Три сложности: Тлеющий / Горящий / Пылающий (награды ×0.75…×1.5)."""
const CHANGELOG_15_B := """• Спуск дня: один лабиринт на всех, одна попытка в день, серия дней.
• Тление (R): погасни до искры и исчезни из виду врагов.
• Пассивки-прогрессии: растут сами от твоих действий, усиливают Апекс.
• Колесо Апекса, магазин навыков, Дневник лабиринта, процедурное аудио."""

# Английские версии тех же новостей — для смены языка в настройках.
const CHANGELOG_112_A_EN := """• Light is no longer a timer — it is a dial you control. LIGHT STANCE: Z / X or the mouse wheel.
• BRIGHT — see much farther: find shards, the portal and junctions sooner. But Light burns 2.4x faster, and enemies spot you from nearly twice the distance.
• DIM — drain drops to 0.45 and they barely see you. In exchange you walk near-blind and slightly slower."""
const CHANGELOG_112_B_EN := """• The stance is free and always on — it is NOT Smother: Smother is still a short burst of invisibility for Will and on cooldown, the panic button. The stance is how you live between stations.
• The HUD gained a stance indicator next to the Light and Will bars: three segments and the current drain multiplier — the cost of the decision is visible, no guessing.
• Smother overrides any stance, so the emergency escape still works out of Bright."""
const CHANGELOG_113_A_EN := """• Skills now have LOUDNESS. An enemy within earshot goes to investigate the source — through walls, even if it never saw you. Visibility is «can they see you», noise is «can they hear you».
• A ring spreads out on every cast: orange means someone heard it and is coming, blue means nobody was in range. The cost of a keypress is visible immediately.
• Breach and Sonar are the loudest, Guide and Shield the quietest. Smother and Mirage are completely silent: one hides you, the other has its own lure.
• Smother muffles any cast, and the light stance is audible too: Dim quieter, Bright louder — an inflated light hums.
• Sonar is no longer free reconnaissance: it shows the layout and calls a Sentinel. Sometimes walking blind is right."""
const CHANGELOG_113_B_EN := """• SHARD STREAK: shards collected in a row without damage form a streak, and each next one is worth more — the XP multiplier grows by 0.25 per shard, up to x2.5. The streak and current multiplier show in the HUD next to the counter.
• An enemy hit breaks the streak and the game says «streak x5 broken» outright — previously the multiplier vanished in silence.
• ON-THE-SPOT REWARD: «+94 XP» and «+Will» float up at a shard, «+30 XP» at a killed enemy. Previously every reward was revealed only in menus and on the results screen, after the moment you were deciding in."""
const CHANGELOG_114_A_EN := """• ESCALATION: levels now have time-based stages. The threshold derives from that level's par time, so «a long time» means different seconds on level 50 and level 1.
• Past par time the dark thickens: your view shrinks and a cold rim appears at the screen edges.
• At roughly twice par the STALKER wakes — a large pink enemy that DOES NOT LOSE YOUR TRAIL. Walls, darkness and Smother do not affect it: you can outrun it but not hide from it.
• Only its speed balances it — a quarter slower than normal — and freezes work on it like on anyone.
• Why: the only pressure used to be the flat Light drain, and the first minute felt like the fourth. Now a run has rhythm: explore first, then leave."""
const CHANGELOG_115_A_EN := """• ENEMY ROLES: an enemy now differs not only by numbers but by behaviour. A role keeps its type's stats — what changes is what it DOES.
• THE HERDER (from level 8, yellow tint) does not come at you but at the cell you were going to escape through. It blocks the way out and squeezes you into a dead end. Running faster is useless — break the route: dash through it, Breach to the side, a shortcut. In a dead end it acts like an ordinary enemy.
• THE MIMIC (from level 12) is a fake station: same crystal, same breathing, indistinguishable by eye. Approach and it flushes crimson and becomes a fast enemy. It does not strike as it transforms: a trap, not a punishment for approaching a station.
• Mimics stand among real stations and live in the Azure Mines; the herder belongs to the Crimson Depths and is half as common in the Wastes. In Blazing there are no mimics: no stations there, so a fake would expose itself."""
const CHANGELOG_116_A_EN := """• Biome themes are back in Blazing: chasms and shortcut portals now appear there too. The hardest difficulty used to play poorer than the easiest — biomes lost their themes. Dark stations and mimics stay out: the first have no way to refund the Light they drain, the second have nothing to hide among when stations never spawn.
• The biome sets the maze's patience: escalation comes later in the Azure Mines (a route-finding biome) and earlier in the Spore Wastes (where you are visible from afar anyway).
• A clean shard streak now multiplies EMBER as well as experience: in a run, care is the main currency.
• From level 30 the herder role can fall to a SENTINEL: slow and armoured, blocking the way out is exactly its job.
• Fixed: the herder roll happened per enemy, so at a 50% chance one appeared almost always and a Sentinel could never get the role. The roll is now once per level."""
const CHANGELOG_117_A_EN := """• Now YOU HEAR THEM TOO. An enemy already hunting you growls — audible through walls: a crimson mark flashes from the direction it is coming from.
• The mark gives DIRECTION only. It is drawn next to you, not on the enemy, and tells neither how many nor how far — otherwise it would be a permanent free sonar and the dark would stop meaning anything.
• Only a hunting enemy growls. A patrolling one is silent, so silence honestly means «nobody is looking for me yet». A frozen one (Shield, Chrono) falls quiet too — it went quiet, so the freeze worked.
• Hearing depends on the light stance: a third farther in Dim, a fifth worse in Bright (an inflated light hums), best of all under Smother."""
const CHANGELOG_117_B_EN := """• Fixed: on level 50 a door transition could drop you into darkness. The arena floor there is smaller than the oval floor and padded with walls — if the door stood outside the arena, you landed inside solid wall.
• Fixed: the floor portal sometimes «did not work» — entering it during the cooldown after a previous transition lost the signal, and you had to step away and back. The portal now retriggers itself.
• The boss test row gained a 50 button — the maze guardian. Previously the test only offered the regular door boss."""
const CHANGELOG_111_A_EN := """• A biome is no longer just color and corridor shape — it's a RULE SET: every five levels play differently, and their mechanics are now guaranteed instead of showing up at random once every few levels.
• Azure Mines — the shortcut biome: portal pairs are always there, the Thief visits more often, the lights glitch more. Learn to read a route.
• Crimson Depths — the chasm biome: pits are always there, quakes hit three times as often, the Runner shows up. Dash here isn't «escape», it's «pass»."""
const CHANGELOG_111_B_EN := """• Spore Wastes — the darkness biome: dark stations are always there, fog rules, and you're visible from afar. The one stretch where Smother matters more than speed.
• Entering a new biome, the maze tells you which rules you're playing by for the next five levels.
• The second pass through a theme is denser than the first: from level 16 there are more pits and dark stations, and two portal pairs instead of one.
• Oval levels 48-50 stay shortcut-free — the ring is meant to be walked in full."""
const CHANGELOG_19_A_EN := """• The exit is now a real portal, not a golden diamond — visible from afar, but sealed until you collect ALL the shards on the level.
• Shards are now key-crystals — their color matches locked doors: it's the same item, not two different bonuses."""
const CHANGELOG_19_B_EN := """• The guide spark (G skill) now leads to unclaimed shards first, and only then to the portal once it opens.
• The beacon got its own silhouette — a signal tower, no longer mistaken for the exit."""
const CHANGELOG_19_C_EN := """• Level 50 is now a real finale: the maze's mechanical guardian — its laser breaks walls, steel cover holds, and its escort feeds on anti-stations.
• Beating the guardian unlocks «Summon Skills» — a separate wheel in the Skill Shop, next to the Apex wheel.
• Multiple players on one computer: each keeps their own progress and settings, and a reset only affects the current one.
• Charge stations, maze guests and the guardian itself were redrawn — every object now has its own recognizable silhouette instead of identical «diamonds»."""
const CHANGELOG_19_D_EN := """• Summon skills now unlock by beating a regular door boss (☠, levels divisible by 5) — used to require the final guardian, leaving almost nowhere to actually use it.
• Mirror Ally gained ★ mastery — boosts its toughness and damage, grows from use or buying stars with SP.
• The guardian's escort stays close to it and only aggroes at short range — drive them off and they return to guard duty instead of chasing you across the whole arena.
• Enemies now hit Mirror Ally on contact instead of ignoring it.
• Dark stations (from level 10) — funnels that drain your Light and buff nearby enemies with a violet aura; douse with Flash/Sonar or suppress with a nearby light station.
• «Shield + Dash» combo: dashing while shielded now freezes the enemy AND rams it, instead of just freezing for nothing.
• Random events now warn ahead of time — a dim pulsing icon of that same event a couple seconds before it fires.
• The Light bar turns red more sharply at low charge; the Will bar is now cyan; both got tooltips explaining the mechanic.
• «Living Maze»: stuck in a long detour — once per level a nearby wall dissolves on its own, opening a shortcut."""
const CHANGELOG_19_E_EN := """• A pursuer can now get scared and flee («Mirror») — after several failed chases in a row, or rarely for no reason at all.
• Pits (from level 15): block passage like a wall — a Dash carries you straight through.
• The tutorial is now 3 short stages in a row (basics + an enemy encounter, advanced skills + the Shield-Dash combo, newer mechanics) instead of one long maze — lesson popups now pause the game while you read.
• The shard echo can lie: 18% chance instead of a second shard — an ambush, and every enemy on the floor catches the scent.
• Special rooms (from level 6): a golden flicker warns ahead of time — a guarded altar shard, a darkness trap, two unmarked portals (station or exit), a safe echo room pointing to the exit, or a surge of strength that wakes nearby enemies.
• Shortcut portals (from level 8): a rare pair of teal portals on the same floor — a secret to find, not to open.
• The maze (from level 5) splits into quarters with their own accent color — reads as a sequence of places, not uniform corridor noise.
• Biomes now shape space, not just color: mines carve big rooms, wastes open into a sparse near-cavern.
• Levels 48-49 warp into a double oval — a ring corridor almost all the way around to the exit. Level 50 is an even bigger oval, with a door at the end of the ring opening onto the guardian's arena."""
const CHANGELOG_18_A_EN := """• Entering mega-mazes (level 30+) and returning to the menu — nearly instant, no more multi-second freezes.
• The boss door on levels divisible by 5 no longer loads its arena upfront — only when you actually step in."""
const CHANGELOG_18_B_EN := """• Quakes and breachable walls recompute instantly even on the biggest levels.
• Walls and their collision were rebuilt under the hood (TileMap) — plays the same, just noticeably faster."""
const CHANGELOG_18_C_EN := """• Mazes got more varied: a level can now hide open halls and looping side-paths, not just solid narrow corridors.
• Wall density can now differ across one floor — tighter in one corner, looser with loops in another."""
const CHANGELOG_18_D_EN := """• The Maze Journal is now a slide carousel: overview numbers, play style, history, coaching tips — each screen reads at a glance, no more long scrolling.
• The «Play» screen now unlocks modes gradually: Daily Dive/Ember/Lair open up as you clear the campaign, instead of dumping all four on a newcomer at once."""
const CHANGELOG_18_E_EN := """• The Bestiary is now a slide carousel too — «Current threat» plus one screen per enemy, bigger portraits.
• Fixed the level-select grid: level buttons stuck to the left edge on wide windows — now centered under the text as intended."""
const CHANGELOG_17_A_EN := """• English localization: menu, HUD, all modes, skill shop.
• Journal and Bestiary — also in English, including the «Voice of the Maze».
• A «Language» switch in settings, two buttons: Русский / English."""
const CHANGELOG_17_B_EN := """• Fixed a bug: the boss could dash straight through arena walls.
• The boss now has real physics collision — just like the player."""
const CHANGELOG_16_A_EN := """• Bestiary «Maze Dossier»: enemy cards — lore, tactics, your encounter/kill counters.
• Ranks now matter: rank multiplies rewards (S ×1.5 … D ×0.7), streaks grant Blessing/Mercy.
• «Maze guests»: Runner, Wisp, Moles, Thief — rare mini-events.
• Ember mode — «descend for fire»: depth horizons, run contracts, slot vows."""
const CHANGELOG_16_B_EN := """• New mode «Lair»: 10 levels, a dark lord — at the maze's center.
• Journal: «Mastery Path» — doesn't just comment on your play, it teaches, step by step.
• Tutorial reworked: pointer popups, an arrow to the goal, you can't lose.
• Auto-pause and mute on minimize; settings cleaned of old sliders."""
const CHANGELOG_15_A_EN := """• Campaign grew to 50 levels (difficulty curve stretched twice).
• Boss door ☠ on levels divisible by 5: an arena, victory — a Core gift.
• Deep elites: Guardian (armor), Phantom (speed), Leech (drains Will).
• Three difficulties: Ember / Blaze / Inferno (rewards ×0.75…×1.5)."""
const CHANGELOG_15_B_EN := """• Daily Dive: one maze for everyone, one attempt per day, a streak.
• Smother (R): dim to a spark and vanish from enemies' sight.
• Passive progressions: grow on their own from your actions, boost Apex.
• Apex wheel, skill shop, maze Journal, procedural audio."""


var _unlock_baseline: int = 1  # честный прогресс, чтобы вернуть его при выключении переключателя

var _title: Label
# [CODEX §30] Узлы шапки. На экране Кодекса они скрываются: это единственный
# экран для ЧТЕНИЯ, и 300px неонового логотипа отбирали у статьи почти
# половину доступной высоты. На остальных экранах шапка остаётся как была.
var _header_title: CenterContainer
var _header_sub: Label
var _title_glow: TextureRect
var _t: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Фон: очень тёмный, загадочный; слабые неоновые ореолы + редкие искры
	var bg := ColorRect.new()
	bg.color = Color(0.012, 0.016, 0.032)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_add_bg_glow(Vector2(0.5, 0.27), Color(0.12, 0.5, 1.0), 760.0, 0.15)
	_add_bg_glow(Vector2(0.14, 0.88), Color(0.6, 0.22, 1.0), 600.0, 0.07)
	_add_bg_glow(Vector2(0.88, 0.84), Color(1.0, 0.45, 0.18), 600.0, 0.05)
	_add_motes()

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(root)
	# [CAROUSEL-BOUNDS] Вся страница меню — ОДНА центрированная колонка, поэтому
	# «влезает ли экран» = «высота этой колонки ≤ высоты окна». Держим ссылку,
	# чтобы _fit_carousel считал доступное место по факту, а не по угаданной
	# константе-запасу (именно такая угаданная константа и протухла).
	_root_col = root

	# Неоновый заголовок с ореолом
	var title_wrap := CenterContainer.new()
	_header_title = title_wrap
	title_wrap.custom_minimum_size = Vector2(560, 128)
	root.add_child(title_wrap)

	_title_glow = TextureRect.new()
	_title_glow.texture = MazeTextures.make_light(256)
	_title_glow.custom_minimum_size = Vector2(460, 190)
	_title_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_title_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_title_glow.modulate = Color(0.18, 0.5, 0.95, 0.32)
	_title_glow.material = _additive()
	_title_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_wrap.add_child(_title_glow)

	_title = Label.new()
	_title.text = "MAZE"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 76)
	_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_title.add_theme_color_override("font_outline_color", Color(0.13, 0.4, 0.85))
	_title.add_theme_constant_override("outline_size", 6)
	title_wrap.add_child(_title)

	var subtitle := Label.new()
	_header_sub = subtitle
	subtitle.text = GameConfig.t("subtitle")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.45, 0.62, 0.82))
	root.add_child(subtitle)

	_start_menu_music()
	_build_menu(root)
	_build_mode(root)
	_build_runs(root)
	_build_briefing(root)
	_build_journal(root)
	_build_bestiary(root)
	_build_daily(root)
	_build_level_select(root)
	_build_lair_select(root)
	_build_settings(root)
	_build_codex(root)

	# Прокручиваемые панели не должны быть выше экрана: иначе CenterContainer
	# центрирует их и верх/низ (в т.ч. кнопка «Назад») уезжают за кадр.
	_fit_panels()
	get_viewport().size_changed.connect(_fit_panels)

	# Постоянная «← Назад» сверху-слева: видна в любом подразделе и не зависит от
	# прокрутки (раньше кнопка «Назад» терялась внизу длинного скролла).
	_back_btn = Button.new()
	_back_btn.text = GameConfig.t("back_arrow")
	_back_btn.visible = false
	_back_btn.focus_mode = Control.FOCUS_NONE
	_back_btn.custom_minimum_size = Vector2(130, 44)
	_back_btn.add_theme_font_size_override("font_size", 20)
	_style_button(_back_btn)
	_back_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_back_btn.offset_left = 20
	_back_btn.offset_top = 20
	_back_btn.pressed.connect(_go_back)
	add_child(_back_btn)

	# После обучения — сразу открыть экран «Играть», а не корневое меню:
	# игрок только что закончил обучение и логично ведёт его к выбору режима.
	if GameConfig.open_mode_on_start:
		GameConfig.open_mode_on_start = false
		_on_open_mode()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _back_btn and _back_btn.visible:
			_go_back()
			get_viewport().set_input_as_handled()

# Спрятать ВСЕ панели (включая корневое меню). Каждый _on_open_* обязан звать
# это перед показом своей панели: панели — соседи в одной колонке, и забытая
# видимая панель выталкивает новую за край экрана («кнопка не работает»).
# Компактный режим шапки: логотип и подзаголовок прячутся, освобождая высоту
# под длинный текст. Включается только Кодексом, снимается любым уходом с него.
func _set_header_compact(on: bool) -> void:
	if _header_title:
		_header_title.visible = not on
	if _header_sub:
		_header_sub.visible = not on

func _hide_all_panels() -> void:
	_set_header_compact(false)
	_menu_box.visible = false
	_level_box.visible = false
	if _lair_box:
		_lair_box.visible = false
	_settings_scroll.visible = false
	if _codex_root:
		_codex_root.visible = false
	_runs_box.visible = false
	_briefing_box.visible = false
	_journal_scroll.visible = false
	if _bestiary_scroll:
		_bestiary_scroll.visible = false
	if _daily_box:
		_daily_box.visible = false
	if _mode_scroll:
		_mode_scroll.visible = false

# Единая точка возврата (кнопка сверху-слева, Esc и нижние «Назад»).
# Иерархия: брифинг → слоты Накала; подпанели «Играть» (слоты, выбор уровня,
# спуск дня, дневник) → экран режимов; остальное → корневое меню.
func _go_back() -> void:
	if _briefing_box and _briefing_box.visible:
		_on_briefing_back()
		return
	var from_mode_child: bool = _runs_box.visible or _level_box.visible \
		or (_lair_box != null and _lair_box.visible) \
		or _journal_scroll.visible \
		or (_bestiary_scroll != null and _bestiary_scroll.visible) \
		or (_daily_box != null and _daily_box.visible)
	_hide_all_panels()
	if from_mode_child:
		_on_open_mode()
		return
	_menu_box.visible = true
	if _back_btn:
		_back_btn.visible = false

func _fit_panels() -> void:
	# Место под заголовком MAZE + подзаголовком + отступами (~250px) с запасом.
	var vh: float = get_viewport().get_visible_rect().size.y
	var avail: float = max(220.0, vh - 300.0)
	_settings_scroll.custom_minimum_size.y = min(480.0, avail)
	# [CAROUSEL-BOUNDS] Колонки Кодекса и карточки Дневника/Бестиария тоже
	# обязаны влезать в окно — раньше они были исключены отсюда «потому что
	# фиксированные», и это дало ровно тот баг, ради которого правило и
	# существует: слайды уезжали за нижний край. См. _fit_carousel.
	_fit_codex()
	_fit_carousel(_journal_slide_scroll, _journal_box)
	_fit_carousel(_bestiary_slide_scroll, _bestiary_box)
	if _mode_scroll:
		_mode_scroll.custom_minimum_size.y = min(520.0, avail)
	if _runs_box:
		_runs_box.custom_minimum_size.y = min(480.0, avail)
	if _briefing_box:
		_briefing_box.custom_minimum_size.y = min(480.0, avail)
	if _level_box:
		_level_box.custom_minimum_size.y = min(480.0, avail)
	if _lair_box:
		_lair_box.custom_minimum_size.y = min(480.0, avail)
	if _daily_box:
		_daily_box.custom_minimum_size.y = min(480.0, avail)

# [CAROUSEL-BOUNDS] Общая обёртка слайда карусели. Решает СРАЗУ две прошлые
# жалобы, которые тянули в разные стороны:
#   • «фиксированная коробка с вечной полосой прокрутки — дыра, а не карточка»
#     (Дневник, 06.07.2026) — отсюда высота ПО КОНТЕНТУ, пока он влезает;
#   • «слайды не целые / уезжают за экран» (Кодекс и Дневник) — отсюда
#     жёсткий потолок по высоте окна и прокрутка, когда контент выше.
# Ширина зафиксирована ВСЕГДА, и место под вертикальную полосу зарезервировано
# в самом контенте — иначе появление полосы на «длинном» слайде сужало бы текст
# и стрелки прыгали бы между слайдами (тот же урок, что был у Справки про
# SCROLL_MODE_AUTO).
func _carousel_slide_scroll(width: int) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(width, 0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	return sc

# Ширина контента внутри карусельной карточки с учётом зарезервированной полосы.
func _carousel_content_width(sc: ScrollContainer, width: int) -> int:
	var bar := sc.get_v_scroll_bar()
	var bw: int = int(bar.get_combined_minimum_size().x) if bar else 12
	return maxi(width - maxi(bw, 12), 100)

# Высота карточки = сколько реально нужно слайду, но не выше того, что влезает
# в окно. Зовётся после КАЖДОЙ перерисовки слайда и из _fit_panels (ресайз).
func _fit_carousel(sc: ScrollContainer, box: Control) -> void:
	if sc == null or box == null or not is_instance_valid(sc) or not is_instance_valid(box):
		return
	if not sc.visible or not sc.is_visible_in_tree():
		return
	var vh: float = get_viewport().get_visible_rect().size.y
	# Сколько занимает ВСЁ остальное в колонке (заголовок MAZE, подзаголовок,
	# имя экрана, счётчик страниц, кнопки, поля карточки) — измеряем, а не
	# угадываем: высота карточки здесь единственная переменная величина.
	var avail: float = vh - 32.0
	if _root_col and is_instance_valid(_root_col) and _root_col.size.y > 0.0 and sc.size.y > 0.0:
		avail = vh - 32.0 - (_root_col.size.y - sc.size.y)
	else:
		avail -= 320.0
	avail = maxf(avail, 200.0)
	var needed: float = box.get_combined_minimum_size().y
	sc.custom_minimum_size.y = min(needed, avail)

func _build_menu(root: VBoxContainer) -> void:
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 12)
	root.add_child(_menu_box)

	_menu_box.add_child(_make_button(GameConfig.t("menu_play"), _on_open_mode))
	_menu_box.add_child(_make_button(GameConfig.t("menu_settings"), _on_open_settings))
	_menu_box.add_child(_make_button(GameConfig.t("menu_help"), _on_open_codex))
	_menu_box.add_child(_make_button(GameConfig.t("menu_quit"), _on_quit))

func _build_settings(root: VBoxContainer) -> void:
	_settings_scroll = ScrollContainer.new()
	_settings_scroll.visible = false
	_settings_scroll.custom_minimum_size = Vector2(620, 480)
	_settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_settings_scroll)

	_settings_box = VBoxContainer.new()
	_settings_box.add_theme_constant_override("separation", 10)
	_settings_scroll.add_child(_settings_box)

	# Единая сетка: секции с заголовками, все строки одной ширины (560),
	# подписи слева, значения справа — ровная левая кромка по всей колонке.

	# Профиль (v1.9): несколько игроков на одной машине, у каждого свой
	# полностью отдельный сейв (прогресс, настройки, статистика). Сброс
	# прогресса ниже трогает только ЭТОГО, текущего, игрока.
	_settings_section(GameConfig.tt("Профиль", "Profile"), Color(0.5, 0.8, 1.0))
	var prof_row := HBoxContainer.new()
	prof_row.custom_minimum_size = Vector2(SETTINGS_W, 0)
	prof_row.add_theme_constant_override("separation", 10)
	_settings_box.add_child(prof_row)
	var prof_lbl := Label.new()
	prof_lbl.text = GameConfig.tt("Игрок: %s", "Player: %s") % GameConfig.profile_name
	prof_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prof_lbl.add_theme_font_size_override("font_size", 18)
	prof_row.add_child(prof_lbl)
	var prof_btn := Button.new()
	prof_btn.text = GameConfig.tt("Сменить игрока", "Switch player")
	prof_btn.custom_minimum_size = Vector2(190, 36)
	prof_btn.add_theme_font_size_override("font_size", 14)
	_style_button(prof_btn)
	prof_btn.pressed.connect(_show_profile_switcher)
	prof_row.add_child(prof_btn)

	_settings_section(GameConfig.t("settings_sound"), Color(0.5, 0.8, 1.0))
	_add_volume_slider(GameConfig.t("vol_music"), GameConfig.music_volume, func(v: float) -> void:
		GameConfig.music_volume = v
		GameConfig.apply_volumes()
		GameConfig.save_game())
	_add_volume_slider(GameConfig.t("vol_sfx"), GameConfig.sfx_volume, func(v: float) -> void:
		GameConfig.sfx_volume = v
		GameConfig.apply_volumes()
		GameConfig.save_game())

	_settings_section(GameConfig.t("settings_screen"), Color(0.5, 0.8, 1.0))
	_settings_check(GameConfig.t("fullscreen"), GameConfig.fullscreen, func(on: bool) -> void:
		GameConfig.fullscreen = on
		GameConfig.apply_display()
		GameConfig.save_game())

	var res_row := HBoxContainer.new()
	res_row.custom_minimum_size = Vector2(SETTINGS_W, 0)
	res_row.add_theme_constant_override("separation", 10)
	_settings_box.add_child(res_row)
	var res_lbl := Label.new()
	res_lbl.text = GameConfig.t("resolution")
	res_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_lbl.add_theme_font_size_override("font_size", 18)
	res_row.add_child(res_lbl)
	var res_opt := OptionButton.new()
	for r in GameConfig.RESOLUTIONS:
		res_opt.add_item("%d × %d" % [r.x, r.y])
	res_opt.selected = GameConfig.resolution_idx
	res_opt.add_theme_font_size_override("font_size", 16)
	res_opt.item_selected.connect(func(i: int) -> void:
		GameConfig.resolution_idx = i
		GameConfig.apply_display()
		GameConfig.save_game())
	res_row.add_child(res_opt)

	_settings_check(GameConfig.t("vsync"), GameConfig.vsync, func(on: bool) -> void:
		GameConfig.vsync = on
		GameConfig.apply_display()
		GameConfig.save_game())

	_settings_section(GameConfig.t("settings_game"), Color(0.5, 0.8, 1.0))
	_settings_check(GameConfig.t("beacon_pulse_opt"), GameConfig.beacon_pulse, func(on: bool) -> void:
		GameConfig.beacon_pulse = on
		GameConfig.save_game())
	_settings_check(GameConfig.t("show_fps_opt"), GameConfig.show_fps, func(on: bool) -> void:
		GameConfig.show_fps = on
		GameConfig.save_game())
	_settings_check(GameConfig.tt("Эхо времени (следы прошлого забега)", "Echo of Time (footprints from your last run)"),
		GameConfig.echo_time_enabled, func(on: bool) -> void:
			GameConfig.echo_time_enabled = on
			GameConfig.save_game())

	# Язык интерфейса: два переключаемых радио-кнопки. Меняет только основной
	# UI (меню/HUD/настройки/справка) — лор и голос лабиринта пока по-русски.
	var lang_row := HBoxContainer.new()
	lang_row.custom_minimum_size = Vector2(SETTINGS_W, 0)
	lang_row.add_theme_constant_override("separation", 10)
	_settings_box.add_child(lang_row)
	var lang_lbl := Label.new()
	lang_lbl.text = GameConfig.t("language")
	lang_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_lbl.add_theme_font_size_override("font_size", 18)
	lang_row.add_child(lang_lbl)
	var lang_btns: Array = []
	for code in ["ru", "en"]:
		var lb := Button.new()
		lb.text = "Русский" if code == "ru" else "English"
		lb.toggle_mode = true
		lb.button_pressed = GameConfig.locale == code
		lb.custom_minimum_size = Vector2(110, 36)
		lb.add_theme_font_size_override("font_size", 15)
		_style_button(lb)
		lang_btns.append(lb)
		var c: String = code
		lb.pressed.connect(func() -> void:
			if GameConfig.locale == c:
				return
			GameConfig.locale = c
			GameConfig.save_game()
			# Перестраиваем меню целиком — большинство подписей строится один
			# раз в _ready(), «на лету» без перезагрузки сцены не обновится.
			get_tree().reload_current_scene()
		)
		lang_row.add_child(lb)

	_settings_section(GameConfig.t("settings_test"), Color(1.0, 0.6, 0.2))
	var thint := Label.new()
	thint.text = GameConfig.tt(
		"В тест-режиме открыто всё, а статистика, XP, история уровней\nи Спуск дня НЕ записываются — прогоны не искажают Дневник.",
		"In test mode everything is unlocked, and stats, XP, level history,\nand Daily Dive are NOT recorded — test runs don't skew the Journal.")
	thint.custom_minimum_size = Vector2(SETTINGS_W, 0)
	thint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	thint.add_theme_font_size_override("font_size", 13)
	thint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.68))
	_settings_box.add_child(thint)

	var on_test := func(on: bool) -> void:
		GameConfig.test_mode = on
		GameConfig.save_game()
		_toast(GameConfig.tt("Тест-режим: %s", "Test mode: %s") % (
			GameConfig.tt("ВКЛ — статистика не записывается", "ON — stats are not recorded") if on
			else GameConfig.tt("выкл", "off")))
	_settings_check(GameConfig.tt("Тест-режим (статистика не пишется)", "Test mode (stats not recorded)"), GameConfig.test_mode, on_test, Color(1.0, 0.6, 0.2))
	_unlock_baseline = GameConfig.max_unlocked_level
	_settings_check(GameConfig.tt("Разблокировать все уровни", "Unlock all levels"), GameConfig.max_unlocked_level >= LEVEL_COUNT,
		_on_unlock_toggled, Color(1.0, 0.6, 0.2))
	# ВНИМАНИЕ на формулировку. Прежняя подпись — «уровни с боссом в меню» —
	# читалась как «добавит в меню кнопки боссовых уровней», тогда как флаг
	# заменяет ареной КАЖДЫЙ уровень кампании. Игрок включал его, шёл играть и
	# спрашивал «а где сами лабиринты?» (жалоба 29.07.2026, до этого — «открыл
	# 49 уровень и там темнота», §28). Подпись обязана называть последствие.
	var on_boss := func(on: bool) -> void:
		GameConfig.boss_test_enabled = on
		_populate_levels()
		if on:
			_toast(GameConfig.tt(
				"⚔ Тест боссов ВКЛЮЧЁН: теперь КАЖДЫЙ уровень — арена с боссом, обычных лабиринтов не будет. Выключи здесь же, чтобы вернуть кампанию.",
				"⚔ Boss test ON: EVERY level is now a boss arena, no normal mazes. Turn it off here to get the campaign back."))
	_settings_check(GameConfig.tt(
		"⚔ Тест боссов: КАЖДЫЙ уровень станет ареной",
		"⚔ Boss test: EVERY level becomes an arena"), GameConfig.boss_test_enabled, on_boss, Color(1.0, 0.6, 0.2))
	# Витрина «Навыки призыва» (GAMEDESIGN.md §25) по-хорошему открывается
	# только победой над дверь-боссом — этот тумблер даёт её потрогать без
	# реального прохождения, не трогая сам флаг прогресса насовсем (можно
	# выключить обратно, если победы ещё не было).
	var on_summon := func(on: bool) -> void:
		GameConfig.door_boss_defeated = on
		GameConfig.save_game()
		_toast(GameConfig.tt("Витрина «Навыки призыва»: %s", "«Summon Skills» shelf: %s") % (
			GameConfig.tt("открыта для теста", "opened for testing") if on
			else GameConfig.tt("скрыта (если нет реальной победы над дверь-боссом)", "hidden (unless a real door-boss win unlocked it)")))
	_settings_check(GameConfig.tt("✦ Тест навыков призыва (открыть витрину)", "✦ Test summon skills (open the shelf)"), GameConfig.door_boss_defeated, on_summon, Color(1.0, 0.6, 0.2))

	# ── Кнопки внизу: по центру колонки ──────────────────────────────────────
	var bsep := HSeparator.new()
	bsep.modulate = Color(0.4, 0.5, 0.7, 0.4)
	_settings_box.add_child(bsep)

	var btn_col := VBoxContainer.new()
	btn_col.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_col.add_theme_constant_override("separation", 10)
	btn_col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_settings_box.add_child(btn_col)

	# «О версиях»: окно с историей изменений (тот же текст, что в конце Справки).
	btn_col.add_child(_make_button(GameConfig.t("about_versions"), _show_changelog))

	# Сброс прогресса — с подтверждением вторым нажатием. Трогает только
	# текущий профиль (см. GameConfig.reset_progress) — прогресс других
	# игроков на этой машине не задет.
	var reset_hint := Label.new()
	reset_hint.text = GameConfig.tt("Сброс — только для текущего игрока (%s)", "Reset — only for the current player (%s)") % GameConfig.profile_name
	reset_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reset_hint.add_theme_font_size_override("font_size", 12)
	reset_hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.68))
	btn_col.add_child(reset_hint)

	var reset_armed := [false]
	var reset_btn := Button.new()
	reset_btn.text = GameConfig.t("reset_progress")
	reset_btn.custom_minimum_size = Vector2(300, 50)
	reset_btn.add_theme_font_size_override("font_size", 24)
	_style_button(reset_btn)
	reset_btn.pressed.connect(func() -> void:
		if reset_armed[0]:
			GameConfig.reset_progress()
			reset_armed[0] = false
			reset_btn.text = GameConfig.t("reset_progress")
			_toast(GameConfig.tt("Прогресс сброшен", "Progress reset"))
		else:
			reset_armed[0] = true
			reset_btn.text = GameConfig.t("reset_confirm")
	)
	reset_btn.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	btn_col.add_child(reset_btn)

# Заголовок секции настроек: отступ + цветная строка одной ширины с колонкой.
func _settings_section(text: String, col: Color) -> void:
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 6)
	_settings_box.add_child(pad)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(SETTINGS_W, 0)
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", col)
	_settings_box.add_child(l)

# Строка-переключатель настроек: та же раскладка HBox(подпись слева, растёт;
# контрол справа), что у ползунков/разрешения/языка — единая левая кромка для
# ВСЕХ строк настроек (раньше текст CheckButton рисовался с собственным
# встроенным отступом и «гулял» относительно обычных Label — жалоба
# «шрифты и выравнивание»; переключатель CheckButton больше не носит текст сам).
func _settings_check(text: String, value: bool, setter: Callable, col: Color = Color(1, 1, 1)) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(SETTINGS_W, 0)
	row.add_theme_constant_override("separation", 10)
	_settings_box.add_child(row)

	var lbl := Label.new()
	lbl.text = text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 18)
	if col != Color(1, 1, 1):
		lbl.add_theme_color_override("font_color", col)
	row.add_child(lbl)

	var cb := CheckButton.new()
	cb.text = ""
	cb.button_pressed = value
	cb.toggled.connect(setter)
	row.add_child(cb)

# Окно «О версиях»: прокручиваемая история изменений поверх настроек.
func _changelog_text() -> String:
	var en := GameConfig.locale == "en"
	var parts := [
		"WHAT'S NEW" if en else "ЧТО НОВОГО", "",
		"VERSION 3.2" if en else "ВЕРСИЯ 3.2",
		CHANGELOG_32_A_EN if en else CHANGELOG_32_A, "",
		"VERSION 3.1" if en else "ВЕРСИЯ 3.1",
		CHANGELOG_31_A_EN if en else CHANGELOG_31_A, "",
		"VERSION 3.0" if en else "ВЕРСИЯ 3.0",
		CHANGELOG_30_A_EN if en else CHANGELOG_30_A, "",
		"VERSION 2.9" if en else "ВЕРСИЯ 2.9",
		CHANGELOG_29_A_EN if en else CHANGELOG_29_A, "",
		"VERSION 2.8" if en else "ВЕРСИЯ 2.8",
		CHANGELOG_28_A_EN if en else CHANGELOG_28_A, "",
		"VERSION 2.7" if en else "ВЕРСИЯ 2.7",
		CHANGELOG_27_A_EN if en else CHANGELOG_27_A, "",
		"VERSION 2.6" if en else "ВЕРСИЯ 2.6",
		CHANGELOG_26_A_EN if en else CHANGELOG_26_A,
		CHANGELOG_26_B_EN if en else CHANGELOG_26_B, "",
		"VERSION 2.5" if en else "ВЕРСИЯ 2.5",
		CHANGELOG_25_A_EN if en else CHANGELOG_25_A,
		CHANGELOG_25_B_EN if en else CHANGELOG_25_B, "",
		"VERSION 2.4" if en else "ВЕРСИЯ 2.4",
		CHANGELOG_24_A_EN if en else CHANGELOG_24_A,
		CHANGELOG_24_B_EN if en else CHANGELOG_24_B, "",
		"VERSION 2.3" if en else "ВЕРСИЯ 2.3",
		CHANGELOG_23_A_EN if en else CHANGELOG_23_A,
		CHANGELOG_23_B_EN if en else CHANGELOG_23_B, "",
		"VERSION 2.2" if en else "ВЕРСИЯ 2.2",
		CHANGELOG_22_A_EN if en else CHANGELOG_22_A,
		CHANGELOG_22_B_EN if en else CHANGELOG_22_B, "",
		"VERSION 2.1" if en else "ВЕРСИЯ 2.1",
		CHANGELOG_21_A_EN if en else CHANGELOG_21_A,
		CHANGELOG_21_B_EN if en else CHANGELOG_21_B, "",
		"VERSION 2.0" if en else "ВЕРСИЯ 2.0",
		CHANGELOG_20_A_EN if en else CHANGELOG_20_A,
		CHANGELOG_20_B_EN if en else CHANGELOG_20_B, "",
		"VERSION 1.18" if en else "ВЕРСИЯ 1.18",
		CHANGELOG_118_A_EN if en else CHANGELOG_118_A,
		CHANGELOG_118_B_EN if en else CHANGELOG_118_B, "",
		"VERSION 1.17" if en else "ВЕРСИЯ 1.17",
		CHANGELOG_117_A_EN if en else CHANGELOG_117_A,
		CHANGELOG_117_B_EN if en else CHANGELOG_117_B, "",
		"VERSION 1.16" if en else "ВЕРСИЯ 1.16",
		CHANGELOG_116_A_EN if en else CHANGELOG_116_A, "",
		"VERSION 1.15" if en else "ВЕРСИЯ 1.15",
		CHANGELOG_115_A_EN if en else CHANGELOG_115_A, "",
		"VERSION 1.14" if en else "ВЕРСИЯ 1.14",
		CHANGELOG_114_A_EN if en else CHANGELOG_114_A, "",
		"VERSION 1.13" if en else "ВЕРСИЯ 1.13",
		CHANGELOG_113_A_EN if en else CHANGELOG_113_A,
		CHANGELOG_113_B_EN if en else CHANGELOG_113_B, "",
		"VERSION 1.12" if en else "ВЕРСИЯ 1.12",
		CHANGELOG_112_A_EN if en else CHANGELOG_112_A,
		CHANGELOG_112_B_EN if en else CHANGELOG_112_B, "",
		"VERSION 1.11" if en else "ВЕРСИЯ 1.11",
		CHANGELOG_111_A_EN if en else CHANGELOG_111_A,
		CHANGELOG_111_B_EN if en else CHANGELOG_111_B, "",
		"VERSION 1.9" if en else "ВЕРСИЯ 1.9",
		CHANGELOG_19_A_EN if en else CHANGELOG_19_A,
		CHANGELOG_19_B_EN if en else CHANGELOG_19_B,
		CHANGELOG_19_C_EN if en else CHANGELOG_19_C,
		CHANGELOG_19_D_EN if en else CHANGELOG_19_D,
		CHANGELOG_19_E_EN if en else CHANGELOG_19_E, "",
		"VERSION 1.8" if en else "ВЕРСИЯ 1.8",
		CHANGELOG_18_A_EN if en else CHANGELOG_18_A,
		CHANGELOG_18_B_EN if en else CHANGELOG_18_B,
		CHANGELOG_18_C_EN if en else CHANGELOG_18_C,
		CHANGELOG_18_D_EN if en else CHANGELOG_18_D,
		CHANGELOG_18_E_EN if en else CHANGELOG_18_E, "",
		"VERSION 1.7" if en else "ВЕРСИЯ 1.7",
		CHANGELOG_17_A_EN if en else CHANGELOG_17_A,
		CHANGELOG_17_B_EN if en else CHANGELOG_17_B, "",
		"VERSION 1.6" if en else "ВЕРСИЯ 1.6",
		CHANGELOG_16_A_EN if en else CHANGELOG_16_A,
		CHANGELOG_16_B_EN if en else CHANGELOG_16_B, "",
		"VERSION 1.5" if en else "ВЕРСИЯ 1.5",
		CHANGELOG_15_A_EN if en else CHANGELOG_15_A,
		CHANGELOG_15_B_EN if en else CHANGELOG_15_B,
	]
	return "\n".join(parts)

func _show_changelog() -> void:
	# Своё модальное окно вместо AcceptDialog: нативный диалог Godot рисуется
	# системной темой ОС и торчит белым квадратом посреди неонового меню (та
	# самая жалоба «окно не в общей стилистике»). Тёмная панель + оверлей —
	# как и всё остальное в игре.
	var overlay := CanvasLayer.new()
	overlay.layer = 20
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel_stylebox())
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	var title := Label.new()
	title.text = GameConfig.t("about_versions")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.85, 0.85, 1.0))
	col.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 460)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var lbl := Label.new()
	lbl.text = _changelog_text()
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(600, 0)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.82, 0.86, 0.95))
	scroll.add_child(lbl)

	col.add_child(UIStyle.make_button(GameConfig.t("close_esc").split("  ")[0], overlay.queue_free, 220, 46, 20))

# Модальное окно списка игроков (v1.9): переключиться на существующий
# профиль, создать нового или удалить неактивный. Тот же паттерн окна,
# что и «О версиях» — тёмная панель + оверлей, не нативный диалог.
func _show_profile_switcher() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 20
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel_stylebox())
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(420, 0)
	panel.add_child(col)

	var title := Label.new()
	title.text = GameConfig.tt("Игроки", "Players")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.85, 0.85, 1.0))
	col.add_child(title)

	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(400, 200)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(list_scroll)
	var list_col := VBoxContainer.new()
	list_col.add_theme_constant_override("separation", 8)
	list_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(list_col)

	for pname in GameConfig.profile_list:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		list_col.add_child(row)

		var is_active: bool = (pname == GameConfig.profile_name)
		var pbtn := Button.new()
		pbtn.text = ("● " if is_active else "○ ") + str(pname) + (GameConfig.tt(" (текущий)", " (current)") if is_active else "")
		pbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pbtn.custom_minimum_size = Vector2(0, 44)
		pbtn.add_theme_font_size_override("font_size", 16)
		pbtn.disabled = is_active
		_style_button(pbtn)
		var nm: String = pname
		pbtn.pressed.connect(func() -> void:
			if GameConfig.switch_profile(nm):
				overlay.queue_free()
				get_tree().reload_current_scene()
		)
		row.add_child(pbtn)

		if not is_active and GameConfig.profile_list.size() > 1:
			var del_btn := Button.new()
			del_btn.text = "✕"
			del_btn.custom_minimum_size = Vector2(44, 44)
			del_btn.add_theme_font_size_override("font_size", 16)
			_style_button(del_btn)
			del_btn.pressed.connect(func() -> void:
				GameConfig.delete_profile(nm)
				overlay.queue_free()
				_show_profile_switcher()
			)
			row.add_child(del_btn)

	var sep := HSeparator.new()
	col.add_child(sep)

	var new_lbl := Label.new()
	new_lbl.text = GameConfig.tt("Новый игрок:", "New player:")
	new_lbl.add_theme_font_size_override("font_size", 16)
	col.add_child(new_lbl)

	var new_row := HBoxContainer.new()
	new_row.add_theme_constant_override("separation", 8)
	col.add_child(new_row)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = GameConfig.tt("Имя игрока", "Player name")
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.custom_minimum_size = Vector2(0, 40)
	new_row.add_child(name_edit)
	var create_btn := Button.new()
	create_btn.text = GameConfig.tt("Создать", "Create")
	create_btn.custom_minimum_size = Vector2(110, 40)
	_style_button(create_btn)
	create_btn.pressed.connect(func() -> void:
		if GameConfig.create_profile(name_edit.text):
			overlay.queue_free()
			get_tree().reload_current_scene()
		else:
			name_edit.placeholder_text = GameConfig.tt("Имя занято/пустое", "Name taken/empty")
			name_edit.text = ""
	)
	new_row.add_child(create_btn)

	col.add_child(UIStyle.make_button(GameConfig.t("close_esc").split("  ")[0], overlay.queue_free, 220, 46, 20))

func _on_unlock_toggled(on: bool) -> void:
	if on:
		# Запомнить честный прогресс перед открытием всех уровней.
		if GameConfig.max_unlocked_level < LEVEL_COUNT:
			_unlock_baseline = GameConfig.max_unlocked_level
		GameConfig.max_unlocked_level = LEVEL_COUNT
	else:
		GameConfig.max_unlocked_level = _unlock_baseline
	GameConfig.save_game()
	_populate_levels()
	if on:
		_toast(GameConfig.tt("Все %d уровней открыты", "All %d levels unlocked") % LEVEL_COUNT)
	else:
		_toast(GameConfig.tt("Уровни закрыты до %d", "Levels locked back to %d") % GameConfig.max_unlocked_level)

# Короткое всплывающее сообщение по центру экрана.
# Короткое подтверждение действия (настройка применена и т.п.) — фон-плашка,
# как и все остальные всплывающие сообщения в игре, а не голый цветной текст.
func _toast(text: String) -> void:
	var wrap := CenterContainer.new()
	wrap.set_anchors_preset(Control.PRESET_TOP_WIDE)
	wrap.position = Vector2(0, 20)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wrap)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.panel_stylebox(Color(0.4, 0.95, 0.7, 0.6)))
	wrap.add_child(panel)

	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.7, 1.0, 0.85))
	panel.add_child(lbl)

	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(panel, "modulate:a", 0.0, 0.6)
	tw.tween_callback(wrap.queue_free)

# Ползунок громкости: подпись + HSlider 0..1 + процент справа.
func _add_volume_slider(text: String, value: float, setter: Callable) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(SETTINGS_W, 0)
	row.add_theme_constant_override("separation", 10)
	_settings_box.add_child(row)
	var lbl := Label.new()
	lbl.text = text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 18)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(220, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var pct := Label.new()
	pct.text = "%d%%" % int(round(value * 100.0))
	pct.custom_minimum_size = Vector2(52, 0)
	pct.add_theme_font_size_override("font_size", 16)
	pct.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	row.add_child(pct)
	slider.value_changed.connect(func(v: float) -> void:
		pct.text = "%d%%" % int(round(v * 100.0))
		setter.call(v))

# Фоновая музыка меню — тот же тёмный дрон, что и в игре, но тише:
# меню и лабиринт звучат одним миром, без склейки при переходе.
func _start_menu_music() -> void:
	var stream = load("res://sounds/ambient_dark.wav")
	if stream == null:
		return
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 4   # 16 бит × 2 канала
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -12.0
	p.bus = "Music"
	add_child(p)
	p.play()

func _make_button(text: String, on_pressed: Callable) -> Button:
	return UIStyle.make_button(text, on_pressed)

# --- Неоновое оформление ---

func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

func _add_bg_glow(anchor: Vector2, col: Color, sz: float, alpha: float) -> void:
	var g := TextureRect.new()
	g.texture = MazeTextures.make_light(256)
	g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g.stretch_mode = TextureRect.STRETCH_SCALE
	g.modulate = Color(col.r, col.g, col.b, alpha)
	g.material = _additive()
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.anchor_left = anchor.x; g.anchor_right = anchor.x
	g.anchor_top = anchor.y; g.anchor_bottom = anchor.y
	g.offset_left = -sz * 0.5; g.offset_right = sz * 0.5
	g.offset_top = -sz * 0.5; g.offset_bottom = sz * 0.5
	add_child(g)

func _add_motes() -> void:
	var vp := get_viewport().get_visible_rect().size
	var p := CPUParticles2D.new()
	p.texture = MazeTextures.make_ball(4, Color(1, 1, 1))
	p.amount = 38
	p.lifetime = 7.0
	p.preprocess = 4.0
	p.position = vp * 0.5
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = vp * 0.5
	p.direction = Vector2(0, -1)
	p.spread = 22.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 7.0
	p.initial_velocity_max = 22.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	ramp.colors = PackedColorArray([
		Color(0.4, 0.8, 1.0, 0.0), Color(0.45, 0.78, 1.0, 0.26), Color(0.45, 0.78, 1.0, 0.0)])
	p.color_ramp = ramp
	p.material = _additive()
	add_child(p)

func _style_button(b: Button) -> void:
	UIStyle.style_button(b)

# Есть ли над контролом ScrollContainer (тогда «выступающие» эффекты запрещены).
func _inside_scroll(n: Node) -> bool:
	var p := n.get_parent()
	while p != null:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false

func _process(delta: float) -> void:
	_t += delta
	if _title_glow:
		_title_glow.modulate.a = 0.26 + 0.09 * sin(_t * 2.0)

func _build_level_select(root: VBoxContainer) -> void:
	_level_box = ScrollContainer.new()
	_level_box.visible = false
	_level_box.custom_minimum_size = Vector2(700, 480)
	_level_box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_level_box)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	inner.custom_minimum_size = Vector2(680, 0)
	_level_box.add_child(inner)
	_level_inner = inner

	var lbl := Label.new()
	lbl.text = GameConfig.tt("Выбери уровень", "Choose a level")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 1.0))
	inner.add_child(lbl)

	var note := Label.new()
	note.text = GameConfig.tt("Чем выше уровень — тем больше лабиринт, темнее, быстрее разрядка и чаще события. Иногда попадаются открытые залы и петляющие развилки — не только тесные коридоры.\nЗакрытые уровни (🔒) откроются после прохождения предыдущего.", "The higher the level, the bigger the maze, the darker it gets, and the faster your light drains. Some floors hide open halls and looping side-paths, not just narrow corridors.\nLocked levels (🔒) unlock after you clear the previous one.")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	inner.add_child(note)

	_level_grid = GridContainer.new()
	_level_grid.columns = 10
	_level_grid.add_theme_constant_override("h_separation", 8)
	_level_grid.add_theme_constant_override("v_separation", 8)
	# [LAYOUT-FIX 2026-07-06] GridContainer не умеет центрировать себя (нет
	# понятия alignment, в отличие от H/VBoxContainer) — если родитель
	# (_level_box/inner, ScrollContainer/VBox без явного size_flags) оказался
	# шире грида (а он оказывается, когда рядом есть более широкие панели —
	# root вычисляет свою ширину по САМОЙ широкой панели среди ВСЕХ, не только
	# видимой), грид просто прилипает к левому краю, а Label'ы над ним
	# выглядят «центрированными», потому что центрируют ТЕКСТ внутри своего
	# растянутого ректа, а не сам рект. SIZE_SHRINK_CENTER — грид остаётся
	# своего натурального размера и центрируется в отведённом месте, как текст.
	_level_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(_level_grid)
	_populate_levels()

func _populate_levels() -> void:
	for c in _level_grid.get_children():
		c.queue_free()
	for i in LEVEL_COUNT:
		var lvl := i + 1
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(64, 50)
		btn.add_theme_font_size_override("font_size", 20)
		_style_button(btn)
		var unlocked: bool = lvl <= GameConfig.max_unlocked_level
		if unlocked:
			btn.text = "%d" % lvl
			# Органические уровни (11-20) — тёплым неоном
			if lvl >= 11:
				btn.add_theme_color_override("font_color", Color(1.0, 0.78, 0.4))
			# Лучший ранг уровня — мотив перепройти на S.
			var best: String = str(GameConfig.level_best_ranks.get(lvl, ""))
			if best != "":
				btn.text = "%d\n%s" % [lvl, best]
				btn.add_theme_font_size_override("font_size", 15)
				btn.add_theme_color_override("font_color", _RESULT_RANK_COLORS.get(best, Color(0.8, 0.85, 0.95)))
			btn.pressed.connect(func(): _on_play(lvl))
		else:
			btn.text = "🔒"
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.55)
		_level_grid.add_child(btn)

	# Боссовая секция — только при включённом тест-флаге
	if is_instance_valid(_boss_section):
		_boss_section.queue_free()
		_boss_section = null

	if GameConfig.boss_test_enabled:
		_boss_section = VBoxContainer.new()
		_boss_section.add_theme_constant_override("separation", 8)
		_level_inner.add_child(_boss_section)
		# Вставить перед кнопкой «Назад» (последний дочерний элемент)
		_level_inner.move_child(_boss_section, _level_inner.get_child_count() - 2)

		var sep := HSeparator.new()
		sep.modulate = Color(1.0, 0.6, 0.2, 0.5)
		_boss_section.add_child(sep)

		var lbl := Label.new()
		lbl.text = GameConfig.tt("⚔ Тест-уровни с боссом", "⚔ Boss test levels")
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		_boss_section.add_child(lbl)

		var hint := Label.new()
		hint.text = GameConfig.tt("Открывает арену с Тёмным Ядром на выбранном уровне.", "Opens the Dark Core arena on the chosen level.")
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 14)
		hint.add_theme_color_override("font_color", Color(0.6, 0.5, 0.4))
		_boss_section.add_child(hint)

		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 6)
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER   # [LAYOUT-FIX 2026-07-06] см. _level_grid
		_boss_section.add_child(grid)

		# 50 — САМЫЙ сильный босс (страж лабиринта, §25). Без него тест-режим
		# давал потрогать только рядового дверь-босса, а финал приходилось
		# добывать прохождением всей кампании (просьба 30.07.2026).
		for lvl in [1, 5, 10, 15, 20, 50]:
			var btn := Button.new()
			btn.text = "⚔ %d" % lvl
			btn.custom_minimum_size = Vector2(90, 50)
			btn.add_theme_font_size_override("font_size", 18)
			btn.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2))
			_style_button(btn)
			var capture: int = lvl
			btn.pressed.connect(func():
				GameConfig.boss_test_enabled = true
				_on_play(capture)
			)
			grid.add_child(btn)

# --- Режим «Логово»: 10 уровней, босс в центре лабиринта ---

func _build_lair_select(root: VBoxContainer) -> void:
	_lair_box = ScrollContainer.new()
	_lair_box.visible = false
	_lair_box.custom_minimum_size = Vector2(620, 480)
	_lair_box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_lair_box)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	inner.custom_minimum_size = Vector2(600, 0)
	_lair_box.add_child(inner)

	var lbl := Label.new()
	lbl.text = GameConfig.tt("ЛОГОВО — тронный зал в центре лабиринта", "LAIR — a throne room at the maze's center")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	inner.add_child(lbl)

	var note := Label.new()
	note.text = GameConfig.tt("Лабиринт растёт и густеет от логова к логову — к 10-му он огромен.\nВладыка тьмы ждёт в центре: дойди сквозь стражу и повергни его.", "The maze grows and thickens lair by lair — by the 10th it is huge.\nA dark lord waits at the center: fight through the guard and defeat it.")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(560, 0)
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color(0.68, 0.55, 0.55))
	inner.add_child(note)

	_lair_grid = GridContainer.new()
	_lair_grid.columns = 5
	_lair_grid.add_theme_constant_override("h_separation", 10)
	_lair_grid.add_theme_constant_override("v_separation", 10)
	_lair_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER   # [LAYOUT-FIX 2026-07-06] см. _level_grid
	inner.add_child(_lair_grid)
	_populate_lair_levels()

func _populate_lair_levels() -> void:
	for c in _lair_grid.get_children():
		c.queue_free()
	for i in GameConfig.LAIR_LEVELS:
		var lvl := i + 1
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(84, 56)
		btn.add_theme_font_size_override("font_size", 20)
		_style_button(btn)
		var unlocked: bool = lvl <= GameConfig.lair_max_unlocked
		if unlocked:
			btn.text = "☠ %d" % lvl
			btn.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
			btn.pressed.connect(func(): _on_play_lair(lvl))
		else:
			btn.text = "🔒"
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.55)
		_lair_grid.add_child(btn)

func _on_open_lair_select() -> void:
	_populate_lair_levels()
	_hide_all_panels()
	_lair_box.visible = true
	_back_btn.visible = true

func _on_play_lair(lvl: int) -> void:
	GameConfig.active_run = -1
	GameConfig.tutorial_mode = false
	GameConfig.lair_mode = true
	GameConfig.lair_level = lvl
	get_tree().change_scene_to_file("res://main.tscn")

# --- Режим «Накал»: слоты забегов и брифинг ---

func _build_runs(root: VBoxContainer) -> void:
	_runs_box = ScrollContainer.new()
	_runs_box.visible = false
	_runs_box.custom_minimum_size = Vector2(620, 480)
	_runs_box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_runs_box)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	inner.custom_minimum_size = Vector2(600, 0)
	_runs_box.add_child(inner)

	var lbl := Label.new()
	lbl.text = GameConfig.tt("НАКАЛ — спуск за огнём", "EMBER — a descent for fire")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.4))
	inner.add_child(lbl)

	var note := Label.new()
	note.text = GameConfig.tt("Ты несёшь уголёк из глубин. Каждый раз с нуля, %d жизни на весь спуск, гибель — конец забега.\nУ каждого слота — свой обет: исполни его и награда уйдёт в профиль «Уровней».",
		"You carry an ember from the depths. Every run starts from zero, %d lives for the whole descent, death ends the run.\nEach slot has its own vow: fulfill it and the reward goes to your «Levels» profile.") % GameConfig.RUN_LIVES
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color(0.72, 0.64, 0.52))
	inner.add_child(note)

	_runs_slots_box = VBoxContainer.new()
	_runs_slots_box.add_theme_constant_override("separation", 10)
	inner.add_child(_runs_slots_box)

func _populate_runs() -> void:
	for c in _runs_slots_box.get_children():
		c.queue_free()
	for i in GameConfig.RUN_SLOTS:
		var slot := i
		var s := GameConfig.run_summary(slot)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(440, 60)
		btn.add_theme_font_size_override("font_size", 20)
		_style_button(btn)
		match s["status"]:
			"active":
				btn.text = GameConfig.tt("Слот %d   ·   %s (глубина %d)   ·   ♥ %d   — продолжить", "Slot %d   ·   %s (depth %d)   ·   ♥ %d   — resume") % [slot + 1, GameConfig.horizon_name(int(s["level"])), s["level"], s["lives"]]
				btn.add_theme_color_override("font_color", Color(0.72, 1.0, 0.82))
			"ended":
				btn.text = GameConfig.tt("Слот %d   ·   завершён: %s (глубина %d)   — новый забег", "Slot %d   ·   finished: %s (depth %d)   — new run") % [slot + 1, GameConfig.horizon_name(int(s["max_depth"])), s["max_depth"]]
				btn.add_theme_color_override("font_color", Color(0.92, 0.62, 0.56))
			_:
				btn.text = GameConfig.tt("Слот %d   ·   пусто   — новый забег", "Slot %d   ·   empty   — new run") % [slot + 1]
		btn.pressed.connect(func(): _on_run_slot_pressed(slot))
		_runs_slots_box.add_child(btn)
		# Обет слота — долгосрочная цель, награда уходит в профиль «Уровней».
		if slot < GameConfig.RUN_VOWS.size():
			var vow: Dictionary = GameConfig.RUN_VOWS[slot]
			var done: bool = bool(GameConfig.vows_done[slot])
			var vlbl := Label.new()
			vlbl.text = GameConfig.tt("   🕯 Обет: %s — %s", "   🕯 Vow: %s — %s") % [GameConfig.vow_text(slot),
				(GameConfig.tt("исполнен ✓ (+%d SP)", "fulfilled ✓ (+%d SP)") % int(vow["sp"])) if done else (GameConfig.tt("+%d SP в «Уровни»", "+%d SP to «Levels»") % int(vow["sp"]))]
			vlbl.add_theme_font_size_override("font_size", 13)
			vlbl.add_theme_color_override("font_color",
				Color(0.55, 0.9, 0.6) if done else Color(0.65, 0.6, 0.5))
			_runs_slots_box.add_child(vlbl)

func _on_run_slot_pressed(slot: int) -> void:
	var s := GameConfig.run_summary(slot)
	if s["status"] == "active":
		GameConfig.resume_run(slot)
		_launch_game()
	else:
		_show_briefing(slot)

func _build_briefing(root: VBoxContainer) -> void:
	_briefing_box = ScrollContainer.new()
	_briefing_box.visible = false
	_briefing_box.custom_minimum_size = Vector2(620, 480)
	_briefing_box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_briefing_box)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	inner.custom_minimum_size = Vector2(600, 0)
	_briefing_box.add_child(inner)

	var lbl := Label.new()
	lbl.text = GameConfig.tt("Спуск за огнём", "A descent for fire")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))
	inner.add_child(lbl)

	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(560, 0)
	body.add_theme_font_size_override("font_size", 16)
	body.add_theme_color_override("font_color", Color(0.82, 0.86, 0.95))
	var horizons_preview: Array = []
	for hi in mini(3, GameConfig.HORIZONS.size()):
		horizons_preview.append(GameConfig.horizon_name(hi * GameConfig.HORIZON_SPAN + 1))
	body.text = GameConfig.tt(
		"Внизу тлеет огонь, которого хватит на всех. Спустись, набери Накал и удержи его.\n\n" +
		"• %d жизни на ВЕСЬ забег — между этажами не восстанавливаются.\n" +
		"• Начинаешь с нуля: только Вспышка (Q), Рывок (Shift) и Тление (R).\n" +
		"• Несомый Накал — риск: гибель сжигает половину, и жар притягивает тьму.\n" +
		"• Алтари (станции) банкуют Накал навсегда — и продают навыки за банк.\n" +
		"• Каждые %d глубин — новый горизонт: %s…\n" +
		"• Гибель завершает забег; выйти в меню можно всегда — слот сохранится.",
		"Below smolders a fire enough for everyone. Descend, gather Ember and hold on to it.\n\n" +
		"• %d lives for the WHOLE run — they don't recover between floors.\n" +
		"• You start from zero: only Flash (Q), Dash (Shift) and Smother (R).\n" +
		"• Carried Ember is a risk: dying burns half of it, and heat draws the dark.\n" +
		"• Altars (stations) bank Ember forever — and sell skills for the bank.\n" +
		"• Every %d depths — a new horizon: %s…\n" +
		"• Dying ends the run; you can always leave to the menu — the slot is saved.") % [
			GameConfig.RUN_LIVES, GameConfig.HORIZON_SPAN,
			", ".join(horizons_preview)]
	inner.add_child(body)

	# Контракт забега: необязательный модификатор риск/награда.
	var clbl := Label.new()
	clbl.text = GameConfig.tt("Контракт спуска (по желанию):", "Descent contract (optional):")
	clbl.add_theme_font_size_override("font_size", 17)
	clbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.35))
	inner.add_child(clbl)

	_briefing_contracts_box = VBoxContainer.new()
	_briefing_contracts_box.add_theme_constant_override("separation", 6)
	inner.add_child(_briefing_contracts_box)

	inner.add_child(_make_button(GameConfig.tt("Начать забег", "Start the run"), _start_briefed_run))

# Кнопки контрактов: одна выбирается, повторный клик снимает выбор.
func _populate_briefing_contracts() -> void:
	for c in _briefing_contracts_box.get_children():
		c.queue_free()
	_briefing_contract = ""
	var ids: Array = GameConfig.RUN_CONTRACTS.keys()
	for id in ids:
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(560, 54)
		b.add_theme_font_size_override("font_size", 15)
		_style_button(b)
		b.text = "%s — %s" % [GameConfig.contract_name(id), GameConfig.contract_desc(id).replace("\n", " ")]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var cid := str(id)
		b.toggled.connect(func(on: bool) -> void:
			if on:
				_briefing_contract = cid
				for other in _briefing_contracts_box.get_children():
					if other != b and other is Button:
						other.set_pressed_no_signal(false)
			elif _briefing_contract == cid:
				_briefing_contract = ""
		)
		_briefing_contracts_box.add_child(b)

func _on_open_runs() -> void:
	_populate_runs()
	_hide_all_panels()
	_runs_box.visible = true
	_back_btn.visible = true

func _show_briefing(slot: int) -> void:
	_briefing_slot = slot
	_populate_briefing_contracts()
	_runs_box.visible = false
	_briefing_box.visible = true
	_back_btn.visible = true

func _on_briefing_back() -> void:
	_briefing_box.visible = false
	_runs_box.visible = true

func _start_briefed_run() -> void:
	GameConfig.start_new_run(_briefing_slot, _briefing_contract)
	_launch_game()

func _launch_game() -> void:
	get_tree().change_scene_to_file("res://main.tscn")

# =============================================================================
# ДНЕВНИК ЛАБИРИНТА — объединённые «Статистика» + «Результаты».
# Подача: карточки-панели с неоновой рамкой. Сверху — «Голос лабиринта»:
# лабиринт «наблюдает» за игрой и говорит с игроком — наблюдения, советы и
# слухи о секретах. Набор и формулировки меняются от визита к визиту, чтобы
# дневник ощущался живым, а не статичной таблицей.
# =============================================================================

func _build_journal(root: VBoxContainer) -> void:
	_journal_scroll = VBoxContainer.new()
	_journal_scroll.visible = false
	_journal_scroll.add_theme_constant_override("separation", 14)
	root.add_child(_journal_scroll)

	var title := Label.new()
	title.text = GameConfig.tt("Дневник лабиринта", "Maze Journal")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_journal_scroll.add_child(title)

	# Стрелки по бокам карточки (как в Справке) — щёлкать всегда в одном месте,
	# независимо от высоты текущего слайда.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	_journal_scroll.add_child(row)

	_journal_prev_btn = _make_button("‹", func() -> void: _populate_journal_slide(_journal_slide_idx - 1))
	_journal_prev_btn.custom_minimum_size = Vector2(52, 52)
	_journal_prev_btn.add_theme_font_size_override("font_size", 26)
	_journal_prev_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_journal_prev_btn)

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.055, 0.10, 0.9)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.4, 0.5, 0.75, 0.5)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", sb)
	row.add_child(card)

	# [CAROUSEL-BOUNDS] Карточка по-прежнему подстраивается под высоту контента
	# (жалоба про «фиксированную коробку с дырой внизу» никуда не делась), но
	# теперь через _carousel_slide_scroll — с потолком по высоте окна. Без него
	# длинные слайды («Путь мастерства») уезжали за нижний край экрана.
	_journal_slide_scroll = _carousel_slide_scroll(700)
	card.add_child(_journal_slide_scroll)

	_journal_box = VBoxContainer.new()
	_journal_box.add_theme_constant_override("separation", 12)
	_journal_box.custom_minimum_size = Vector2(_carousel_content_width(_journal_slide_scroll, 700), 0)
	_journal_slide_scroll.add_child(_journal_box)

	_journal_next_btn = _make_button("›", func() -> void: _populate_journal_slide(_journal_slide_idx + 1))
	_journal_next_btn.custom_minimum_size = Vector2(52, 52)
	_journal_next_btn.add_theme_font_size_override("font_size", 26)
	_journal_next_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_journal_next_btn)

	_journal_nav_label = Label.new()
	_journal_nav_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_journal_nav_label.add_theme_font_size_override("font_size", 16)
	_journal_nav_label.add_theme_color_override("font_color", Color(0.6, 0.68, 0.8))
	_journal_scroll.add_child(_journal_nav_label)

const _RESULT_RANK_COLORS := {
	"S": Color(1.0, 0.85, 0.3), "A": Color(0.5, 1.0, 0.6),
	"B": Color(0.5, 0.8, 1.0), "C": Color(0.9, 0.7, 0.4), "D": Color(0.9, 0.4, 0.4),
}

# Карточка-панель с тонкой неоновой рамкой; возвращает VBox для содержимого.
func _journal_panel(title: String, accent: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.055, 0.10, 0.88)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.45)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	_journal_box.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)

	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 21)
	l.add_theme_color_override("font_color", accent)
	box.add_child(l)
	return box

func _journal_line(box: VBoxContainer, t: String, col: Color = Color(0.78, 0.84, 0.95), fsize: int = 16, wrap: bool = false) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 660
	box.add_child(l)

# Ряд «чипов»-статистик: иконка сверху, крупное число, мелкая подпись снизу.
# Оборачивается по ширине (HFlowContainer) — не растягивает панель на узких окнах.
func _journal_stat_chips(box: VBoxContainer, items: Array) -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 8)
	box.add_child(flow)
	for it in items:
		var icon: String = str(it[0])
		var value: String = str(it[1])
		var caption: String = str(it[2])
		var panel := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.1, 0.16, 0.7)
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		panel.add_theme_stylebox_override("panel", sb)
		flow.add_child(panel)

		var cv := VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.add_theme_constant_override("separation", 0)
		panel.add_child(cv)

		var vl := Label.new()
		vl.text = "%s %s" % [icon, value]
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vl.add_theme_font_size_override("font_size", 20)
		vl.add_theme_color_override("font_color", Color(0.95, 0.92, 1.0))
		cv.add_child(vl)

		var cl := Label.new()
		cl.text = caption
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cl.add_theme_font_size_override("font_size", 12)
		cl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.78))
		cv.add_child(cl)

# Полоска-диаграмма распределения рангов: закрашенный сегмент на ранг
# (пропорционально количеству) + легенда с цветом/буквой/числом под ней —
# вместо текста «S 0 · A 0 · B 5 · C 1 · D 0», который не считывается с ходу.
func _journal_rank_bar(box: VBoxContainer, counts: Dictionary) -> void:
	var total := 0
	for k in counts:
		total += int(counts[k])
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 2)
	bar.custom_minimum_size = Vector2(0, 14)
	box.add_child(bar)
	var order := ["S", "A", "B", "C", "D"]
	for rk in order:
		var n: int = int(counts.get(rk, 0))
		var seg := ColorRect.new()
		seg.color = _RESULT_RANK_COLORS.get(rk, Color(0.4, 0.4, 0.5))
		seg.custom_minimum_size = Vector2(0, 14)
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL if n > 0 else Control.SIZE_FILL
		# «Пусто» — тонкая тёмная полоска-заглушка, чтобы порядок S..D был виден
		# и когда конкретного ранга ещё не было ни разу.
		if n == 0:
			seg.color.a = 0.15
			seg.custom_minimum_size.x = 6
		else:
			seg.size_flags_stretch_ratio = float(n) / float(maxi(total, 1))
		bar.add_child(seg)

	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 14)
	box.add_child(legend)
	for rk in order:
		var n: int = int(counts.get(rk, 0))
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 4)
		legend.add_child(item)
		var sw := ColorRect.new()
		sw.color = _RESULT_RANK_COLORS.get(rk, Color(0.4, 0.4, 0.5))
		sw.custom_minimum_size = Vector2(10, 10)
		item.add_child(sw)
		var lbl := Label.new()
		lbl.text = "%s %d" % [rk, n]
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
		item.add_child(lbl)

# Доля «спидометра»: 1.0 = не хуже пар-тайма, 0 = вдвое и хуже медленнее.
func _journal_speed_frac(t: float, par: float) -> float:
	return clampf(par / maxf(t, 0.1), 0.0, 1.0)

# Карточка слота Накала: статус-бейдж + глубина текущая/макс + ранги-пипсы.
func _journal_run_card(box: VBoxContainer, slot: int, sm: Dictionary) -> void:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.13, 0.6)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)
	box.add_child(card)

	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	card.add_child(cv)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	cv.add_child(head)

	var slot_lbl := Label.new()
	slot_lbl.text = GameConfig.tt("Слот %d", "Slot %d") % (slot + 1)
	slot_lbl.add_theme_font_size_override("font_size", 16)
	slot_lbl.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0))
	head.add_child(slot_lbl)

	var status: String = str(sm.get("status", "empty"))
	var badge_text: String
	var badge_col: Color
	match status:
		"active":
			badge_text = GameConfig.tt("● идёт", "● active")
			badge_col = Color(0.4, 0.95, 0.55)
		"ended":
			badge_text = GameConfig.tt("○ завершён", "○ finished")
			badge_col = Color(0.75, 0.6, 0.5)
		_:
			badge_text = GameConfig.tt("пусто", "empty")
			badge_col = Color(0.5, 0.55, 0.65)
	var badge := Label.new()
	badge.text = badge_text
	badge.add_theme_font_size_override("font_size", 14)
	badge.add_theme_color_override("font_color", badge_col)
	head.add_child(badge)

	if status == "empty":
		return

	_journal_stat_chips(cv, [
		["⌀", str(int(sm.get("level", 1))), GameConfig.tt("текущая глубина", "current depth")],
		["⌂", str(int(sm.get("max_depth", 1))), GameConfig.tt("лучшая глубина", "best depth")],
		["♥", str(int(sm.get("lives", 0))), GameConfig.tt("жизней осталось", "lives left")],
	])

	var r = GameConfig.runs[slot]
	var ranks: Array = r.get("ranks", []) if r != null else []
	if ranks.is_empty():
		return
	var ranks_lbl := Label.new()
	ranks_lbl.text = GameConfig.tt("Ранги последних этажей:", "Ranks of last floors:")
	ranks_lbl.add_theme_font_size_override("font_size", 12)
	ranks_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.78))
	cv.add_child(ranks_lbl)

	var pip_row := HBoxContainer.new()
	pip_row.add_theme_constant_override("separation", 5)
	cv.add_child(pip_row)
	var rstart := maxi(0, ranks.size() - 12)
	for j in range(rstart, ranks.size()):
		var rk: String = str(ranks[j].get("rank", "?"))
		var pip := PanelContainer.new()
		var psb := StyleBoxFlat.new()
		psb.bg_color = _RESULT_RANK_COLORS.get(rk, Color(0.4, 0.4, 0.5))
		psb.set_corner_radius_all(4)
		pip.add_theme_stylebox_override("panel", psb)
		pip.custom_minimum_size = Vector2(20, 20)
		var pl := Label.new()
		pl.text = rk
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pl.add_theme_font_size_override("font_size", 12)
		pl.add_theme_color_override("font_color", Color(0.05, 0.05, 0.08))
		pip.add_child(pl)
		pip_row.add_child(pip)

# Строка «Последних уровней» — таблица с фиксированными колонками, не текст.
func _journal_level_row(box: VBoxContainer, rk: String, speed_frac: float,
		level: int, time_s: float, shards_pct: float, tags: Array) -> void:
	var col: Color = _RESULT_RANK_COLORS.get(rk, Color(0.78, 0.84, 0.95))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)

	var rk_lbl := Label.new()
	rk_lbl.text = rk
	rk_lbl.custom_minimum_size = Vector2(22, 0)
	rk_lbl.add_theme_font_size_override("font_size", 16)
	rk_lbl.add_theme_color_override("font_color", col)
	row.add_child(rk_lbl)

	var bar_bg := PanelContainer.new()
	bar_bg.custom_minimum_size = Vector2(70, 12)
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.15, 0.16, 0.2, 0.6)
	bg_sb.set_corner_radius_all(3)
	bar_bg.add_theme_stylebox_override("panel", bg_sb)
	row.add_child(bar_bg)
	var bar_fill := ColorRect.new()
	bar_fill.color = col
	bar_fill.custom_minimum_size = Vector2(70.0 * clampf(speed_frac, 0.0, 1.0), 12)
	var fill_wrap := Control.new()
	fill_wrap.custom_minimum_size = Vector2(70, 12)
	fill_wrap.add_child(bar_fill)
	bar_bg.add_child(fill_wrap)

	var lvl_lbl := Label.new()
	lvl_lbl.text = GameConfig.tt("ур. %d", "lvl %d") % level
	lvl_lbl.custom_minimum_size = Vector2(64, 0)
	lvl_lbl.add_theme_font_size_override("font_size", 14)
	lvl_lbl.add_theme_color_override("font_color", Color(0.8, 0.84, 0.95))
	row.add_child(lvl_lbl)

	var time_lbl := Label.new()
	time_lbl.text = "%.1fс" % time_s if GameConfig.locale != "en" else "%.1fs" % time_s
	time_lbl.custom_minimum_size = Vector2(58, 0)
	time_lbl.add_theme_font_size_override("font_size", 14)
	time_lbl.add_theme_color_override("font_color", Color(0.8, 0.84, 0.95))
	row.add_child(time_lbl)

	var shard_lbl := Label.new()
	shard_lbl.text = GameConfig.tt("осколки %d%%", "shards %d%%") % int(round(shards_pct * 100.0))
	shard_lbl.custom_minimum_size = Vector2(90, 0)
	shard_lbl.add_theme_font_size_override("font_size", 14)
	shard_lbl.add_theme_color_override("font_color", Color(0.8, 0.84, 0.95))
	row.add_child(shard_lbl)

	if not tags.is_empty():
		var tag_lbl := Label.new()
		tag_lbl.text = "  ·  ".join(tags)
		tag_lbl.add_theme_font_size_override("font_size", 13)
		tag_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.6))
		row.add_child(tag_lbl)

# [JOURNAL-CAROUSEL] Пересобирает список слайдов Дневника — состав зависит от
# прогресса игрока (некоторые слайды не показываются, если данных ещё нет).
# Данные (stats/history) снимаются ОДИН раз здесь и передаются в билдеры
# замыканиями — картина не «плывёт», если что-то поменяется, пока дневник открыт.
func _journal_rebuild_slides() -> void:
	var s: Dictionary = GameConfig.stats
	var hist: Array = GameConfig.level_history
	_journal_slides = []

	# [JOURNAL-CAROUSEL] Дневник «молчит», пока не пройдено вообще ничего —
	# нулевые чипы, все навыки за замком и голос-приветствие «мы не знакомы»
	# на 8 слайдах подряд выглядели уныло и бессмысленно для чистого
	# сохранения. Один тихий слайд вместо всей карусели, пока нет ни одной
	# зацепки за реальный прогресс.
	var has_progress: bool = int(s.get("levels_cleared", 0)) > 0 \
		or not hist.is_empty() \
		or int(s.get("runs_started", 0)) > 0 \
		or not GameConfig.daily_history.is_empty()
	if not has_progress:
		_journal_slides.append({"title": GameConfig.tt("Дневник лабиринта", "Maze Journal"),
			"build": func() -> void: _journal_slide_empty()})
		return

	_journal_slides.append({"title": GameConfig.tt("Обзор", "Overview"),
		"build": func() -> void: _journal_slide_overview(s)})
	_journal_slides.append({"title": GameConfig.tt("Твой стиль", "Your Style"),
		"build": func() -> void: _journal_slide_style()})
	_journal_slides.append({"title": GameConfig.tt("🎓 Путь мастерства", "🎓 Path of Mastery"),
		"build": func() -> void: _journal_slide_mastery(s, hist)})
	_journal_slides.append({"title": GameConfig.tt("Последние уровни", "Recent levels"),
		"build": func() -> void: _journal_slide_history(hist)})
	var locked_ms: Array = []
	for id in GameConfig.SKILL_MILESTONES:
		if not GameConfig.skills_unlocked.get(id, false):
			locked_ms.append(id)
	if not locked_ms.is_empty():
		_journal_slides.append({"title": GameConfig.tt("Путь к навыкам", "Path to skills"),
			"build": func() -> void: _journal_slide_goals(s, locked_ms)})
	_journal_slides.append({"title": GameConfig.tt("✧ Голос лабиринта", "✧ Voice of the Maze"),
		"build": func() -> void: _journal_slide_voice(hist, s)})
	if not GameConfig.daily_history.is_empty():
		_journal_slides.append({"title": GameConfig.tt("Спуск дня", "Daily Dive"),
			"build": func() -> void: _journal_slide_daily()})
	_journal_slides.append({"title": GameConfig.tt("Забеги Накала", "Ember runs"),
		"build": func() -> void: _journal_slide_runs()})

# Перерисовать слайд idx (с зацикливанием). Заголовок — общий для всех
# слайдов (единый стиль), сам билдер добавляет только содержимое.
func _populate_journal_slide(idx: int) -> void:
	if _journal_slides.is_empty():
		_journal_rebuild_slides()
	var n := _journal_slides.size()
	_journal_slide_idx = ((idx % n) + n) % n
	for c in _journal_box.get_children():
		c.queue_free()
	var slide: Dictionary = _journal_slides[_journal_slide_idx]
	var t := Label.new()
	t.text = str(slide["title"])
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_journal_box.add_child(t)
	(slide["build"] as Callable).call()
	# Один слайд (дневник «молчит», см. _journal_rebuild_slides) — стрелки и
	# счётчик страниц ни на что не указывают, прячем их совсем.
	var multi := n > 1
	_journal_prev_btn.visible = multi
	_journal_next_btn.visible = multi
	_journal_nav_label.visible = multi
	_journal_nav_label.text = "%d / %d" % [_journal_slide_idx + 1, n]
	# Высота карточки считается ПОСЛЕ сборки контента и через кадр — до этого
	# get_combined_minimum_size() ещё не учитывает только что добавленные узлы.
	_refit_carousel_deferred(_journal_slide_scroll, _journal_box)

# Пересчёт высоты карточки на следующем кадре: контейнеры Godot вычисляют свои
# минимальные размеры не мгновенно, а к следующему проходу layout'а.
func _refit_carousel_deferred(sc: ScrollContainer, box: Control) -> void:
	if sc == null or box == null:
		return
	# Два прохода: первый ставит высоту по свежесобранному контенту, второй
	# уточняет её, когда колонка уже пересчиталась под новый размер карточки.
	for _pass in 2:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		_fit_carousel(sc, box)

# --- Единственный слайд для чистого сохранения — см. _journal_rebuild_slides.
func _journal_slide_empty() -> void:
	var panel := _journal_panel(GameConfig.tt("✧ Голос лабиринта", "✧ Voice of the Maze"), Color(1.0, 0.85, 0.3))
	_journal_line(panel, GameConfig.tt(
		"Мы ещё не знакомы. Пройди хотя бы один этаж — и я начну записывать твою историю.",
		"We haven't met yet. Clear at least one floor — and I'll start recording your story."),
		Color(0.95, 0.9, 0.75), 16, true)

# --- Слайд «Обзор»: агрегаты за всё время — карточки-цифры + полоска рангов.
# Самый «дашбордный» слайд — читается одним взглядом, без единого абзаца текста.
func _journal_slide_overview(s: Dictionary) -> void:
	var path := _journal_panel(GameConfig.tt("Путь", "Path"), Color(0.5, 0.8, 1.0))
	_journal_stat_chips(path, [
		["🚪", str(int(s.get("levels_cleared", 0))), GameConfig.tt("этажей пройдено", "floors cleared")],
		["✦", str(int(s.get("shards_total", 0))), GameConfig.tt("осколков собрано", "shards collected")],
		["⌀", str(int(s.get("best_depth", 0))), GameConfig.tt("лучшая глубина Накала", "best Ember depth")],
		["🏦", str(int(s.get("best_ember", 0))), GameConfig.tt("рекорд банка", "best bank")],
		["🔥", "%d/%d" % [int(s.get("runs_ended", 0)), int(s.get("runs_started", 0))], GameConfig.tt("забегов завершено", "runs finished")],
	])
	_journal_rank_bar(path, {
		"S": int(s.get("rank_S", 0)), "A": int(s.get("rank_A", 0)), "B": int(s.get("rank_B", 0)),
		"C": int(s.get("rank_C", 0)), "D": int(s.get("rank_D", 0)),
	})

# --- Слайд «Твой стиль»: навыки в картинках — частота, мастерство, форма Апекса.
func _journal_slide_style() -> void:
	var style := _journal_panel(GameConfig.tt("Твой стиль", "Your Style"), Color(0.8, 0.7, 1.0))
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 12)
	style.add_child(srow)
	for id in ["flash", "dash", "smother", "sonar", "shield", "guide", "reveal", "pulse", "mirage", "breach", "chrono"]:
		var uses := int(GameConfig.skill_uses.get(id, 0))
		var unlocked: bool = GameConfig.skills_unlocked.get(id, false)
		var cellv := VBoxContainer.new()
		cellv.alignment = BoxContainer.ALIGNMENT_CENTER
		var ic := TextureRect.new()
		ic.texture = SkillIcons.make(id, 30)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		ic.custom_minimum_size = Vector2(34, 34)
		if not unlocked:
			ic.modulate = Color(0.32, 0.32, 0.38)
		cellv.add_child(ic)
		var nml := Label.new()
		nml.text = _skill_name(id)
		nml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nml.add_theme_font_size_override("font_size", 11)
		nml.add_theme_color_override("font_color", Color(0.7, 0.76, 0.88))
		cellv.add_child(nml)
		var ul := Label.new()
		ul.text = ("×%d" % uses) if unlocked else "🔒"
		ul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ul.add_theme_font_size_override("font_size", 12)
		ul.add_theme_color_override("font_color", Color(0.75, 0.8, 0.92) if unlocked else Color(0.45, 0.48, 0.55))
		cellv.add_child(ul)
		var mstars := GameConfig.mastery(id)
		if unlocked and mstars > 0:
			var ml := Label.new()
			ml.text = "★".repeat(mstars)
			ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ml.add_theme_font_size_override("font_size", 10)
			ml.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			cellv.add_child(ml)
		srow.add_child(cellv)
	# Прогноз Апекса: форма = самый прокачанный навык, эхо = второй.
	if GameConfig.skills_unlocked.get("apex", false):
		var top := GameConfig.top_mastered(2)
		var arow := HBoxContainer.new()
		arow.add_theme_constant_override("separation", 8)
		style.add_child(arow)
		var al := Label.new()
		al.text = GameConfig.tt("Апекс (H) сейчас примет форму:", "Apex (H) will currently take the form:")
		al.add_theme_font_size_override("font_size", 15)
		al.add_theme_color_override("font_color", Color(1.0, 0.5, 0.55))
		arow.add_child(al)
		var mic := TextureRect.new()
		mic.texture = SkillIcons.make(top[0], 26)
		mic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		arow.add_child(mic)
		var mn := Label.new()
		mn.text = _skill_name(top[0])
		mn.add_theme_font_size_override("font_size", 15)
		arow.add_child(mn)
		if top.size() > 1:
			var el := Label.new()
			el.text = GameConfig.tt("· эхо:", "· echo:")
			el.add_theme_font_size_override("font_size", 14)
			el.add_theme_color_override("font_color", Color(0.65, 0.7, 0.82))
			arow.add_child(el)
			var eic := TextureRect.new()
			eic.texture = SkillIcons.make(top[1], 22)
			eic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			arow.add_child(eic)
			var en := Label.new()
			en.text = _skill_name(top[1])
			en.add_theme_font_size_override("font_size", 14)
			arow.add_child(en)
		_journal_line(style, GameConfig.tt("Форма Апекса — это всегда твой самый прокачанный навык (★ мастерства выше остальных). Хочешь другую форму — применяй нужный навык чаще других, и Апекс перейдёт на него.",
			"The Apex form is always your most-mastered skill (highest ★ mastery). Want a different form — use that skill more than the others, and Apex will switch to it."), Color(0.6, 0.66, 0.78), 13, true)
	else:
		_journal_line(style, GameConfig.tt("Апекс (H) откроется, когда куплены все 7 активных навыков — или досрочно: 4+ навыка и один прокачан до ★5. Форму примет тот, что качаешь сильнее.",
			"Apex (H) unlocks once all 7 active skills are bought — or early: 4+ skills with one at ★5 mastery. It takes the form of whichever you've mastered most."), Color(0.6, 0.66, 0.78), 13, true)

# --- Слайд «Путь мастерства»: лабиринт не комментирует, а ТРЕНИРУЕТ.
# Последовательная программа: по статистике находим первый непройденный
# «урок», показываем прогресс до цели и конкретный совет, как её взять.
func _journal_slide_mastery(s: Dictionary, hist: Array) -> void:
	var is_en := GameConfig.locale == "en"
	var coach := _journal_panel(GameConfig.tt("🎓 Путь мастерства", "🎓 Path of Mastery"), Color(0.45, 0.95, 0.75))
	var steps := _coach_steps(s, hist)
	var done_n := 0
	for st in steps:
		if bool(st["done"]):
			done_n += 1
	_journal_line(coach, (("Lessons done: %d of %d") if is_en else ("Пройдено уроков: %d из %d")) % [done_n, steps.size()], Color(0.6, 0.75, 0.7), 14)
	var shown_current := false
	var upcoming := 0
	for st in steps:
		if bool(st["done"]):
			_journal_line(coach, "✓ %s" % str(st["title"]), Color(0.45, 0.7, 0.55), 14)
		elif not shown_current:
			shown_current = true
			var prog := str(st["progress"])
			_journal_line(coach, (("▶ CURRENT LESSON: %s%s") if is_en else ("▶ ТЕКУЩИЙ УРОК: %s%s")) % [str(st["title"]),
				("   (%s)" % prog) if prog != "" else ""],
				Color(0.55, 1.0, 0.8), 17, true)
			_journal_line(coach, (("   How: %s") if is_en else ("   Как: %s")) % str(st["how"]), Color(0.85, 0.95, 0.85), 15, true)
		elif upcoming < 2:
			upcoming += 1
			_journal_line(coach, (("· next: %s") if is_en else ("· дальше: %s")) % str(st["title"]), Color(0.45, 0.52, 0.6), 13)
	if not shown_current:
		_journal_line(coach, "The path is fully walked. The maze is no longer your teacher — now you teach it to fear you." if is_en else
			"Путь пройден целиком. Лабиринт больше не учитель тебе — теперь ты учишь его бояться.",
			Color(1.0, 0.85, 0.3), 15, true)

# --- Слайд «Последние уровни»: настоящая таблица (не текст с пробелами!),
# теперь на отдельном слайде — влезает больше строк, чем в общем скролле.
func _journal_slide_history(hist: Array) -> void:
	var recent := _journal_panel(GameConfig.tt("Последние уровни", "Recent levels"), Color(0.85, 0.9, 1.0))
	if hist.is_empty():
		_journal_line(recent, "Пока пусто — пройди первый уровень, и лабиринт начнёт записывать.")
	else:
		_journal_line(recent, GameConfig.tt("полоска — скорость против пар-тайма: длиннее = быстрее", "bar — speed vs par time: longer = faster"), Color(0.55, 0.6, 0.72), 12)
		var start := maxi(0, hist.size() - 10)
		for i in range(hist.size() - 1, start - 1, -1):
			var e: Dictionary = hist[i]
			var t: float = float(e.get("time", 0.0))
			var par: float = maxf(1.0, float(e.get("par", 1.0)))
			var rk: String = str(e.get("rank", "?"))
			var tags: Array = []
			if bool(e.get("no_dmg", false)):
				tags.append(GameConfig.tt("без урона ✦", "no damage ✦"))
			var diff_tag: String = ["◦ " + GameConfig.tt("тлеющий", "ember"), "", "☀ " + GameConfig.tt("ПЫЛАЮЩИЙ", "INFERNO")][clampi(int(e.get("diff", 1)), 0, 2)]
			if diff_tag != "":
				tags.append(diff_tag)
			_journal_level_row(recent, rk, _journal_speed_frac(t, par),
				int(e.get("level", 0)), t, float(e.get("shards_pct", 0.0)), tags)

# --- Слайд «Путь к навыкам»: цели-майлстоуны (навык откроется сам за достижение).
func _journal_slide_goals(s: Dictionary, locked_ms: Array) -> void:
	var goals := _journal_panel(GameConfig.tt("Путь к навыкам", "Path to skills"), Color(0.5, 1.0, 0.6))
	_journal_line(goals, "Навыки открываются за дела — или за SP в меню навыков, что раньше.", Color(0.6, 0.75, 0.65), 14, true)
	var names := {"sonar": "Сонар (E)", "shield": "Щит (C)", "guide": "Искра (G)", "reveal": "Озарение (F)", "pulse": "Пульс (B)"}
	for id in locked_ms:
		var ms: Dictionary = GameConfig.SKILL_MILESTONES[id]
		var cur := mini(int(s.get(ms["stat"], 0)), int(ms["need"]))
		var frac := float(cur) / float(ms["need"])
		var bar := "▰".repeat(int(round(frac * 8.0))) + "▱".repeat(8 - int(round(frac * 8.0)))
		_journal_line(goals, "%s   %s   %d / %d — %s" % [names.get(id, id), bar, cur, int(ms["need"]), str(ms["text"])])

# --- Слайд «Голос лабиринта»: наблюдения и советы по игре.
func _journal_slide_voice(hist: Array, s: Dictionary) -> void:
	var voice := _journal_panel(GameConfig.tt("✧ Голос лабиринта", "✧ Voice of the Maze"), Color(1.0, 0.85, 0.3))
	for line in _journal_voice_lines(hist, s):
		_journal_line(voice, line, Color(0.95, 0.9, 0.75), 16, true)

# --- Слайд «Спуск дня»: серия и последние результаты.
func _journal_slide_daily() -> void:
	var daily := _journal_panel(GameConfig.tt("Спуск дня", "Daily Dive"), Color(1.0, 0.85, 0.3))
	var streak := GameConfig.daily_streak()
	if streak >= 2:
		_journal_line(daily, "🔥 Серия: %d %s подряд" % [streak, _plural(streak, "день", "дня", "дней")], Color(1.0, 0.62, 0.25))
	var dh: Array = GameConfig.daily_history
	var dstart := maxi(0, dh.size() - 5)
	for i in range(dh.size() - 1, dstart - 1, -1):
		var e: Dictionary = dh[i]
		_journal_line(daily, "%s   ·   глубина %d   ·   Накал %d" % [
			str(e.get("date", "?")), int(e.get("depth", 1)), int(e.get("ember", 0))])

# --- Слайд «Забеги Накала»: слоты — карточка на слот вместо строки текста.
func _journal_slide_runs() -> void:
	var runs := _journal_panel(GameConfig.tt("Забеги Накала", "Ember runs"), Color(1.0, 0.62, 0.25))
	for i in GameConfig.RUN_SLOTS:
		var sm := GameConfig.run_summary(i)
		_journal_run_card(runs, i, sm)

# Сводка по кольцевому буферу последних уровней.
func _journal_aggregates(hist: Array) -> Dictionary:
	var sum_ratio := 0.0
	var sum_shards := 0.0
	var clean_count := 0
	for e in hist:
		var par: float = maxf(1.0, float(e.get("par", 1.0)))
		sum_ratio += float(e.get("time", 0.0)) / par
		sum_shards += float(e.get("shards_pct", 0.0))
		if bool(e.get("no_dmg", false)):
			clean_count += 1
	var n := maxi(hist.size(), 1)
	return {
		avg_ratio = sum_ratio / n,
		avg_shards = sum_shards / n,
		clean_pct = float(clean_count) / n,
	}

# =============================================================================
# «Голос лабиринта»: строит реплики по накопленным данным. Никакого ИИ — только
# пороги, но с ВАРИАТИВНОСТЬЮ: у каждого наблюдения несколько формулировок,
# из подходящих выбираются случайные 3 (приветствие — всегда). Каждый визит
# дневник звучит немного иначе — лабиринт «живой» и правда наблюдает.
# =============================================================================

const _SKILL_NAMES := {"flash": "Вспышка", "dash": "Рывок", "sonar": "Сонар",
	"shield": "Щит", "guide": "Искра", "reveal": "Озарение", "smother": "Тление", "pulse": "Пульс",
	"mirage": "Мираж", "breach": "Разлом", "chrono": "Хронос"}
const _SKILL_NAMES_EN := {"flash": "Flash", "dash": "Dash", "sonar": "Sonar",
	"shield": "Shield", "guide": "Guide", "reveal": "Reveal", "smother": "Smother", "pulse": "Pulse",
	"mirage": "Mirage", "breach": "Breach", "chrono": "Chrono"}

func _skill_name(id: String) -> String:
	var names: Dictionary = _SKILL_NAMES_EN if GameConfig.locale == "en" else _SKILL_NAMES
	return str(names.get(id, id))

# Слухи о секретах: подмешиваются, когда советов мало (или просто повезёт).
const _JOURNAL_RUMORS := [
	"Слух: если собрать три осколка подряд, не получив урона, тьма отступает сама. Проверь.",
	"Слух: осколки иногда оставляют эхо. Услышишь звон за спиной — реши, стоит ли возвращаться.",
	"Слух: Рывок сквозь собственную Вспышку летит дальше обычного. Кто-то называл это «световым копьём».",
	"Слух: Сонар, пущенный во время Озарения, видит всё — и враги слепнут от него.",
	"Слух: далёкий огонёк-маяк живёт полминуты. Успевший к нему получает подарок.",
	"Слух: тот, кто стоит у энергокристалла, не тает. Станция — убежище, переведи дух.",
	"Слух: в глубинах Накала чем ярче горишь — тем громче бьётся сердце экрана. Тьма это слышит.",
]
const _JOURNAL_RUMORS_EN := [
	"Rumor: gather three shards in a row without taking damage, and the dark retreats on its own. Try it.",
	"Rumor: shards sometimes leave an echo. Hear a chime behind you — decide whether it's worth turning back.",
	"Rumor: a Dash through your own Flash flies farther than usual. Some call it a «light spear».",
	"Rumor: Sonar fired during Reveal sees everything — and enemies are blinded by it.",
	"Rumor: a distant beacon lives for half a minute. Whoever reaches it gets a gift.",
	"Rumor: whoever stands by an energy crystal doesn't fade. A station is a refuge — catch your breath.",
	"Rumor: deep in Ember, the brighter you burn, the louder the screen's heart beats. The dark hears it.",
]

func _journal_rumors() -> Array:
	return _JOURNAL_RUMORS_EN if GameConfig.locale == "en" else _JOURNAL_RUMORS

# Русское склонение: _plural(3, "этаж", "этажа", "этажей") → «этажа».
func _plural(n: int, one: String, few: String, many: String) -> String:
	var m := absi(n) % 100
	if m >= 11 and m <= 14:
		return many
	match m % 10:
		1: return one
		2, 3, 4: return few
		_: return many

func _journal_voice_lines(hist: Array, s: Dictionary) -> Array:
	var en := GameConfig.locale == "en"
	var out: Array = []
	var total := int(s.get("levels_cleared", 0))
	var fl := _plural(total, "этаж", "этажа", "этажей")

	# Приветствие — всегда первое, зависит от «стажа» и меняет формулировку.
	var greet: Array
	if en:
		if total <= 0:
			greet = [
				"We haven't met yet. Clear at least one floor — and I'll start recording your story.",
				"The journal is empty. The maze awaits your first step.",
			]
		elif total < 10:
			greet = [
				"I've been watching you for %d floor(s). Still sizing you up." % total,
				"%d floor(s) behind you. I'm starting to recognize your gait." % total,
			]
		elif total < 50:
			greet = [
				"%d floors together. I already know how you play — read below." % total,
				"I've seen every one of your %d floors. There's something I want to say." % total,
			]
		else:
			greet = [
				"%d floors. You've been here longer than most sparks. I remember every one." % total,
				"After %d floors it's hard to surprise you. But I'll try." % total,
			]
	else:
		if total <= 0:
			greet = [
				"Мы ещё не знакомы. Пройди хотя бы один этаж — и я начну записывать твою историю.",
				"Дневник пуст. Лабиринт ждёт первого шага.",
			]
		elif total < 10:
			greet = [
				"Я наблюдаю за тобой уже %d %s. Пока присматриваюсь." % [total, fl],
				"%d %s позади. Я начинаю узнавать твою походку." % [total, fl],
			]
		elif total < 50:
			greet = [
				"%d %s вместе. Я уже знаю, как ты играешь — читай ниже." % [total, fl],
				"Я видел каждый из твоих %d этажей. Кое-что мне хочется сказать." % total,
			]
		else:
			greet = [
				"%d %s. Ты здесь дольше многих огоньков. Я помню каждый." % [total, fl],
				"После %d этажей мне трудно тебя удивить. Но я попробую." % total,
			]
	out.append(greet[randi() % greet.size()])
	if hist.is_empty():
		return out

	# --- Пул наблюдений: [условие уже проверено] массив формулировок ---
	var pool: Array = []
	var agg := _journal_aggregates(hist)
	var n := hist.size()

	# Темп
	if agg.avg_ratio > 1.6:
		pool.append(([
			"You tend to wander — averaging %d%% of par time. Guide (G) will show the way, and Sonar reveals what's around the corner." % int(round(agg.avg_ratio * 100.0)),
			"I see you circling the same corridors. Trust Sonar — it draws what the eye can't see.",
		] if en else [
			"Ты подолгу блуждаешь — в среднем %d%% от пар-тайма. Искра (G) покажет дорогу, а Сонар вскроет планировку за углом." % int(round(agg.avg_ratio * 100.0)),
			"Я вижу, как ты кружишь по одним и тем же коридорам. Доверься Сонару — он рисует то, чего не видит глаз.",
		]))
	elif agg.avg_ratio <= 1.05 and n >= 3:
		pool.append(([
			"You clear levels faster than I can rebuild the walls. Impressive.",
			"Your pace — %d%% of par time. Few walk me with such confidence." % int(round(agg.avg_ratio * 100.0)),
		] if en else [
			"Ты проходишь быстрее, чем я успеваю перестраивать стены. Впечатляет.",
			"Твой темп — %d%% от пар-тайма. Мало кто ходит по мне так уверенно." % int(round(agg.avg_ratio * 100.0)),
		]))

	# Чистота
	if agg.clean_pct < 0.3 and n >= 3:
		pool.append(([
			"The dark reaches you too often. Shield (C) forgives one mistake, Dash (Shift) — one and a half.",
			"You take damage in %d%% of levels. Try holding Shield ready for tight corridors." % int(round((1.0 - agg.clean_pct) * 100.0)),
		] if en else [
			"Тьма слишком часто дотягивается до тебя. Щит (C) прощает одну ошибку, а Рывок (Shift) — полторы.",
			"Ты получаешь урон в %d%% уровней. Попробуй держать Щит на случай тесных коридоров." % int(round((1.0 - agg.clean_pct) * 100.0)),
		]))
	elif agg.clean_pct >= 0.7 and n >= 5:
		pool.append(([
			"You're almost untouchable — %d%% of levels without a scratch. Maybe it's time to risk it: carry Ember longer without banking." % int(round(agg.clean_pct * 100.0)),
			"The dark complains it can't touch you. Give it a chance — and take more Ember.",
		] if en else [
			"Ты почти неуловим — %d%% уровней без единой царапины. Может, пора рискнуть: неси Накал дольше, не банкуя." % int(round(agg.clean_pct * 100.0)),
			"Тьма жалуется, что не может тебя коснуться. Дай ей шанс — и забери больше Накала.",
		]))

	# Осколки
	if agg.avg_shards < 0.5 and n >= 3:
		pool.append(([
			"You leave more than half the shards lying in the dark. They're keys, Will and Ember. And they're bored.",
			"Shards whisper that you walk past. Collect three in a row without damage — and see what happens.",
		] if en else [
			"Ты оставляешь больше половины осколков лежать в темноте. Они — ключи, Воля и Накал. И они скучают.",
			"Осколки шепчут, что ты проходишь мимо. Собери три подряд без урона — и увидишь, что будет.",
		]))
	elif agg.avg_shards >= 0.9 and n >= 3:
		pool.append(([
			"You collect almost everything I hide. A collector. I'll have to hide better.",
			"%d%% of shards — you sweep me clean. Respect." % int(round(agg.avg_shards * 100.0)),
		] if en else [
			"Ты собираешь почти всё, что я прячу. Коллекционер. Мне приходится прятать лучше.",
			"%d%% осколков — ты выметаешь меня подчистую. Уважаю." % int(round(agg.avg_shards * 100.0)),
		]))

	# Динамика: последние 5 уровней против предыдущих
	if n >= 8:
		var recent_h := hist.slice(n - 5, n)
		var prev_h := hist.slice(maxi(0, n - 10), n - 5)
		var ra := _journal_aggregates(recent_h)
		var pa := _journal_aggregates(prev_h)
		if ra.avg_ratio < pa.avg_ratio - 0.15:
			pool.append(([
				"I compared your recent levels to your older ones: you've gotten noticeably faster. I've noted it.",
				"You're growing. Five levels ago you moved slower — now corridors part for you.",
			] if en else [
				"Я сравнил твои последние уровни с прежними: ты стал заметно быстрее. Я это запомнил.",
				"Ты растёшь. Пять уровней назад ты ходил медленнее — теперь коридоры сами расступаются.",
			]))
		elif ra.avg_ratio > pa.avg_ratio + 0.2:
			pool.append(([
				"Recent levels are harder for you than before. Tired? Stations are a refuge: Light doesn't fade there.",
				"I sense you've slowed down. Sometimes it helps to stand by a crystal and look around.",
			] if en else [
				"Последние уровни даются тяжелее прежних. Устал? Станции — убежище: Свет там не тает.",
				"Я чувствую, что ты сбавил шаг. Иногда полезно постоять у кристалла и оглядеться.",
			]))

	# Серия рангов
	if n >= 3:
		var last3_top := true
		for i in range(n - 3, n):
			var rk: String = str(hist[i].get("rank", "?"))
			if rk != "S" and rk != "A":
				last3_top = false
				break
		if last3_top:
			pool.append(([
				"Three high ranks in a row. You play as if you can see in the dark.",
				"S and A, one after another. I'm starting to build meaner walls — don't take it personally.",
			] if en else [
				"Три высоких ранга подряд. Ты играешь так, будто видишь в темноте.",
				"S и A идут один за другим. Я начинаю строить стены злее — не обижайся.",
			]))

	# Навыки: забытый и любимый
	var uses: Dictionary = GameConfig.skill_uses
	var max_key := ""
	var min_key := ""
	var max_v := -1
	var min_v := 999999999
	for k in uses.keys():
		var v: int = int(uses[k])
		if v > max_v:
			max_v = v
			max_key = k
		if v < min_v:
			min_v = v
			min_key = k
	if min_key != "" and max_v > 0 and min_v <= int(max_v / 4.0):
		var nm: String = _skill_name(min_key)
		pool.append(([
			"«%s» gathers dust. I've seen sparks it saved the life of." % nm,
			"You barely call on «%s». Try it — it might be the tool you're missing." % nm,
		] if en else [
			"«%s» пылится без дела. Я видел огоньков, которым он спасал жизнь." % nm,
			"Ты почти не зовёшь «%s». Попробуй — возможно, это твой недостающий инструмент." % nm,
		]))
	if max_v >= 10 and max_key != "":
		var combo_hint := ""
		if en:
			match max_key:
				"flash": combo_hint = " By the way: Dash during Flash flies one and a half times farther."
				"dash":  combo_hint = " By the way: bursting into Dash during Flash makes a «light spear»."
				"sonar": combo_hint = " By the way: Sonar during Reveal covers twice the area and stuns enemies."
		else:
			match max_key:
				"flash": combo_hint = " К слову: Рывок во время Вспышки летит в полтора раза дальше."
				"dash":  combo_hint = " К слову: если сорваться в Рывок во время Вспышки — получится «световое копьё»."
				"sonar": combo_hint = " К слову: Сонар во время Озарения накрывает вдвое больше и глушит врагов."
		if combo_hint != "":
			pool.append(([
				"Your favorite tool is «%s», %d uses.%s" % [_skill_name(max_key), max_v, combo_hint],
			] if en else [
				"Твой любимый инструмент — «%s», %d применений.%s" % [_skill_name(max_key), max_v, combo_hint],
			]))

	# Выбираем случайные 3 наблюдения; если мало — добиваем слухом о секретах.
	pool.shuffle()
	for i in mini(3, pool.size()):
		var variants: Array = pool[i]
		out.append("◈ " + variants[randi() % variants.size()])
	if out.size() < 3 or randf() < 0.35:
		var rumors := _journal_rumors()
		out.append("◈ " + rumors[randi() % rumors.size()])
	return out

# =============================================================================
# БЕСТИАРИЙ «Досье лабиринта» — карточки врагов: портрет, лор, тактика, счётчики.
# Карточка скрыта («???») до первой погони (seen_tN), тактика открывается
# первым убийством (kill_tN). Данные — GameConfig.BESTIARY.
# =============================================================================

# С какого уровня появляется каждый тип (0-2 — с первых встреч, элита — глубины).
const _BESTIARY_APPEAR := [
	"обитает повсюду", "обитает повсюду", "обитает повсюду",
	"глубины 25+", "глубины 30+", "глубины 35+",
]
const _BESTIARY_APPEAR_EN := [
	"found everywhere", "found everywhere", "found everywhere",
	"depth 25+", "depth 30+", "depth 35+",
]

func _bestiary_appear(i: int) -> String:
	return (_BESTIARY_APPEAR_EN if GameConfig.locale == "en" else _BESTIARY_APPEAR)[i]

func _build_bestiary(root: VBoxContainer) -> void:
	_bestiary_scroll = VBoxContainer.new()
	_bestiary_scroll.visible = false
	_bestiary_scroll.add_theme_constant_override("separation", 14)
	root.add_child(_bestiary_scroll)

	var title := Label.new()
	title.text = GameConfig.tt("Досье лабиринта", "Maze Dossier")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_bestiary_scroll.add_child(title)

	# Стрелки по бокам карточки — тот же паттерн, что у Справки/Дневника.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	_bestiary_scroll.add_child(row)

	_bestiary_prev_btn = _make_button("‹", func() -> void: _populate_bestiary_slide(_bestiary_slide_idx - 1))
	_bestiary_prev_btn.custom_minimum_size = Vector2(52, 52)
	_bestiary_prev_btn.add_theme_font_size_override("font_size", 26)
	_bestiary_prev_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_bestiary_prev_btn)

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.055, 0.10, 0.9)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.4, 0.5, 0.75, 0.5)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", sb)
	row.add_child(card)

	# [CAROUSEL-BOUNDS] Тот же общий механизм, что у Дневника и Справки:
	# высота по контенту, пока он влезает в окно, дальше — прокрутка.
	# Бестиарий сейчас в границы укладывается, но карточки врагов растут
	# вместе с лором, и держать его на «пока влезает» — та же протухающая
	# подгонка, что уже подвела Справку.
	_bestiary_slide_scroll = _carousel_slide_scroll(700)
	card.add_child(_bestiary_slide_scroll)

	_bestiary_box = VBoxContainer.new()
	_bestiary_box.add_theme_constant_override("separation", 12)
	_bestiary_box.custom_minimum_size = Vector2(_carousel_content_width(_bestiary_slide_scroll, 700), 0)
	_bestiary_slide_scroll.add_child(_bestiary_box)

	_bestiary_next_btn = _make_button("›", func() -> void: _populate_bestiary_slide(_bestiary_slide_idx + 1))
	_bestiary_next_btn.custom_minimum_size = Vector2(52, 52)
	_bestiary_next_btn.add_theme_font_size_override("font_size", 26)
	_bestiary_next_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_bestiary_next_btn)

	_bestiary_nav_label = Label.new()
	_bestiary_nav_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bestiary_nav_label.add_theme_font_size_override("font_size", 16)
	_bestiary_nav_label.add_theme_color_override("font_color", Color(0.6, 0.68, 0.8))
	_bestiary_scroll.add_child(_bestiary_nav_label)

func _on_open_bestiary() -> void:
	_bestiary_rebuild_slides()
	_populate_bestiary_slide(0)
	_hide_all_panels()
	_bestiary_scroll.visible = true
	if _back_btn:
		_back_btn.visible = true

# Карточка-панель бестиария (та же стилистика, что у дневника, но своя колонка).
func _bestiary_panel(title: String, accent: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.055, 0.10, 0.88)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.45)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	_bestiary_box.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 21)
	l.add_theme_color_override("font_color", accent)
	box.add_child(l)
	return box

func _bestiary_line(box: VBoxContainer, t: String, col: Color = Color(0.78, 0.84, 0.95), fsize: int = 15, wrap: bool = true) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 600
	box.add_child(l)

# «Текущая угроза»: почему враги сейчас сильнее именно у этого игрока.
func _bestiary_threat_lines() -> Array:
	var en := GameConfig.locale == "en"
	var out: Array = []
	var lvl: int = GameConfig.max_unlocked_level
	var speed_pct := int(round(minf(float(lvl), 50.0) * 0.5))
	if speed_pct > 0:
		out.append(("Depth %d: the dark has sped up — enemy speed +%d%%." % [lvl, speed_pct]) if en else
			("Глубина %d: тьма разогналась — скорость врагов +%d%%." % [lvl, speed_pct]))
	match GameConfig.difficulty:
		0: out.append("Ember flame: enemies are lazier than usual (−15% speed)." if en else "Тлеющее пламя: враги ленивее обычного (−15% прыти).")
		2: out.append("Inferno flame: enemies are fiercer (+10% speed), no stations — the dark senses weakness." if en else "Пылающее пламя: враги злее (+10% прыти), станций нет — тьма чует слабость.")
	for i in GameConfig.RUN_SLOTS:
		var r = GameConfig.runs[i]
		if r != null and not bool(r.get("ended", false)) and float(r.get("ember_carried", 0)) > 0.0:
			out.append("In an Ember run you're carrying unbanked heat — the dark comes for its light. Bank it at altars." if en else
				"В забеге Накала ты несёшь незабанканный жар — тьма идёт на его свет. Банкуй на алтарях.")
			break
	if lvl >= 25:
		if en:
			out.append("You've gone deep: the maze unleashes elites — Guardians%s%s." % [
				", Phantoms" if lvl >= 30 else "", " and Leeches" if lvl >= 35 else ""])
		else:
			out.append("Ты спустился глубоко: лабиринт выпускает элиту — Стражей%s%s." % [
				", Фантомов" if lvl >= 30 else "", " и Пиявок" if lvl >= 35 else ""])
	if out.is_empty():
		out.append("The dark is still dozing: enemies at their normal strength. The deeper, the fiercer." if en else
			"Пока тьма дремлет: враги в своей обычной силе. Чем глубже — тем злее.")
	return out

# [BESTIARY-CAROUSEL] Пересобирает список слайдов — «Текущая угроза» первым,
# затем один слайд на каждого врага (заголовок слайда — имя, если встречен,
# иначе «???», чтобы не спойлерить в счётчике страниц).
func _bestiary_rebuild_slides() -> void:
	var s: Dictionary = GameConfig.stats
	_bestiary_slides = []
	_bestiary_slides.append({"title": GameConfig.tt("⚠ Текущая угроза", "⚠ Current threat"),
		"build": func() -> void: _bestiary_slide_threat(s)})
	for t in GameConfig.BESTIARY.size():
		var tt := t   # заморозить значение цикла для замыкания — иначе все билдеры увидят последнее t
		var seen := int(s.get("seen_t%d" % tt, 0))
		var title: String = GameConfig.bestiary_name(tt) if seen > 0 else "???"
		_bestiary_slides.append({"title": title,
			"build": func() -> void: _bestiary_slide_enemy(s, tt)})

# Перерисовать слайд idx (с зацикливанием). Заголовок — общий для всех слайдов.
func _populate_bestiary_slide(idx: int) -> void:
	if _bestiary_slides.is_empty():
		_bestiary_rebuild_slides()
	var n := _bestiary_slides.size()
	_bestiary_slide_idx = ((idx % n) + n) % n
	for c in _bestiary_box.get_children():
		c.queue_free()
	var slide: Dictionary = _bestiary_slides[_bestiary_slide_idx]
	var t := Label.new()
	t.text = str(slide["title"])
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_bestiary_box.add_child(t)
	(slide["build"] as Callable).call()
	_bestiary_nav_label.text = "%d / %d" % [_bestiary_slide_idx + 1, n]
	_refit_carousel_deferred(_bestiary_slide_scroll, _bestiary_box)

# --- Слайд «Текущая угроза»: сколько досье открыто + живое объяснение силы врагов.
func _bestiary_slide_threat(s: Dictionary) -> void:
	var known := 0
	for t in GameConfig.BESTIARY.size():
		if int(s.get("seen_t%d" % t, 0)) > 0:
			known += 1
	var sub := Label.new()
	sub.text = GameConfig.tt("Открыто досье: %d из %d. Встреча открывает имя, победа — слабости.",
		"Dossiers unlocked: %d of %d. An encounter reveals the name, a victory — its weaknesses.") % [known, GameConfig.BESTIARY.size()]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.6, 0.68, 0.8))
	_bestiary_box.add_child(sub)

	var threat := _bestiary_panel(GameConfig.tt("⚠ Текущая угроза", "⚠ Current threat"), Color(1.0, 0.55, 0.25))
	for line in _bestiary_threat_lines():
		_bestiary_line(threat, str(line), Color(0.95, 0.85, 0.7))

# --- Слайд одного врага: свой слайд на каждого — просторнее, крупнее портрет.
func _bestiary_slide_enemy(s: Dictionary, t: int) -> void:
	var d: Dictionary = GameConfig.BESTIARY[t]
	var seen := int(s.get("seen_t%d" % t, 0))
	var kills := int(s.get("kill_t%d" % t, 0))
	var hits := int(s.get("hit_t%d" % t, 0))
	var col: Color = d["color"]

	if seen <= 0:
		# Неизвестный: силуэт и намёк, где искать.
		var lock := _bestiary_panel("???", Color(0.35, 0.4, 0.5))
		var lrow := HBoxContainer.new()
		lrow.add_theme_constant_override("separation", 16)
		lock.add_child(lrow)
		var sil := TextureRect.new()
		sil.texture = MazeTextures.make_enemy(t, 40)
		# [BESTIARY-CAROUSEL] make_enemy(40) генерит текстуру ~172×172 (радиус —
		# не итоговый пиксельный размер, текстура больше из-за свечения).
		# STRETCH_KEEP_CENTERED не масштабирует — рисует текстуру в РЕАЛЬНОМ
		# размере поверх рамки, и она вылезает за края 90×90 (заметно только
		# тут, где рядом всего одна строка текста — со старым радиусом 26
		# текстура была меньше рамки, и баг был не виден). KEEP_ASPECT_CENTERED
		# реально уменьшает картинку под рамку. expand_mode нужен, чтобы
		# custom_minimum_size вообще мог сжать control ниже размера текстуры.
		sil.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sil.custom_minimum_size = Vector2(90, 90)
		sil.modulate = Color(0.06, 0.07, 0.1)   # чёрный силуэт
		lrow.add_child(sil)
		var lv := VBoxContainer.new()
		lrow.add_child(lv)
		_bestiary_line(lv, GameConfig.tt("Ещё не встречен (%s).", "Not encountered yet (%s).") % _bestiary_appear(t), Color(0.5, 0.55, 0.65), 16)
		# Текст короче иконки (одна строка) — без этого строка ровно 90px
		# высотой, иконка упирается точно в нижний паддинг панели, и её мягкое
		# свечение визуально задевает рамку. Небольшой запас снизу решает это.
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 10)
		lock.add_child(spacer)
		return

	var box := _bestiary_panel(GameConfig.bestiary_name(t), col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)

	# Портрет крупнее, чем в старой построчной вёрстке (26→40) — свой слайд, места хватает.
	var ic := TextureRect.new()
	ic.texture = MazeTextures.make_enemy(t, 40)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED   # [BESTIARY-CAROUSEL] см. sil выше
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.custom_minimum_size = Vector2(90, 90)
	row.add_child(ic)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(body)

	_bestiary_line(body, GameConfig.bestiary_lore(t), Color(0.75, 0.8, 0.92), 16)
	if kills > 0:
		_bestiary_line(body, GameConfig.tt("Тактика: %s", "Tactic: %s") % GameConfig.bestiary_tactic(t), Color(0.6, 1.0, 0.7), 15)
	else:
		_bestiary_line(body, GameConfig.tt("Досье неполно: одолей одного, чтобы вписать его слабости.", "Dossier incomplete: defeat one to record its weaknesses."), Color(0.85, 0.75, 0.5), 15)
	_bestiary_line(body, GameConfig.tt("Встреч: %d   •   Побеждено: %d   •   Ударов по тебе: %d   •   %s", "Encounters: %d   •   Defeated: %d   •   Hits on you: %d   •   %s") % [seen, kills, hits, _bestiary_appear(t)],
		Color(0.55, 0.62, 0.75), 13)

# Учебная программа «Пути мастерства»: упорядоченные уроки от выживания до
# Пылающего. Каждый — проверка по статистике + конкретный совет «как взять».
func _coach_steps(s: Dictionary, hist: Array) -> Array:
	var clean_done := false
	var fast_done := false
	var blazing_done := false
	for e in hist:
		if bool(e.get("no_dmg", false)):
			clean_done = true
		if float(e.get("time", 1e9)) <= float(e.get("par", 0.0)):
			fast_done = true
		if int(e.get("diff", 1)) == 2:
			blazing_done = true
	var best_mastery := 0
	for id in ["flash", "dash", "smother", "sonar", "shield", "guide", "reveal", "pulse", "mirage", "breach", "chrono"]:
		best_mastery = maxi(best_mastery, GameConfig.mastery(id))
	var lvls := int(s.get("levels_cleared", 0))
	var shards := int(s.get("shards_total", 0))
	var kills := int(s.get("enemies_killed", 0))
	var ranks_good := int(s.get("rank_S", 0)) + int(s.get("rank_A", 0))
	var depth := int(s.get("best_depth", 0))
	var en := GameConfig.locale == "en"
	if en:
		return [
			{"title": "Survival: clear 3 levels", "done": lvls >= 3,
			 "progress": "%d/3" % mini(lvls, 3),
			 "how": "stick to energy crystals — your light doesn't fade near them, it's a refuge and a checkpoint."},
			{"title": "Collector: 25 shards (unlocks Sonar)", "done": shards >= 25,
			 "progress": "%d/25" % mini(shards, 25),
			 "how": "shards are both keys and Will. Detour for a shard: it pays off."},
			{"title": "Fighter: defeat 8 enemies (unlocks Shield)", "done": kills >= 8,
			 "progress": "%d/8" % mini(kills, 8),
			 "how": "dash THROUGH an enemy — a tackle with no damage to you; flash point-blank also hits. A frozen enemy takes +1 damage."},
			{"title": "Shadow: clear a level without damage", "done": clean_done,
			 "progress": "not yet" if not clean_done else "done",
			 "how": "Smother (R) dims you to a spark — enemies lose your trail. Freeze, let the patrol pass, move on."},
			{"title": "Wind: clear a level faster than par time", "done": fast_done,
			 "progress": "not yet" if not fast_done else "done",
			 "how": "Guide (G) shows the path to the exit, dash speeds you up. Decide ahead: this level is for speed."},
			{"title": "Straight-A: get rank A or S", "done": ranks_good > 0,
			 "progress": "%d" % ranks_good,
			 "how": "rank formula: all shards + no damage + speed. The breakdown is on the victory screen."},
			{"title": "Master: bring any skill to 3★", "done": best_mastery >= 3,
			 "progress": "best — %d★" % best_mastery,
			 "how": "mastery grows from uses (10 = ★). Or buy an upgrade for SP in the skill shop."},
			{"title": "Apex: unlock all 7 active skills (or 4+ skills with one at ★5)", "done": bool(GameConfig.skills_unlocked.get("apex", false)),
			 "progress": "",
			 "how": "buy them for SP or earn them as milestones (Journal → «Path to skills»). The seventh skill unlocks Apex (H) on its own — or master one skill to ★5 once you own 4+."},
			{"title": "Firebearer: depth 10 in «Ember»", "done": depth >= 10,
			 "progress": "%d/10" % mini(depth, 10),
			 "how": "don't be greedy: bank Ember at every altar. Carried heat draws the dark — banked doesn't."},
			{"title": "Inferno: clear a level on the highest difficulty", "done": blazing_done,
			 "progress": "not yet" if not blazing_done else "done",
			 "how": "no stations — light only from shards (double capacity). Plan your route by shards and keep moving."},
		]
	return [
		{"title": "Выживание: пройди 3 уровня", "done": lvls >= 3,
		 "progress": "%d/3" % mini(lvls, 3),
		 "how": "держись энергокристаллов — возле них свет не гаснет, это убежище и точка возврата."},
		{"title": "Собиратель: 25 осколков (откроет Сонар)", "done": shards >= 25,
		 "progress": "%d/25" % mini(shards, 25),
		 "how": "осколки — это и ключи, и Воля. Сверни с прямого пути ради осколка: он окупается."},
		{"title": "Боец: победи 8 врагов (откроет Щит)", "done": kills >= 8,
		 "progress": "%d/8" % mini(kills, 8),
		 "how": "рывок СКВОЗЬ врага — таран без урона по тебе; вспышка в упор тоже бьёт. Замороженный враг ловит +1 урона."},
		{"title": "Тень: пройди уровень без урона", "done": clean_done,
		 "progress": "ещё нет" if not clean_done else "есть",
		 "how": "Тление (R) гасит тебя до искры — враги теряют след. Замри, пропусти патруль, иди дальше."},
		{"title": "Ветер: пройди уровень быстрее пар-тайма", "done": fast_done,
		 "progress": "ещё нет" if not fast_done else "есть",
		 "how": "Искра (G) показывает путь к выходу, рывок ускоряет. Реши заранее: этот уровень — на скорость."},
		{"title": "Отличник: возьми ранг A или S", "done": ranks_good > 0,
		 "progress": "%d" % ranks_good,
		 "how": "формула ранга: все осколки + без урона + скорость. Расшифровка — на экране победы."},
		{"title": "Мастер: доведи любой навык до 3★", "done": best_mastery >= 3,
		 "progress": "лучший — %d★" % best_mastery,
		 "how": "мастерство растёт от применений (10 = ★). Или купи усиление за SP в магазине навыков."},
		{"title": "Апекс: открой все 7 активных навыков (или 4+ навыка и один на ★5)", "done": bool(GameConfig.skills_unlocked.get("apex", false)),
		 "progress": "",
		 "how": "покупай за SP или бери целями (Дневник → «Путь к навыкам»). Седьмой навык откроет Апекс (H) сам — или прокачай один навык до ★5, когда куплено 4+."},
		{"title": "Огненосец: глубина 10 в «Накале»", "done": depth >= 10,
		 "progress": "%d/10" % mini(depth, 10),
		 "how": "не жадничай: банкуй Накал на каждом алтаре. Несомый жар притягивает тьму — банк нет."},
		{"title": "Пылающий: пройди уровень на высшей сложности", "done": blazing_done,
		 "progress": "ещё нет" if not blazing_done else "есть",
		 "how": "станций нет — свет только из осколков (запас ×2). Планируй маршрут по осколкам и не стой на месте."},
	]

func _on_open_journal() -> void:
	_journal_rebuild_slides()
	_populate_journal_slide(0)
	_hide_all_panels()
	_journal_scroll.visible = true
	_back_btn.visible = true

# =============================================================================
# ВЫБОР РЕЖИМА («Играть») — последовательный путь игрока: сначала выбор режима,
# затем игра. «Уровни» продолжаются с того места, где остановился; выбор
# конкретного уровня — вторичная кнопка внутри, а не главный экран.
# =============================================================================

func _build_mode(root: VBoxContainer) -> void:
	_mode_scroll = ScrollContainer.new()
	_mode_scroll.visible = false
	_mode_scroll.custom_minimum_size = Vector2(980, 520)
	_mode_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_mode_scroll)
	_mode_box = VBoxContainer.new()
	_mode_box.add_theme_constant_override("separation", 12)
	_mode_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_scroll.add_child(_mode_box)

func _populate_mode() -> void:
	for c in _mode_box.get_children():
		c.queue_free()

	# --- Верхний ряд: всегда доступные разделы (не режимы) ---
	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 14)
	_mode_box.add_child(top_row)
	for pair in [[GameConfig.t("top_shop"), _on_open_shop], [GameConfig.t("top_tutorial"), _on_open_tutorial], [GameConfig.t("top_journal"), _on_open_journal], [GameConfig.t("top_bestiary"), _on_open_bestiary]]:
		var tb := _make_button(str(pair[0]), pair[1])
		tb.custom_minimum_size = Vector2(200, 44)
		tb.add_theme_font_size_override("font_size", 18)
		top_row.add_child(tb)

	# --- Карточки-режимы. FlowContainer вместо HBox: на узких окнах карточки
	# переносятся на вторую строку вместо обрезания краем экрана (см.
	# GAMEDESIGN.md, «Известная проблема: границы экрана») — стало актуальнее
	# с добавлением 4-й карточки «Логово».
	# Все 4 карточки — в один ряд (не переносить кроме совсем узких окон):
	# HFlowContainer остаётся страховкой на маленьких экранах, но при ширине
	# _mode_scroll (980px) четыре карточки по 180px + отступы влезают в ряд.
	var cards := HFlowContainer.new()
	cards.alignment = FlowContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("h_separation", 14)
	cards.add_theme_constant_override("v_separation", 14)
	_mode_box.add_child(cards)

	var cur := clampi(GameConfig.level, 1, GameConfig.max_unlocked_level)
	cards.add_child(_mode_card(GameConfig.t("mode_levels_title"),
		GameConfig.t("mode_levels_desc") % cur,
		Color(0.45, 0.75, 1.0),
		func() -> void:
			GameConfig.active_run = -1
			_on_play(cur)))

	# [GAMEDESIGN §18] Последовательное открытие режимов — новичку видна только
	# «Уровни», остальные три появляются по мере прохождения кампании (пороги —
	# GameConfig.MODE_UNLOCK_*), вместо того чтобы вываливать все 4 сразу.
	if GameConfig.is_ember_unlocked():
		cards.add_child(_mode_card(GameConfig.t("mode_ember_title"),
			GameConfig.t("mode_ember_desc"),
			Color(1.0, 0.55, 0.25), _on_open_runs))
	else:
		cards.add_child(_locked_mode_card(GameConfig.t("mode_ember_title"), GameConfig.MODE_UNLOCK_EMBER - 1))

	if GameConfig.is_daily_unlocked():
		var streak := GameConfig.daily_streak()
		cards.add_child(_mode_card(GameConfig.t("mode_daily_title"),
			"%s\n\n%s%s" % [GameConfig.t("mode_daily_desc"), GameConfig.today_str(),
				("\n🔥 %d" % streak) if streak >= 2 else ""],
			Color(1.0, 0.85, 0.35), _on_open_daily))
	else:
		cards.add_child(_locked_mode_card(GameConfig.t("mode_daily_title"), GameConfig.MODE_UNLOCK_DAILY - 1))

	if GameConfig.is_lair_unlocked():
		cards.add_child(_mode_card(GameConfig.t("mode_lair_title"),
			GameConfig.t("mode_lair_desc") % [GameConfig.lair_max_unlocked, GameConfig.LAIR_LEVELS],
			Color(1.0, 0.3, 0.35), _on_open_lair_select))
	else:
		cards.add_child(_locked_mode_card(GameConfig.t("mode_lair_title"), GameConfig.MODE_UNLOCK_LAIR - 1))

	# --- Одна строка: выбор уровня + сложность ---
	var opts_row := HBoxContainer.new()
	opts_row.alignment = BoxContainer.ALIGNMENT_CENTER
	opts_row.add_theme_constant_override("separation", 12)
	_mode_box.add_child(opts_row)

	var pick_btn := _make_button(GameConfig.t("pick_level") % GameConfig.max_unlocked_level, _on_open_level_select)
	pick_btn.custom_minimum_size = Vector2(220, 42)
	pick_btn.add_theme_font_size_override("font_size", 16)
	opts_row.add_child(pick_btn)

	var diff_lbl := Label.new()
	diff_lbl.text = GameConfig.t("difficulty")
	diff_lbl.add_theme_font_size_override("font_size", 15)
	diff_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	opts_row.add_child(diff_lbl)

	var diff_desc := Label.new()
	diff_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	diff_desc.custom_minimum_size = Vector2(660, 0)
	diff_desc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	diff_desc.add_theme_font_size_override("font_size", 13)
	diff_desc.add_theme_color_override("font_color", Color(0.62, 0.68, 0.8))
	diff_desc.text = GameConfig.diff_desc(GameConfig.difficulty)

	var diff_colors := [Color(0.55, 0.8, 1.0), Color(1.0, 0.8, 0.35), Color(1.0, 0.42, 0.32)]
	var diff_marks := ["◦ ", "● ", "☀ "]
	var diff_btns: Array = []
	for i in 3:
		var db := Button.new()
		db.text = diff_marks[i] + GameConfig.diff_name(i)
		db.toggle_mode = true
		db.button_pressed = GameConfig.difficulty == i
		db.custom_minimum_size = Vector2(140, 42)
		db.add_theme_font_size_override("font_size", 16)
		db.add_theme_color_override("font_color", diff_colors[i])
		_style_button(db)
		diff_btns.append(db)
		var idx := i
		db.pressed.connect(func() -> void:
			GameConfig.difficulty = idx
			GameConfig.save_game()
			for j in 3:
				diff_btns[j].button_pressed = (j == idx)
			diff_desc.text = GameConfig.diff_desc(idx)
			_toast("%s: %s" % [GameConfig.t("difficulty").trim_suffix(":"), GameConfig.diff_name(idx)])
		)
		opts_row.add_child(db)
	_mode_box.add_child(diff_desc)

# Большая квадратная карточка режима: цветная рамка, название, описание.
func _mode_card(title: String, sub: String, accent: Color, cb: Callable) -> Button:
	var b := Button.new()
	# 4 карточки в один ряд при ширине _mode_scroll (980px): 4×182 + 3×14 = 770.
	b.custom_minimum_size = Vector2(182, 250)
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.06, 0.12, 0.92)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	b.add_theme_stylebox_override("normal", sb)
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.border_color = accent
	sbh.bg_color = Color(0.07, 0.09, 0.17, 0.96)
	b.add_theme_stylebox_override("hover", sbh)
	var sbp: StyleBoxFlat = sbh.duplicate()
	sbp.bg_color = Color(0.10, 0.13, 0.22, 0.98)
	b.add_theme_stylebox_override("pressed", sbp)
	b.pressed.connect(cb)
	# Карточка «оживает» под курсором: слегка приподнимается. Внутри
	# ScrollContainer масштаб запрещён (клиппинг краёв — см. GAMEDESIGN.md).
	b.mouse_entered.connect(func() -> void:
		if _inside_scroll(b):
			return
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(1.04, 1.04), 0.14) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	b.mouse_exited.connect(func() -> void:
		if b.scale == Vector2.ONE:
			return
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.14) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))

	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		mc.add_theme_constant_override(m, 14)
	b.add_child(mc)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	mc.add_child(v)

	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Автоперенос заголовка: «СПУСК ДНЯ» иначе не влезает в узкую карточку
	# (4 карточки в ряд — см. GAMEDESIGN.md, «Известная проблема: границы экрана»).
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", accent)
	t.add_theme_constant_override("outline_size", 5)
	t.add_theme_color_override("font_outline_color", Color(accent.r * 0.25, accent.g * 0.25, accent.b * 0.25, 0.9))
	v.add_child(t)

	var s := Label.new()
	s.text = sub
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size = Vector2(150, 0)
	s.add_theme_font_size_override("font_size", 12)
	s.add_theme_color_override("font_color", Color(0.72, 0.78, 0.9))
	v.add_child(s)
	return b

# [GAMEDESIGN §18] Карточка ещё не открытого режима — тот же _mode_card
# (единый стиль), только приглушённая (серый акцент + прозрачность) и с
# заголовком-подсказкой вместо описания; клик — тост с условием, а не переход.
func _locked_mode_card(title: String, need_level: int) -> Button:
	var grey := Color(0.42, 0.45, 0.5)
	var hint := GameConfig.tt("🔒 Откроется после уровня %d", "🔒 Unlocks after level %d") % need_level
	var card := _mode_card(title, hint, grey, func() -> void:
		_toast(GameConfig.tt("Пока закрыто — пройди уровень %d", "Still locked — clear level %d") % need_level))
	card.modulate = Color(1.0, 1.0, 1.0, 0.55)
	return card

# Магазин навыков (колесо Апекса) — тот же оверлей, что в паузе «Уровней».
# Правит глобальный профиль «Уровней» (в меню active_run всегда -1).
func _on_open_shop() -> void:
	var sm := CanvasLayer.new()
	sm.set_script(load("res://skills_menu.gd"))
	add_child(sm)

func _on_open_mode() -> void:
	_populate_mode()
	_hide_all_panels()
	_mode_scroll.visible = true
	_back_btn.visible = true

# =============================================================================
# СПУСК ДНЯ — ежедневный забег. Один и тот же лабиринт у всех игроков в этот
# день (сид = дата), одна попытка. Умер — приходи завтра. Механика — обёртка
# над забегом «Накал» (скрытый 4-й слот DAILY_SLOT в GameConfig).
# =============================================================================

func _build_daily(root: VBoxContainer) -> void:
	_daily_box = ScrollContainer.new()
	_daily_box.visible = false
	_daily_box.custom_minimum_size = Vector2(620, 480)
	_daily_box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_daily_box)

	_daily_inner = VBoxContainer.new()
	_daily_inner.add_theme_constant_override("separation", 10)
	_daily_inner.custom_minimum_size = Vector2(600, 0)
	_daily_box.add_child(_daily_inner)

func _populate_daily() -> void:
	for c in _daily_inner.get_children():
		c.queue_free()

	var en := GameConfig.locale == "en"
	var title := Label.new()
	title.text = GameConfig.tt("Спуск дня — %s", "Daily Dive — %s") % GameConfig.today_str()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_daily_inner.add_child(title)

	var sub := Label.new()
	sub.text = "Every day the maze is the same for everyone: same layout, same enemies.\nOne attempt. Ember rules: 3 lives for the whole descent, death ends it." if en else \
		"Каждый день лабиринт один для всех: тот же лабиринт, те же враги.\nОдна попытка. Правила Накала: 3 жизни на весь спуск, смерть — конец."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.7, 0.76, 0.88))
	_daily_inner.add_child(sub)

	var streak := GameConfig.daily_streak()
	if streak >= 2:
		var sl := Label.new()
		sl.text = ("🔥 Streak: %d days in a row" % streak) if en else ("🔥 Серия: %d %s подряд" % [streak, _plural(streak, "день", "дня", "дней")])
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.add_theme_font_size_override("font_size", 17)
		sl.add_theme_color_override("font_color", Color(1.0, 0.62, 0.25))
		_daily_inner.add_child(sl)

	# --- Состояние сегодняшнего дня ---
	if GameConfig.daily_resumable():
		var msg := Label.new()
		msg.text = (("Today's descent isn't finished — depth %d.") if en else ("Сегодняшний спуск не завершён — глубина %d.")) % int(GameConfig.runs[GameConfig.DAILY_SLOT].get("level", 1))
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		msg.add_theme_font_size_override("font_size", 17)
		msg.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
		_daily_inner.add_child(msg)
		_daily_inner.add_child(_make_button(GameConfig.tt("Продолжить спуск", "Resume the descent"), func() -> void:
			GameConfig.resume_daily_run()
			get_tree().change_scene_to_file("res://main.tscn")))
	elif GameConfig.daily_played_today() and not GameConfig.test_mode:
		var today := GameConfig.today_str()
		var res: Dictionary = {}
		for e in GameConfig.daily_history:
			if str(e.get("date", "")) == today:
				res = e
		var msg := Label.new()
		msg.text = (("Today you already descended: depth %d, Ember %d.\nThe maze will change shape at midnight — come back tomorrow.") if en else
			("Сегодня ты уже спускался: глубина %d, Накал %d.\nЛабиринт сменит облик в полночь — возвращайся завтра.")) % [
			int(res.get("depth", 1)), int(res.get("ember", 0))]
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		msg.add_theme_font_size_override("font_size", 17)
		msg.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
		_daily_inner.add_child(msg)
	else:
		if GameConfig.daily_played_today():
			var tst := Label.new()
			tst.text = "(test mode: attempt limit disabled)" if en else "(тест-режим: лимит попыток отключён)"
			tst.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tst.add_theme_font_size_override("font_size", 14)
			tst.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
			_daily_inner.add_child(tst)
		_daily_inner.add_child(_make_button(GameConfig.tt("Начать спуск", "Start the descent"), func() -> void:
			GameConfig.start_daily_run()
			get_tree().change_scene_to_file("res://main.tscn")))

	# --- Последние дни ---
	if not GameConfig.daily_history.is_empty():
		var hl := Label.new()
		hl.text = GameConfig.tt("Последние дни", "Recent days")
		hl.add_theme_font_size_override("font_size", 20)
		hl.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
		_daily_inner.add_child(hl)
		var hist: Array = GameConfig.daily_history
		var start := maxi(0, hist.size() - 7)
		for i in range(hist.size() - 1, start - 1, -1):
			var e: Dictionary = hist[i]
			var l := Label.new()
			l.text = GameConfig.tt("%s   ·   глубина %d   ·   Накал %d", "%s   ·   depth %d   ·   Ember %d") % [
				str(e.get("date", "?")), int(e.get("depth", 1)), int(e.get("ember", 0))]
			l.add_theme_font_size_override("font_size", 15)
			l.add_theme_color_override("font_color", Color(0.72, 0.78, 0.9))
			_daily_inner.add_child(l)

func _on_open_daily() -> void:
	_populate_daily()
	_hide_all_panels()
	_daily_box.visible = true
	_back_btn.visible = true

# ── КОДЕКС (GAMEDESIGN §30) ──────────────────────────────────────────────────
# Двухколоночный экран вместо прежней карусели слайдов Справки. Слева —
# навигация: заголовки разделов и кнопки статей (одним списком, как в кодексах
# современных игр). Справа — статья: заголовок, картинка, текст абзацами.
#
# Почему не карусель: слайд обязан влезать в один экран, поэтому текст
# приходилось резать до трёх строк — «прочитать и разобраться» по такому
# формату невозможно. У статьи есть своя прокрутка, поэтому её можно писать
# нормальной длины, а навигация при этом всегда на виду.

const CODEX_NAV_W := 288
const CODEX_ART_W := 604

func _build_codex(root: VBoxContainer) -> void:
	_codex_root = HBoxContainer.new()
	_codex_root.visible = false
	_codex_root.add_theme_constant_override("separation", 16)
	root.add_child(_codex_root)

	# --- левая колонка: список разделов и статей ---
	var nav_panel := PanelContainer.new()
	nav_panel.add_theme_stylebox_override("panel", _codex_panel_style())
	_codex_root.add_child(nav_panel)

	_codex_nav = ScrollContainer.new()
	_codex_nav.custom_minimum_size = Vector2(CODEX_NAV_W, 0)
	_codex_nav.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_codex_nav.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	nav_panel.add_child(_codex_nav)

	_codex_nav_box = VBoxContainer.new()
	_codex_nav_box.add_theme_constant_override("separation", 4)
	_codex_nav_box.custom_minimum_size = Vector2(_carousel_content_width(_codex_nav, CODEX_NAV_W), 0)
	_codex_nav.add_child(_codex_nav_box)

	# --- правая колонка: тело статьи ---
	var art_panel := PanelContainer.new()
	art_panel.add_theme_stylebox_override("panel", _codex_panel_style())
	_codex_root.add_child(art_panel)

	_codex_article = ScrollContainer.new()
	_codex_article.custom_minimum_size = Vector2(CODEX_ART_W, 0)
	_codex_article.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_codex_article.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	art_panel.add_child(_codex_article)

	_codex_body = VBoxContainer.new()
	_codex_body.add_theme_constant_override("separation", 12)
	_codex_body.custom_minimum_size = Vector2(_carousel_content_width(_codex_article, CODEX_ART_W), 0)
	_codex_article.add_child(_codex_body)

	_codex_rebuild_nav()

func _codex_panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.055, 0.10, 0.9)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.4, 0.5, 0.75, 0.5)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb

# Статьи «Что нового» собираются здесь, а не в codex.gd: их текст — те же
# CHANGELOG_*-константы, которые уже показывает окно «О версиях», и держать
# две копии одного чейнджлога значило бы обязательно их однажды разойтись.
func _codex_version_articles() -> Array:
	var en := GameConfig.locale == "en"
	var out: Array = []
	for v in [
		["3.2", CHANGELOG_32_A_EN if en else CHANGELOG_32_A, ""],
		["3.1", CHANGELOG_31_A_EN if en else CHANGELOG_31_A, ""],
		["3.0", CHANGELOG_30_A_EN if en else CHANGELOG_30_A, ""],
		["2.9", CHANGELOG_29_A_EN if en else CHANGELOG_29_A, ""],
		["2.8", CHANGELOG_28_A_EN if en else CHANGELOG_28_A, ""],
		["2.7", CHANGELOG_27_A_EN if en else CHANGELOG_27_A, ""],
		["2.6", CHANGELOG_26_A_EN if en else CHANGELOG_26_A, CHANGELOG_26_B_EN if en else CHANGELOG_26_B],
		["2.5", CHANGELOG_25_A_EN if en else CHANGELOG_25_A, CHANGELOG_25_B_EN if en else CHANGELOG_25_B],
		["2.4", CHANGELOG_24_A_EN if en else CHANGELOG_24_A, CHANGELOG_24_B_EN if en else CHANGELOG_24_B],
		["2.3", CHANGELOG_23_A_EN if en else CHANGELOG_23_A, CHANGELOG_23_B_EN if en else CHANGELOG_23_B],
		["2.2", CHANGELOG_22_A_EN if en else CHANGELOG_22_A, CHANGELOG_22_B_EN if en else CHANGELOG_22_B],
		["2.1", CHANGELOG_21_A_EN if en else CHANGELOG_21_A, CHANGELOG_21_B_EN if en else CHANGELOG_21_B],
		["2.0", CHANGELOG_20_A_EN if en else CHANGELOG_20_A, CHANGELOG_20_B_EN if en else CHANGELOG_20_B],
		["1.18", CHANGELOG_118_A_EN if en else CHANGELOG_118_A, CHANGELOG_118_B_EN if en else CHANGELOG_118_B],
		["1.17", CHANGELOG_117_A_EN if en else CHANGELOG_117_A, CHANGELOG_117_B_EN if en else CHANGELOG_117_B],
		["1.16", CHANGELOG_116_A_EN if en else CHANGELOG_116_A, ""],
		["1.15", CHANGELOG_115_A_EN if en else CHANGELOG_115_A, ""],
		["1.14", CHANGELOG_114_A_EN if en else CHANGELOG_114_A, ""],
		["1.13", CHANGELOG_113_A_EN if en else CHANGELOG_113_A, CHANGELOG_113_B_EN if en else CHANGELOG_113_B],
		["1.12", CHANGELOG_112_A_EN if en else CHANGELOG_112_A, CHANGELOG_112_B_EN if en else CHANGELOG_112_B],
		["1.11", CHANGELOG_111_A_EN if en else CHANGELOG_111_A, CHANGELOG_111_B_EN if en else CHANGELOG_111_B],
		["1.9",  CHANGELOG_19_A_EN if en else CHANGELOG_19_A, CHANGELOG_19_B_EN if en else CHANGELOG_19_B],
		["1.9 ", CHANGELOG_19_C_EN if en else CHANGELOG_19_C, CHANGELOG_19_D_EN if en else CHANGELOG_19_D],
		["1.8",  CHANGELOG_18_A_EN if en else CHANGELOG_18_A, CHANGELOG_18_C_EN if en else CHANGELOG_18_C],
		["1.7",  CHANGELOG_17_A_EN if en else CHANGELOG_17_A, CHANGELOG_17_B_EN if en else CHANGELOG_17_B],
		["1.6",  CHANGELOG_16_A_EN if en else CHANGELOG_16_A, CHANGELOG_16_B_EN if en else CHANGELOG_16_B],
		["1.5",  CHANGELOG_15_A_EN if en else CHANGELOG_15_A, CHANGELOG_15_B_EN if en else CHANGELOG_15_B],
	]:
		var ver: String = str(v[0]).strip_edges()
		var title := ("Version %s" % ver) if en else ("Версия %s" % ver)
		out.append({
			"sec": "versions", "id": "v" + ver, "fig": "versions",
			"title": title, "title_en": title,
			"body": "%s\n%s" % [v[1], v[2]],
			"body_en": "%s\n%s" % [v[1], v[2]],
		})
	return out

# [GAMEDESIGN §38] Статья «Лестница открытий» — единственное место, где игрок
# видит ВЕСЬ порядок ввода механик разом: что уже открылось, что следующее и на
# каком уровне. Строится из GameConfig.LADDER, а не из литерала: реестр там
# один, и статья не может разъехаться с реальными гейтами.
# Уже пройденное показывается с описанием, будущее — только именем и уровнем:
# ответ на вопрос «откуда это взялось» нужен, спойлер на 30 уровней вперёд — нет.
func _codex_ladder_article() -> Dictionary:
	var en := GameConfig.locale == "en"
	var lvl: int = GameConfig.max_unlocked_level
	var lines: Array = []
	lines.append(("Every mechanic in «Levels» enters the game at a fixed level, and always inside the stretch of the biome that owns it. Below is the full order. Reached entries show what they are; the rest show only when they arrive."
		if en else
		"Каждая механика «Уровней» входит в игру на фиксированном уровне — и всегда внутри полосы того биома, которому она принадлежит. Ниже весь порядок целиком. У пройденного видно, что это; у остального — только когда оно придёт."))
	lines.append("")
	var next_shown := false
	for e in GameConfig.LADDER:
		var el: int = int(e["level"])
		var nm: String = str(e["name_en"]) if en else str(e["name"])
		if lvl >= el:
			lines.append("✓  %d · %s" % [el, nm])
			lines.append("     " + (str(e["what_en"]) if en else str(e["what"])))
		else:
			var mark := "→" if not next_shown else "🔒"
			next_shown = true
			lines.append("%s  %d · %s" % [mark, el, nm])
		lines.append("")
	var title: String = "The ladder of discovery" if en else "Лестница открытий"
	var body: String = "\n".join(lines)
	return {
		"sec": "progress", "id": "ladder", "fig": "ladder",
		"title": title, "title_en": title,
		"body": body, "body_en": body,
	}

# Полный плоский список статей: данные из codex.gd плюс лестница и версии.
func _codex_all_articles() -> Array:
	var out: Array = []
	out.append_array(Codex.ARTICLES)
	out.append(_codex_ladder_article())
	out.append_array(_codex_version_articles())
	return out

func _codex_rebuild_nav() -> void:
	for c in _codex_nav_box.get_children():
		c.queue_free()
	_codex_entries = _codex_all_articles()
	_codex_buttons = []
	_codex_buttons.resize(_codex_entries.size())

	for sec in Codex.SECTIONS:
		var sid: String = str(sec["id"])
		var idxs: Array = []
		for i in _codex_entries.size():
			if str((_codex_entries[i] as Dictionary)["sec"]) == sid:
				idxs.append(i)
		if idxs.is_empty():
			continue
		var head := Label.new()
		head.text = Codex.title_of(sec).to_upper()
		head.add_theme_font_size_override("font_size", 13)
		head.add_theme_color_override("font_color", sec["color"])
		head.custom_minimum_size = Vector2(0, 26)
		head.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_codex_nav_box.add_child(head)
		for i: int in idxs:
			var art: Dictionary = _codex_entries[i]
			var btn := Button.new()
			btn.text = Codex.title_of(art)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.custom_minimum_size = Vector2(0, 34)
			btn.add_theme_font_size_override("font_size", 14)
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			UIStyle.style_button(btn)
			var capture: int = i
			btn.pressed.connect(func() -> void: _codex_open(capture))
			_codex_buttons[i] = btn
			_codex_nav_box.add_child(btn)

# Открыть статью idx: перерисовать правую колонку и подсветить кнопку слева.
func _codex_open(idx: int) -> void:
	if _codex_entries.is_empty():
		_codex_rebuild_nav()
	if _codex_entries.is_empty():
		return
	_codex_idx = clampi(idx, 0, _codex_entries.size() - 1)
	var art: Dictionary = _codex_entries[_codex_idx]

	for i in _codex_buttons.size():
		var b: Button = _codex_buttons[i]
		if b == null or not is_instance_valid(b):
			continue
		# Выбранная статья — ярче текстом; рамку не трогаем, её рисует UIStyle.
		b.add_theme_color_override("font_color",
			Color(1.0, 0.95, 0.75) if i == _codex_idx else Color(0.78, 0.84, 0.95))

	for c in _codex_body.get_children():
		c.queue_free()

	var sec_col := Color(0.7, 0.8, 1.0)
	for sec in Codex.SECTIONS:
		if str(sec["id"]) == str(art["sec"]):
			sec_col = sec["color"]
			break

	var kicker := Label.new()
	kicker.text = _codex_section_title(str(art["sec"])).to_upper()
	kicker.add_theme_font_size_override("font_size", 12)
	kicker.add_theme_color_override("font_color", sec_col)
	_codex_body.add_child(kicker)

	var title := Label.new()
	title.text = Codex.title_of(art)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.9, 0.94, 1.0))
	_codex_body.add_child(title)

	var fig := _codex_figure(str(art["fig"]), sec_col)
	if fig != null:
		_codex_body.add_child(fig)

	# Текст абзацами: пустая строка в данных = новый Label. Так у абзацев есть
	# настоящий интервал, а не двойной перевод строки внутри одной метки.
	# Списки-перечисления (статьи «Что нового» целиком из пунктов «•») режем
	# ещё и по одиночному переводу строки — иначе весь чейнджлог склеивается в
	# одну простыню без интервалов между пунктами.
	for para in Codex.body_of(art).split("\n\n"):
		var chunk: String = para.strip_edges()
		if chunk == "":
			continue
		var pieces: Array = [chunk]
		if chunk.begins_with("•") and chunk.contains("\n"):
			pieces = chunk.split("\n")
		for piece in pieces:
			var t: String = str(piece).strip_edges()
			if t == "":
				continue
			var l := Label.new()
			l.text = t
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.add_theme_font_size_override("font_size", 15)
			l.add_theme_color_override("font_color", Color(0.84, 0.88, 0.96))
			_codex_body.add_child(l)

	_codex_article.scroll_vertical = 0
	_refit_codex_deferred()

func _codex_section_title(sid: String) -> String:
	for sec in Codex.SECTIONS:
		if str(sec["id"]) == sid:
			return Codex.title_of(sec)
	return ""

func _on_open_codex() -> void:
	_hide_all_panels()
	if _codex_entries.is_empty() or _codex_idx < 0:
		_codex_open(0)
	_set_header_compact(true)
	_codex_root.visible = true
	_back_btn.visible = true
	_fit_codex()

# Обе колонки Кодекса — по правилу «Screen bounds»: высота по контенту, пока он
# влезает, дальше потолок по измеренному остатку колонки и автопрокрутка.
func _fit_codex() -> void:
	if _codex_root == null or not is_instance_valid(_codex_root):
		return
	_fit_carousel(_codex_article, _codex_body)
	_fit_carousel(_codex_nav, _codex_nav_box)

func _refit_codex_deferred() -> void:
	for _pass in 2:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		_fit_codex()

# ── Картинки статей ─────────────────────────────────────────────────────────
# Собираются из ТЕХ ЖЕ генераторов, что рисуют объекты в игре (MazeTextures,
# SkillIcons) — иначе картинка в кодексе и предмет в лабиринте однажды
# разойдутся. Диаграммы (полосы, стойка, ранги) рисуются простыми ColorRect.

func _codex_figure(id: String, accent: Color) -> Control:
	match id:
		"goal":
			return _codex_icons([
				[MazeTextures.make_player_orb(20), Color.WHITE, "ты"],
				[MazeTextures.make_key_crystal(16, Color(1.0, 0.55, 0.30)), Color.WHITE, "осколок"],
				[MazeTextures.make_portal(20, Color(1.0, 0.86, 0.30)), Color.WHITE, "портал"],
			])
		"controls":
			return _codex_keys(["Z", "X", "Q", "Shift", "R", "E", "C", "G", "F", "H"])
		"first_run":
			return _codex_icons([
				[MazeTextures.make_key_crystal(16, Color(1.0, 0.55, 0.30)), Color.WHITE, "собери"],
				[MazeTextures.make_charge_station(18, Color(0.35, 0.8, 1.0)), Color.WHITE, "заправься"],
				[MazeTextures.make_portal(18, Color(1.0, 0.86, 0.30)), Color.WHITE, "уходи"],
			])
		"bars":
			return _codex_bars()
		"stance", "visibility":
			return _codex_stance()
		"skills_base":
			return _codex_skill_row(["flash", "dash", "smother"], ["Q", "Shift", "R"])
		"skills_buy":
			return _codex_skill_row(["sonar", "shield", "guide", "reveal"], ["E", "C", "G", "F"])
		"skills_combo":
			return _codex_skill_row(["dash", "flash", "shield", "sonar"], ["+", "=", "+", "="])
		"skills_gift":
			return _codex_skill_row(["mirage", "breach", "chrono", "apex"], ["T", "Y", "V", "H"])
		"noise":
			return _codex_noise()
		"streak":
			return _codex_streak()
		"escalation":
			return _codex_escalation()
		"roles":
			return _codex_roles()
		"hearing":
			return _codex_hearing()
		"shards":
			return _codex_icons([
				[MazeTextures.make_key_crystal(16, Color(1.0, 0.55, 0.30)), Color.WHITE, "осколок = ключ"],
				[MazeTextures.make_portal(16, Color(0.66, 0.45, 1.0)), Color.WHITE, "открыта"],
				[MazeTextures.make_lock(16, Color(1.0, 0.55, 0.30)), Color.WHITE, "заперта"],
			])
		"stations":
			return _codex_icons([
				[MazeTextures.make_charge_station(18, Color(0.35, 0.8, 1.0)), Color.WHITE, "укрытие"],
				[MazeTextures.make_portal(16, Color(0.55, 0.2, 0.75)), Color.WHITE, "тёмная"],
			])
		"hazards":
			return _codex_icons([
				[MazeTextures.make_ring(28), Color(0.45, 0.42, 0.5), "яма"],
				[MazeTextures.make_portal(16, Color(0.3, 0.9, 0.85)), Color.WHITE, "срезка"],
			])
		"events":
			return _codex_glyphs(["⛰", "▦", "✦", "≈", "⚠", "⚡"], accent)
		"claim":
			# [§41] Те же цвета, что у следа в игре (main.gd claim_color).
			return _codex_glyphs(["свежая ▮", "тлеет ▮", "тьма забрала ▯"], Color(1.0, 0.78, 0.42))
		"spine":
			# [§40] Те же цвета, что у столпов в игре (main.gd HUB_COLORS).
			return _codex_icons([
				[MazeTextures.make_light(26), Color(0.35, 0.85, 1.00), "зал"],
				[MazeTextures.make_light(26), Color(1.00, 0.55, 0.25), "зал"],
				[MazeTextures.make_light(26), Color(0.75, 0.45, 1.00), "зал"],
			])
		"ladder":
			# [§38] Ближайшие ступени: последняя пройденная и три следующие —
			# картинка отвечает «где я на лестнице», а текст статьи — «что где».
			return _codex_glyphs(_codex_ladder_glyphs(), accent)
		"biomes", "biomes3":
			return _codex_biomes()
		"enemies":
			return _codex_enemies()
		"guests":
			return _codex_icons([
				[_guest_icon("gold"), Color.WHITE, "беглец"],
				[_guest_icon("azure"), Color(0.5, 1.0, 0.75), "огонёк"],
				[_guest_icon("crimson"), Color.WHITE, "кроты"],
				[_guest_icon("silver"), Color.WHITE, "вор"],
			])
		"boss_door":
			return _codex_icons([
				[MazeTextures.make_portal(20, Color(0.8, 0.12, 0.2)), Color.WHITE, "дверь"],
				[MazeTextures.make_ball(16, Color(0.6, 0.2, 0.9)), Color.WHITE, "ядро"],
			])
		"boss_final":
			return _codex_icons([
				[MazeTextures.make_superboss_body(22, Color(0.75, 0.2, 0.85)), Color.WHITE, "страж"],
				[MazeTextures.make_portal(16, Color(0.42, 0.12, 0.55)), Color.WHITE, "арена"],
			])
		"modes_levels":
			return _codex_glyphs(["Тлеющий", "Горящий", "Пылающий"], accent)
		"modes_ember":
			return _codex_icons([
				[MazeTextures.make_light(36), Color(1.0, 0.55, 0.2), "жар"],
				[MazeTextures.make_charge_station(18, Color(1.0, 0.7, 0.3)), Color.WHITE, "алтарь"],
			])
		"modes_other":
			return _codex_glyphs(["Спуск дня", "Логово", "Обучение"], accent)
		"progress_sp":
			return _codex_glyphs(["SP", "★★★☆☆", "пассивки"], accent)
		"progress_rank":
			return _codex_ranks()
		"progress_journal":
			return _codex_glyphs(["Дневник", "Бестиарий", "Профили"], accent)
		"versions":
			return null
	return null

# Ряд «иконка + подпись».
func _codex_icons(items: Array) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	for it in items:
		var spec: Array = it
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		var ic := TextureRect.new()
		ic.texture = spec[0]
		ic.modulate = spec[1]
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(52, 52)
		col.add_child(ic)
		var lb := Label.new()
		lb.text = str(spec[2])
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.add_theme_font_size_override("font_size", 11)
		lb.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))
		col.add_child(lb)
		row.add_child(col)
	return row

# Ряд иконок навыков с подписью клавиши.
func _codex_skill_row(ids: Array, keys: Array) -> Control:
	var items: Array = []
	for i in ids.size():
		var sid: String = str(ids[i])
		items.append([SkillIcons.make_hd(sid, 46), Color.WHITE, str(keys[i])])
	return _codex_icons(items)

# Клавиши как «кнопки» — для статьи про управление.
func _codex_keys(keys: Array) -> Control:
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	for k in keys:
		var p := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.10, 0.13, 0.20, 0.95)
		sb.set_corner_radius_all(6)
		sb.set_border_width_all(1)
		sb.border_color = Color(0.45, 0.6, 0.9, 0.6)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 5
		sb.content_margin_bottom = 5
		p.add_theme_stylebox_override("panel", sb)
		var l := Label.new()
		l.text = str(k)
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
		p.add_child(l)
		row.add_child(p)
	return row

# Диаграмма двух полос — Свет и Воля, теми же цветами, что в HUD.
func _codex_bars() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	for spec in [
		["Свет", "Light", Color(1.0, 0.85, 0.3), 14, "жизнь · тает во тьме", "life - fades in the dark"],
		["Воля", "Will", Color(0.3, 0.9, 0.95), 9, "навыки · копится сама", "skills - refills itself"],
	]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name := Label.new()
		name.text = str(spec[1]) if GameConfig.locale == "en" else str(spec[0])
		name.custom_minimum_size = Vector2(52, 0)
		name.add_theme_font_size_override("font_size", 13)
		name.add_theme_color_override("font_color", spec[2])
		row.add_child(name)
		var bar := ColorRect.new()
		bar.color = spec[2]
		bar.custom_minimum_size = Vector2(240, int(spec[3]))
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var note := Label.new()
		note.text = str(spec[5]) if GameConfig.locale == "en" else str(spec[4])
		note.add_theme_font_size_override("font_size", 11)
		note.add_theme_color_override("font_color", Color(0.62, 0.7, 0.82))
		row.add_child(note)
		box.add_child(row)
	return box

# Диаграмма стойки света: три сегмента с реальными числами из player.gd.
func _codex_stance() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var names_ru := ["Тусклый", "Ровный", "Яркий"]
	var names_en := ["Dim", "Even", "Bright"]
	var cols := [Color(0.45, 0.60, 0.85), Color(1.0, 0.86, 0.35), Color(1.0, 0.72, 0.25)]
	var drain := ["×0.45", "×1.0", "×2.40"]
	var vis := ["×0.55", "×1.0", "×1.75"]
	for i in 3:
		var card := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(cols[i].r * 0.16, cols[i].g * 0.16, cols[i].b * 0.16, 0.95)
		sb.set_corner_radius_all(8)
		sb.set_border_width_all(1)
		sb.border_color = Color(cols[i].r, cols[i].g, cols[i].b, 0.55)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", sb)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 3)
		var glow := TextureRect.new()
		glow.texture = MazeTextures.make_light(30)
		glow.modulate = cols[i]
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glow.custom_minimum_size = Vector2(38 + i * 12, 34)
		col.add_child(glow)
		var nm := Label.new()
		nm.text = str(names_en[i]) if GameConfig.locale == "en" else str(names_ru[i])
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.add_theme_font_size_override("font_size", 13)
		nm.add_theme_color_override("font_color", cols[i])
		col.add_child(nm)
		var d := Label.new()
		d.text = ("burn %s" % drain[i]) if GameConfig.locale == "en" else ("расход %s" % drain[i])
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.add_theme_font_size_override("font_size", 11)
		d.add_theme_color_override("font_color", Color(0.7, 0.76, 0.88))
		col.add_child(d)
		var v := Label.new()
		v.text = ("seen %s" % vis[i]) if GameConfig.locale == "en" else ("заметность %s" % vis[i])
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_theme_font_size_override("font_size", 11)
		v.add_theme_color_override("font_color", Color(0.7, 0.76, 0.88))
		col.add_child(v)
		card.add_child(col)
		row.add_child(card)
	return row

# Три биома — их настоящие цвета стен из main.gd BIOMES.
func _codex_biomes() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	for spec in [
		[Color(0.18, 0.72, 1.00), "Лазурные шахты", "Azure Mines", "срезки", "shortcuts"],
		[Color(1.00, 0.32, 0.26), "Багровые недра", "Crimson Depths", "ямы", "chasms"],
		[Color(0.55, 1.00, 0.30), "Споровые пустоты", "Spore Wastes", "тьма", "darkness"],
	]:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 3)
		var sw := ColorRect.new()
		sw.color = spec[0]
		sw.custom_minimum_size = Vector2(120, 14)
		col.add_child(sw)
		var nm := Label.new()
		nm.text = str(spec[2]) if GameConfig.locale == "en" else str(spec[1])
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.custom_minimum_size = Vector2(120, 0)
		nm.add_theme_font_size_override("font_size", 12)
		nm.add_theme_color_override("font_color", spec[0])
		col.add_child(nm)
		var th := Label.new()
		th.text = str(spec[4]) if GameConfig.locale == "en" else str(spec[3])
		th.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		th.add_theme_font_size_override("font_size", 11)
		th.add_theme_color_override("font_color", Color(0.66, 0.73, 0.85))
		col.add_child(th)
		row.add_child(col)
	return row

# Портреты врагов — те же make_enemy, что в игре и в Бестиарии.
func _codex_enemies() -> Control:
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 14)
	row.add_theme_constant_override("v_separation", 6)
	var names_ru := ["медлит.", "быстрый", "циклич.", "Страж", "Фантом", "Пиявка"]
	var names_en := ["slow", "fast", "cyclic", "Sentinel", "Phantom", "Leech"]
	for t in 6:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		var ic := TextureRect.new()
		ic.texture = MazeTextures.make_enemy(t, 18)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(46, 46)
		col.add_child(ic)
		var lb := Label.new()
		lb.text = str(names_en[t]) if GameConfig.locale == "en" else str(names_ru[t])
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.add_theme_font_size_override("font_size", 11)
		lb.add_theme_color_override("font_color", Color(0.7, 0.76, 0.86))
		col.add_child(lb)
		row.add_child(col)
	return row

# Ранги — теми же цветами, что на экране результатов.
func _codex_ranks() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for spec in [["S", "×1.5"], ["A", "×1.25"], ["B", "×1.0"], ["C", "×0.85"], ["D", "×0.7"]]:
		var c: Color = _RESULT_RANK_COLORS.get(str(spec[0]), Color.WHITE)
		var card := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(c.r * 0.16, c.g * 0.16, c.b * 0.16, 0.95)
		sb.set_corner_radius_all(8)
		sb.set_border_width_all(1)
		sb.border_color = Color(c.r, c.g, c.b, 0.6)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		card.add_theme_stylebox_override("panel", sb)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		var r := Label.new()
		r.text = str(spec[0])
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.add_theme_font_size_override("font_size", 22)
		r.add_theme_color_override("font_color", c)
		col.add_child(r)
		var m := Label.new()
		m.text = str(spec[1])
		m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		m.add_theme_font_size_override("font_size", 11)
		m.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88))
		col.add_child(m)
		card.add_child(col)
		row.add_child(card)
	return row

# Диаграмма шума: сравнение радиусов слышимости с радиусом ЗРЕНИЯ врага —
# главная мысль статьи в одной картинке (Сонар слышно вдвое дальше, чем ты
# успеешь увидеть пришедшего). Полосы масштабированы к самой громкой.
func _codex_noise() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	var rows := [
		["Разлом", "Breach", 700.0, Color(1.0, 0.45, 0.35)],
		["Сонар", "Sonar", 620.0, Color(1.0, 0.55, 0.35)],
		["Вспышка", "Flash", 520.0, Color(1.0, 0.72, 0.35)],
		["зрение врага", "enemy sight", 330.0, Color(0.55, 0.75, 1.0)],
		["Рывок", "Dash", 200.0, Color(0.75, 0.85, 0.6)],
		["Тление", "Smother", 0.0, Color(0.45, 0.60, 0.85)],
	]
	for r in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var nm := Label.new()
		nm.text = str(r[1]) if GameConfig.locale == "en" else str(r[0])
		nm.custom_minimum_size = Vector2(112, 0)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		nm.add_theme_font_size_override("font_size", 12)
		nm.add_theme_color_override("font_color", r[3])
		row.add_child(nm)
		var bar := ColorRect.new()
		bar.color = r[3]
		bar.custom_minimum_size = Vector2(maxf(float(r[2]) / 700.0 * 300.0, 3.0), 11)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var val := Label.new()
		val.text = ("бесшумно" if GameConfig.locale != "en" else "silent") if float(r[2]) <= 0.0 else str(int(r[2]))
		val.add_theme_font_size_override("font_size", 11)
		val.add_theme_color_override("font_color", Color(0.66, 0.73, 0.85))
		row.add_child(val)
		box.add_child(row)
	return box

# Диаграмма слуха: насколько дальше слышно врагов в разных стойках. Числа те
# же, что в player.STANCE_HEARING/SMOTHER_HEARING — при правке баланса
# правится и здесь (menu.gd не грузит player.gd).
func _codex_hearing() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	for r in [
			["Тление", "Smother", 1.5, Color(0.55, 0.75, 1.0)],
			["Тусклый", "Dim", 1.35, Color(0.45, 0.60, 0.85)],
			["Ровный", "Even", 1.0, Color(1.0, 0.86, 0.35)],
			["Яркий", "Bright", 0.8, Color(1.0, 0.72, 0.25)]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var nm := Label.new()
		nm.text = str(r[1]) if GameConfig.locale == "en" else str(r[0])
		nm.custom_minimum_size = Vector2(96, 0)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		nm.add_theme_font_size_override("font_size", 13)
		nm.add_theme_color_override("font_color", r[3])
		row.add_child(nm)
		var bar := ColorRect.new()
		bar.color = r[3]
		bar.custom_minimum_size = Vector2(float(r[2]) / 1.5 * 230.0, 12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var val := Label.new()
		val.text = "×%.2f" % float(r[2])
		val.add_theme_font_size_override("font_size", 11)
		val.add_theme_color_override("font_color", Color(0.66, 0.73, 0.85))
		row.add_child(val)
		box.add_child(row)
	return box

# Диаграмма серии осколков: лестница множителей до потолка. Числа берутся из
# тех же констант, что и в игре (main.gd STREAK_STEP / STREAK_MULT_MAX), но
# menu.gd не грузит main.gd — поэтому шаг задан здесь и должен совпадать.
const _CODEX_STREAK_STEP := 0.25
const _CODEX_STREAK_MAX := 2.5

func _codex_streak() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	for n in [1, 2, 3, 4, 5, 7]:
		var m: float = minf(1.0 + (n - 1) * _CODEX_STREAK_STEP, _CODEX_STREAK_MAX)
		var k: float = clampf((m - 1.0) / (_CODEX_STREAK_MAX - 1.0), 0.0, 1.0)
		var c: Color = Color(1.0, 0.72, 0.45).lerp(Color(1.0, 0.95, 0.45), k)
		var card := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(c.r * 0.16, c.g * 0.16, c.b * 0.16, 0.95)
		sb.set_corner_radius_all(8)
		sb.set_border_width_all(1)
		sb.border_color = Color(c.r, c.g, c.b, 0.55)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		card.add_theme_stylebox_override("panel", sb)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		var s1 := Label.new()
		s1.text = "×%d" % n
		s1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s1.add_theme_font_size_override("font_size", 15)
		s1.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88))
		col.add_child(s1)
		var s2 := Label.new()
		s2.text = "%.2f" % m
		s2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s2.add_theme_font_size_override("font_size", 17)
		s2.add_theme_color_override("font_color", c)
		col.add_child(s2)
		card.add_child(col)
		row.add_child(card)
	return row

# Диаграмма эскалации: три стадии уровня как шкала времени. Пороги подписаны
# в долях нормы времени, а не в секундах — в игре они и считаются так
# (main.gd ESCALATION_STAGE*_MULT), потому что зависят от номера уровня.
func _codex_escalation() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var rows := [
		["Тишина", "Silence", "до нормы времени", "up to par time", Color(0.55, 0.85, 0.65), 0.30],
		["Тьма густеет", "Dark thickens", "×1.15 нормы  ·  обзор 0.9", "x1.15 par  -  view 0.9", Color(0.55, 0.65, 0.95), 0.62],
		["Охота: ЛОВЧИЙ", "The hunt: STALKER", "×1.90 нормы  ·  обзор 0.8", "x1.90 par  -  view 0.8", Color(1.0, 0.45, 0.75), 1.0],
	]
	for r in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var nm := Label.new()
		nm.text = str(r[1]) if GameConfig.locale == "en" else str(r[0])
		nm.custom_minimum_size = Vector2(130, 0)
		nm.add_theme_font_size_override("font_size", 13)
		nm.add_theme_color_override("font_color", r[4])
		row.add_child(nm)
		var bar := ColorRect.new()
		bar.color = r[4]
		bar.custom_minimum_size = Vector2(float(r[5]) * 190.0, 12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var note := Label.new()
		note.text = str(r[3]) if GameConfig.locale == "en" else str(r[2])
		note.add_theme_font_size_override("font_size", 11)
		note.add_theme_color_override("font_color", Color(0.66, 0.73, 0.85))
		row.add_child(note)
		box.add_child(row)
	return box

# Картинка статьи про роли: слева обычный враг (идёт к тебе), в центре
# загонщик в своём жёлтом тоне (идёт к твоему пути отхода), справа мимик —
# та же текстура станции, что и у настоящей, иначе подделка не читалась бы.
func _codex_roles() -> Control:
	return _codex_icons([
		[MazeTextures.make_enemy(0, 18), Color.WHITE,
			"обычный" if GameConfig.locale != "en" else "ordinary"],
		[MazeTextures.make_enemy(0, 18), Color(1.0, 0.85, 0.45),
			"загонщик" if GameConfig.locale != "en" else "herder"],
		[MazeTextures.make_charge_station(18, Color(0.35, 0.8, 1.0)), Color.WHITE,
			"мимик?" if GameConfig.locale != "en" else "mimic?"],
	])

# Ряд текстовых глифов/ярлыков — для статей без своей иконки.
# [§38] Метки ступеней для картинки статьи «Лестница открытий»: пройденное с
# галочкой, ближайшее со стрелкой. Берём окно вокруг текущего прогресса, а не
# весь список из 18 пунктов — иначе строка чипов уезжает за край панели.
func _codex_ladder_glyphs() -> Array:
	var en := GameConfig.locale == "en"
	var lvl: int = GameConfig.max_unlocked_level
	var done: Array = []
	var next: Array = []
	for e in GameConfig.LADDER:
		var nm: String = str(e["name_en"]) if en else str(e["name"])
		var chip: String = "%d · %s" % [int(e["level"]), nm]
		if lvl >= int(e["level"]):
			done.append("✓ " + chip)
		elif next.size() < 3:
			next.append(("→ " if next.is_empty() else "🔒 ") + chip)
	var out: Array = done.slice(maxi(done.size() - 2, 0))
	out.append_array(next)
	return out

func _codex_glyphs(items: Array, accent: Color) -> Control:
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 6)
	for it in items:
		var p := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(accent.r * 0.14, accent.g * 0.14, accent.b * 0.14, 0.95)
		sb.set_corner_radius_all(8)
		sb.set_border_width_all(1)
		sb.border_color = Color(accent.r, accent.g, accent.b, 0.5)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		p.add_theme_stylebox_override("panel", sb)
		var l := Label.new()
		l.text = str(it)
		l.add_theme_font_size_override("font_size", 16)
		l.add_theme_color_override("font_color", accent)
		p.add_child(l)
		row.add_child(p)
	return row

# Цветовые метки гостей лабиринта (те же, что у самих гостей в игре).
const _GUEST_COLORS := {
	"gold": Color(1.0, 0.8, 0.2), "azure": Color(0.5, 1.0, 0.75),
	"crimson": Color(0.85, 0.6, 0.3), "silver": Color(0.7, 0.4, 1.0),
}

# Иконка гостя — та же текстура, что у самого гостя в игре.
func _guest_icon(id: String) -> Texture2D:
	var col: Color = _GUEST_COLORS.get(id, Color.WHITE)
	match id:
		"gold":
			return MazeTextures.make_runner_spark(15, col)
		"crimson":
			return MazeTextures.make_molehill(13, col)
		"silver":
			return MazeTextures.make_sack(15, col)
		_:
			return MazeTextures.make_light(40)   # azure/Огонёк — тот же мягкий блик, что и в игре
# Цвета карточек режимов (те же, что на экране «Играть»).
const _MODE_COLORS := {
	"u": Color(0.45, 0.75, 1.0), "n": Color(1.0, 0.55, 0.25),
	"d": Color(1.0, 0.85, 0.35), "l": Color(1.0, 0.3, 0.35),
}

# Мини-галерея слайда: иконка + подпись в сетке, короткая заметка под ней.
func _on_play(lvl: int = 1) -> void:
	GameConfig.level = lvl
	get_tree().change_scene_to_file("res://main.tscn")

func _on_open_tutorial() -> void:
	GameConfig.active_run = -1
	GameConfig.tutorial_mode = true
	GameConfig.tutorial_stage = 0
	GameConfig.level = 1
	get_tree().change_scene_to_file("res://main.tscn")

func _on_open_level_select() -> void:
	_hide_all_panels()
	_level_box.visible = true
	_back_btn.visible = true

func _on_open_settings() -> void:
	_hide_all_panels()
	_settings_scroll.visible = true
	_back_btn.visible = true

func _on_reset_progress() -> void:
	GameConfig.reset_progress()

func _on_quit() -> void:
	GameConfig.save_game()
	get_tree().quit()
