# MAGE RAGE — Registro de Decisiones de Diseño

> Bitácora de decisiones que resuelven ambigüedades del GDD/LORE. Cada entrada es
> **ACEPTADA** (decisión firme) o **PROVISIONAL** (default razonable, sujeto a
> playtest). El skill `.claude/skills/game-design/` debe respetar estas decisiones
> al validar features. Canon narrativo: `docs/LORE-BIBLE.md`. Diseño: `docs/GDD.md`.

---

## DD-001 — Dificultad dinámica vs. tono de "victoria ganada"  ·  **ACEPTADA**

**Tensión:** El GDD §4 dice "cuanto más poder desatas, más fuertes las contramedidas
del Imperio". El riesgo clásico de la dificultad dinámica (DDA) es que el jugador
*note* el rubber-banding y sienta que sus victorias no se ganaron — choca con el tono
severo y de muerte-justa de Mage Rage.

**Decisión:** La escalada del Imperio se ata a **hitos de progresión permanentes**
(cada elemento absorbido despliega un nuevo *tier* de contramedidas), justificada
**en ficción** (el Imperio reacciona a un prisionero más peligroso). **Nunca** habrá
un nerf oculto basado en muertes ("moriste → enemigo más fácil"). La dificultad es
**justa y determinista**: el jugador siempre puede entender por qué murió. Sin
rubber-banding invisible.

---

## DD-002 — Tuning del Ultimate de Antimateria  ·  **PROVISIONAL**

**Tensión:** Fuente de carga, rareza, riesgo/recompensa y ventana de vulnerabilidad
sin definir en canon.

**Defaults provisionales (a confirmar en playtest):**
- **Carga:** una barra que sube al **dar y recibir daño elemental** (recompensa jugar
  agresivo y mezclar elementos), no por tiempo.
- **Rareza:** carga completa ≈ una vez cada varios encuentros; debe sentirse un evento.
- **Efecto:** ~6–8 s encarnando los cuatro elementos + vuelo, daño alto, lectura visual
  inconfundible.
- **Riesgo:** al terminar, breve estado "agotado" (cooldown/vulnerabilidad) — el poder
  cuesta, coherente con el tema "todo ascenso es también una invocación".

**No bloquea el demo de movimiento** (el ultimate no entra todavía).

---

## DD-003 — Legibilidad de Mapa / UI de gates  ·  **PROVISIONAL**

**Tensión:** El backtracking metroidvania depende de un mapa legible y gates
codificados visualmente; ni GDD ni LORE definen la UI.

**Decisión provisional:** Adoptar un mapa estilo metroidvania con **gates codificados
por color/ícono según elemento**: Fuego = rojo, Hielo = azul, Electricidad = amarillo,
Antimateria = violeta. El jugador identifica de un vistazo qué ruta requiere qué verbo
de movimiento. Diseño completo de la UI de mapa **diferido a una fase posterior**; por
ahora queda fijada la convención de color.

---

## DD-004 — Anti-dominancia con sólo 3 elementos de combate  ·  **ACEPTADA (con mitigación)**

**Tensión:** Mantener Fuego/Hielo/Electricidad ~equivalentes en juego óptimo, pero con
identidad distinta, es estrecho con sólo tres opciones.

**Decisión:** Identidades comprometidas y distintas:
- **Fuego** — daño directo de objetivo único / ráfaga (brute, burst).
- **Hielo** — control: ralentiza/detiene sistemas mecánicos (control, defensa).
- **Electricidad** — daño en cadena multi-objetivo (alcance, grupos).
El balance se valida con un **playtest de combate en greybox temprano** (antes de
fijar números). Se acepta el riesgo, se mitiga con playtest. Regla de oro del skill:
ningún elemento debe ser dominante en un sector dado — el matchup vs. armadura del
enemigo debe forzar el cambio.

---

## DD-005 — Idioma de la documentación  ·  **ACEPTADA**

**Tensión:** El GDD está en español; LORE-BIBLE y los skills técnicos en inglés.

**Decisión (convención del proyecto):**
- **Docs de diseño y canon → español** (`GDD.md`, este registro, specs de diseño) —
  alinea con el idioma del equipo.
- **Código, comentarios de código, nombres de símbolos, skills técnicos y docs de
  ingeniería → inglés** (estándar de industria; coincide con `godot-game-dev` y GUT).
- `LORE-BIBLE.md` se mantiene en inglés (es el system-prompt canónico para generación
  de lore; reescribirlo no aporta y rompería referencias).

**Nota TASK-054 — Dash (suelo, botón RB / Shift):**
El dash terrestre (`MoveState`, TASK-054) opera con cooldown. Gateado por Fuego. Binding
definitivo: RB (botón 10, right shoulder) / Shift — véase corrección en DD-007.

**Nota TASK-055 — Dash unificado repeatable (todos los estados, PROVISIONAL):**
El dash se **unificó** en un único `DashComponent` (nodo hijo del Player) que es la fuente
de verdad de todas las constantes y la lógica de burst/cooldown. Los cuatro estados
(`MoveState`, `JumpState`, `GlideState`, `FlightState`) delegan en él.

- **Tuning nuevo (PROVISIONAL, DD-001):** `DASH_SPEED` 460 → **700 px/s**, `DASH_TIME`
  0.12 → **0.16 s** (distancia ≈ 112 px), `DASH_COOLDOWN` 0.35 → **0.30 s**.
- **Repeatable en todos los estados:** el modelo "uno por airtime" de `JumpState` fue
  reemplazado por cooldown compartido. Una vez transcurrido `DASH_COOLDOWN` el jugador
  puede volver a dashes en cualquier estado.
- **Cooldown compartido entre estados:** el cooldown pertenece al `DashComponent`, no al
  estado. Un dash en vuelo bloquea el re-dash al aterrizar hasta que el cooldown expire.
- **Suppresión del dash aéreo en zona anti-magia (DD-011 / TASK-028):** mientras
  `player.is_flight_suppressed()` es verdadero (zona anti-magia sin purgar), el dash
  **aéreo** (off-floor) es un no-op. El dash **terrestre** NO está suprimido. Auditoría
  bypass confirmada: el alcance de 112 px no crea ninguna vía nueva de cruce sin purgar.
  - Gate FIRE (sector_02): barrera `StaticBody2D` completa — el dash impacta la pared.
  - Zona anti-magia (~88 px gap superior): dash aéreo suprimido por código; dash terrestre
    impacta la barrera inferior. Ningún bypass.
  - Gap jefe (≈98 px vertical): el dash es puramente horizontal (velocity.y = 0); no
    puede cruzar un gap vertical. Ningún bypass.
- **Burst:** `velocity.x = facing * DASH_SPEED`; `velocity.y = 0` (no altitud, nunca
  negativo). Gravedad suprimida durante `DASH_TIME`; luego el control normal del estado
  continúa. El salto (buffered jump) sigue cancelando el dash terrestre y transicionando
  a JumpState.
- **ANIMACIÓN:** no existe sprite dedicado de dash en el set PixelLab (TASK-052). Durante
  el burst breve (0.16 s) se usa la animación de movimiento vigente (walk/idle). Gap
  documentado; un sprite de dash puede añadirse en el follow-up de TASK-053 si se desea.
- **Binding definitivo:** RB (botón 10, right shoulder) / Shift — véase corrección en DD-007.

---

## DD-006 — Matchup elemento vs. armadura (RPS de combate)  ·  **PROVISIONAL**

**Tensión:** El GDD §3 dice "mezclar Fuego/Hielo/Electricidad según el tipo de armadura
del enemigo", pero no define la tabla. Sin tabla no hay loop micro ni anti-dominancia.

**Regla (intuitiva y simétrica):** cada enemigo tiene un `armor_type` ∈ {Fuego, Hielo,
Electricidad}. Un dron **blindado en X resiste X** y es **débil a la contra de X**;
el tercer elemento es neutro. Ciclo de contras: **Electricidad → Fuego → Hielo →
Electricidad** (Fuego derrite blindaje de Hielo; Hielo congela sistemas Eléctricos;
Electricidad cortocircuita sistemas de Fuego).

| Armadura del dron | Resiste (×0.5) | Débil a (×1.5) | Neutro (×1.0) |
|---|---|---|---|
| **Fuego**         | Fuego          | Electricidad   | Hielo         |
| **Hielo**         | Hielo          | Fuego          | Electricidad  |
| **Electricidad**  | Electricidad   | Hielo          | Fuego         |

**Multiplicadores provisionales:** resiste 0.5×, débil 1.5×, neutro 1.0× — a afinar en
el playtest de greybox de DD-004. Ningún elemento es dominante contra todas las
armaduras → fuerza el intercambio (loop micro). Identidades de DD-004 intactas
(Fuego = burst objetivo único, Hielo = control/slow, Electricidad = cadena multi).

---

## DD-007 — Soporte de gamepad y layout de control  ·  **ACEPTADA (ajustable)**

**Decisión:** El juego se controla con **gamepad** (objetivo principal) y también con
teclado/mouse (additive — ambos activos a la vez). Layout estándar tipo Xbox:

| Acción | Gamepad | Teclado |
|---|---|---|
| Mover / vertical (vuelo) | Stick izq (analógico) + D-pad | A/D o ←/→ ; W/S o ↑/↓ |
| Salto | **A** (botón 0) | Espacio |
| Dash | ~~B (botón 1)~~ → **RB (botón 10)** | Shift |
| Planeo (mantener) | **LT** / gatillo izq (mantener) | Alt |
| Vuelo (toggle) | **Y** (botón 3) | F |
| Lanzar hechizo | **RT** / gatillo der | E / clic izq |
| Elemento directo (Fuego/Hielo/Elec) | **D-pad** ← / ↑ / → | 1 / 2 / 3 |
| Ciclar elemento | **RB** sig / **LB** ant (botones 5/4) | Q |

**Corrección TASK-054:** la fila "Dash" de esta tabla decía originalmente "B (botón 1)"
que es incorrecto. El binding real (confirmado en DD-008 y en el `InputMap` del proyecto)
es **RB = botón 10 (right shoulder) / Shift**. La tabla ahora refleja la corrección.

**Actualización TASK-055:** el dash ahora es **repeatable en todos los estados**
(`MoveState`, `JumpState`, `GlideState`, `FlightState`) mediante cooldown compartido.
Tuning revisado: DASH_SPEED=700 px/s, DASH_TIME=0.16 s, DASH_COOLDOWN=0.30 s (PROVISIONAL).
El dash aéreo está suprimido dentro de zonas anti-magia sin purgar (véase DD-005 y DD-011).

**Notas técnicas:** sticks con deadzone ~0.3; `Input.get_axis` da movimiento analógico
gratis. Gatillos = ejes 4 (LT) / 5 (RT) en Godot; planeo se mapea como *mantener*. El
casteo sigue siendo en la dirección de `facing` por ahora; **aim con stick derecho**
queda como mejora futura. Layout afinable en playtest.

> **Revisado por DD-008** — el layout de arriba (vuelo en Y, gatillos = planeo/cast,
> un solo cast, element_cycle) queda reemplazado por el esquema de DD-008.
> **Dash binding corregido por TASK-054:** B→RB (botón 10) en línea con DD-008 y el InputMap real.

---

## DD-008 — Esquema de control revisado (gamepad-first) + loadout de 2 elementos  ·  **ACEPTADA (ajustable)**

Reemplaza el layout de DD-007. Gamepad principal, teclado additive.

### Movimiento
- **Mover / vertical de vuelo:** stick izquierdo (analógico, deadzone 0.3). Teclado A/D, ←/→, W/S.
- **Salto:** A (botón 0) / Espacio.
- **Vuelo:** **doble salto** — el segundo salto en el aire entra a `FlightState`. **No hay
  botón dedicado de vuelo.** Sigue gateado por Electricidad (sin Electricidad no hay
  segundo salto / vuelo).
- **Salir del vuelo (TASK-062, endurecido en TASK-068):** dos formas. (a) Al **tocar
  piso** se cae a `MoveState`. (b) **Doble-tap DELIBERADO de Salto** estando en vuelo:
  dos pulsaciones *limpias* de Salto dentro de una ventana corta
  (`FlightState.DOUBLE_TAP_WINDOW`, **0.30 s**, constante ajustable) cortan el vuelo y
  **bajan a plataformeo**: se sale de `FlightState`, vuelve la gravedad y el héroe **cae**
  (mismo destino `MoveState` que la salida por aterrizaje — caída pura, sin nuevo impulso
  de salto). **Regresión TASK-068 ("ya no puede volar"):** el héroe **entra** al vuelo con
  un doble salto (dos pulsaciones rápidas de Salto en `JumpState`); esas pulsaciones de
  entrada —agravadas por el known-pitfall de Godot donde `Input.is_action_just_pressed()`
  leído en `_physics_process` puede quedar latched a `true` durante **varios frames de
  física** dentro de un mismo frame de render— se colaban en el detector de salida y
  tiraban al héroe a `MoveState` apenas comenzaba el vuelo. El detector ahora es **gracia
  de entrada + release-gated**:
  - **Gracia de entrada (`FlightState.ENTRY_GRACE`, 0.25 s, constante ajustable):** en
    `enter()` se arma un contador; mientras está activo se **ignoran** todos los flancos de
    Salto para salida (solo decrementa). El doble salto de entrada (y cualquier latch
    multi-frame) nunca puede cortar el vuelo.
  - **Release-gating:** se lee el estado mantenido vía `InputGate.pressed("jump")` y el
    detector se **arma** solo tras observar Salto **soltado** al menos una vez después de la
    gracia; cada tap cuenta únicamente como un flanco que **sigue a una soltada** (el botón
    estaba arriba el frame anterior). Una pulsación mantenida/latched **nunca** cuenta como
    dos taps.
  Un solo tap **no** corta el vuelo; si la ventana expira sin segundo tap limpio, el
  contador se reinicia (un tap posterior empieza de cero). Lectura del flanco y del estado
  mantenido por la costura `InputGate` (determinista en tests, TASK-024/068). **Seguridad de
  gating:** soltar el vuelo solo puede **quitar** vuelo, nunca otorgar travesía — no abre
  ningún gate (zona anti-magia / gate de FUEGO / hueco de vuelo de 98 px del jefe); como
  mucho hace la travesía más difícil.
- **Planeo (Hielo):** **mantener LB** (botón 9, left shoulder) / Alt. Gateado por Hielo.
- **Dash:** **RB** (botón 10, right shoulder) / Shift. Gateado por Fuego.

### Magia — loadout de 2 elementos (primario + secundario)
- **Slots:** PRIMARIO y SECUNDARIO, cada uno con un elemento.
- **Asignar (X/Y/B / teclas 1/2/3):** X = Fuego, Y = Hielo, B = Electricidad. Al apretar
  un elemento, **pasa a PRIMARIO** y el que estaba en primario **baja a SECUNDARIO**
  (stack de los últimos dos elementos distintos; apretar el ya-primario no hace nada).
  Esto produce las "combinaciones de poderes".
- **Disparo PRIMARIO:** **RT** (eje 5) / E / clic izquierdo — lanza el elemento del slot primario.
- **Disparo SECUNDARIO:** **LT** (eje 4) / Q / clic derecho — lanza el elemento del slot secundario.

### Tabla resumen

| Acción | Gamepad | Teclado |
|---|---|---|
| Mover / vertical | Stick izq | A/D, ←/→, W/S |
| Salto / (doble = vuelo / doble-tap en vuelo = bajar a plataformeo) | A | Espacio |
| Planeo (mantener) | LB | Alt |
| Dash | RB | Shift |
| Asignar Fuego/Hielo/Elec | X / Y / B | 1 / 2 / 3 |
| Disparo primario | RT | E / clic izq |
| Disparo secundario | LT | Q / clic der |

Índices Godot 4 verificados: A=0, B=1, X=2, Y=3, LB=9, RB=10, gatillos eje 4/5.

---

## DD-009 — IA básica del dron, slow de Hielo real, y daño al jugador  ·  **PROVISIONAL**

Da vida al dron del Imperio (hoy un blanco estático) y cierra el loop micro en ambas
direcciones. Valores provisionales, a afinar en playtest.

### IA del dron (FSM por nodos, como el movimiento del héroe)
- **Patrol:** sin objetivo a la vista, va y viene (hover) en un rango corto alrededor
  de su punto de spawn.
- **Chase:** si el jugador entra en el **rango de aggro** (~280 px), se mueve hacia él
  (dron flotante; sin gravedad).
- **Attack:** en rango de ataque + cooldown listo → **telegrafía** (wind-up ~0.4s, flash
  de color) y dispara un **proyectil enemigo** hacia el jugador. Cooldown ~1.5s. El
  telegraph es obligatorio (juego justo, DD-001): el jugador siempre puede reaccionar.
- Proyectil enemigo: capa propia **EnemyAttack (layer 5)** que enmascara **Player (2)**;
  más lento que el del jugador (legible/esquivable).

### Slow de Hielo (hace real el flag `applies_slow` de DD-004)
- Un impacto de **Hielo** aplica **SLOWED**: velocidad de movimiento y cadencia de
  ataque al **50%** por **~2.5s**, refrescable al re-pegar, con decaimiento. Señal visual
  clara (tinte azulado + etiqueta). Esto es la identidad de **control** de Hielo.

### Daño al jugador (consecuencia + justicia)
- El jugador gana **Health** (ej. 100). El proyectil enemigo le quita vida.
- Al recibir daño: **i-frames** breves (~0.8s) con parpadeo; sin stun que quite control.
- **Muerte → respawn** en el punto de inicio con vida llena (demo; sin penalización dura).
  Determinista y justo (DD-001). El HUD muestra la **vida del jugador**.

---

## DD-010 — Primer mini-jefe mecánico: "El Carcelero" (Warden)  ·  **PROVISIONAL**

Primer jefe del loop minuto-a-minuto. Una construcción grande del Imperio en una arena
cerrada. Es la prueba que obliga a usar TODO el kit. Valores a afinar en playtest.

### Estructura por fases (obliga a leer armadura y cambiar de elemento)
La armadura del jefe **rota por fase**, forzando el intercambio del loadout (DD-008) y
respetando el RPS (DD-006). HP alta (~300), umbrales a 66% y 33%:
- **Fase 1 (100–66% HP):** armadura **Fuego** → débil a Electricidad. Patrón: disparos
  apuntados pesados (como el dron pero más daño/lentos), telegrafiados.
- **Fase 2 (66–33% HP):** armadura **Hielo** → débil a Fuego. Patrón: **volea en abanico**
  (3 proyectiles), telegrafiada.
- **Fase 3 (33–0% HP):** armadura **Electricidad** → débil a Hielo. Patrón: más rápido +
  un **barrido**; el Hielo además lo ralentiza (DD-009) dándole ventana al jugador.
- Cada cambio de fase: gran **hit-stop + shake** (juice) y re-telegrafía claramente la
  nueva armadura (color). Todo telegrafiado (justo, DD-001).

### Arena y victoria
- Escena `levels/arena.tscn`: sala cerrada (paredes Environment), jugador, el Warden, HUD
  con **barra de HP del jefe** + fase actual. Reusa FSM de IA, proyectil enemigo, Health,
  matchup, slow y juice ya existentes.
- **Derrota del jefe a 0 HP → estado de victoria** (freeze + label). Muerte del jugador →
  respawn en la arena (DD-009).
- La arena queda como escena principal del demo; `test_level.tscn` sigue disponible como
  sandbox de movimiento/combate.

---

## DD-011 — Reconciliación: vuelo inicial vs. gate metroidvania (modelo de gate del slice)  ·  **ACEPTADA**

**Tensión:** El GDD §2–3 ata la evolución de movilidad (salto → planeo → vuelo) a absorber
elementos, con el **vuelo como la última mejora a desbloquear**. Pero el build actual
(DD-008) ya entrega **vuelo desde el inicio** (doble salto → `FlightState`). Si el jugador
ya vuela, **no se puede gatear una ruta detrás de "desbloquear volar"** — el verbo macro
del GDD ya está en manos del jugador.

**Decisión:** En el vertical slice (Milestone **M1**) el héroe **arranca con el vuelo ya
disponible** (estado post-fuga; el "despertar del vuelo" del GDD se trata como ya ocurrido
en la ficción del slice). La progresión que **abre rutas** es la **maestría elemental
aplicada al entorno**, no re-adquirir movilidad. El gate del slice es **HÍBRIDO**, con dos
mecanismos complementarios:

- **Gate elemental sobre el entorno:** una ruta intransitable hasta **absorber/equipar un
  elemento y aplicarlo al entorno** — congelar un géiser/refrigerante con **Hielo** para
  formar plataforma, quemar una obstrucción con **Fuego**, o energizar un ascensor/puente
  muerto con **Electricidad**. Mantiene intacto "absorber elemento → abre ruta" (GDD §2
  macro). Codificación visual por color según **DD-003**.
- **Zona anti-magia que anula el vuelo:** un sector con **campo amortiguador tecno-mágico**
  del Imperio donde el `FlightState` queda **deshabilitado**; el jugador debe **purgar /
  restaurar** el campo con el elemento correcto para recuperar el vuelo y cruzar.
  Reintroduce un gate de movilidad **coherente con el lore** (la prisión está diseñada para
  contener al arma) sin contradecir que el vuelo ya existe.

**Coherencia con canon:** el Imperio es una cuarentena tecno-mágica (pilar "el carcelero
era el protector"); que la prisión tenga **campos anti-vuelo** y **rutas selladas por
energía elemental** es consistente. **Provisional** en números y ubicación exacta (a afinar
en playtest/greybox); el **modelo de gate** queda **ACEPTADO** como base de M1.

---

## DD-012 — Asistencia de apuntado suave (aim magnetism)  ·  **ACEPTADA (ajustable)**

**Tensión / origen:** feedback de playtest — apuntar a enemigos con el twin-stick (vector
`_aim`, `reticle.gd`) se siente trabajoso. El jugador pidió "lock-on al acercarse a un
enemigo, para que sea más sencillo". Pero DD-001 exige dificultad **justa y determinista,
sin ayuda oculta** — un lock-on que "tome el control" o teledirija mágicamente choca con
ese tono.

**Decisión:** **asistencia suave por magnetismo**, NO lock-on duro. El jugador conserva
control manual total; la asistencia solo **sesga** el apuntado hacia un enemigo que el
jugador ya está casi apuntando:

- Al computar el aim de casteo, si el enemigo más cercano cae **dentro de un cono angular**
  (provisional ±~20°) del aim crudo **y** dentro de un **rango** (provisional ~400 px),
  el aim se **rota hacia ese enemigo** por una cantidad **acotada** (snap completo dentro
  de un cono interno más chico, ~8°; lerp parcial entre el cono interno y el externo). Fuera
  del cono externo **no asiste** — apuntar deliberadamente a otro lado se respeta.
- **Legibilidad (DD-001):** el **reticle refleja** la dirección asistida (el jugador ve a
  dónde irá el disparo) y el enemigo asistido recibe una marca sutil. La asistencia es una
  **función pura y determinista** de posiciones + aim: sin RNG, sin rubber-banding, sin
  acumuladores ocultos. El jugador siempre entiende por qué el disparo fue ahí.
- **Alcance:** afecta el `_aim` que usan `cast_primary`/`cast_secondary`. Aplica a ambos
  métodos de input; se siente más en gamepad (el mouse ya es preciso). Sin botón nuevo ni
  estado de "target fijado" (eso sería el lock-on duro, descartado).

**Provisional** en números (cono, rango, fuerza del snap) — a afinar en playtest. El
**modelo** (magnetismo suave, legible, determinista) queda **ACEPTADO**.

---

## DD-013 — Dual-cast: mezcla/combo de elementos (TASK-040, M2.1)  ·  **PROVISIONAL**

**Origen:** decisión del usuario. Pulsar **AMBOS gatillos a la vez** dispara **UN solo
proyectil COMBO mezclado** (no dos disparos independientes) que combina los dos
elementos equipados. Es un pequeño ensayo de la fantasía de antimateria ("todos los
elementos a la vez") pero **NO es el ultimate** (ese es DD-002) y **NO está por encima
del RPS de armaduras** (DD-006). Sirve al loop micro: añade una decisión táctica
deliberada sin matar el swap Fuego/Hielo/Electricidad.

### Tabla de combos (Fuego/Hielo/Electricidad; ANTIMATERIA excluida)
La mezcla es **CONMUTATIVA** (Fuego+Hielo == Hielo+Fuego) y **determinista** (DD-001):

| Par | Combo | Identidad | Color (lectura) |
|---|---|---|---|
| **Fuego + Hielo** | **STEAM / Choque Térmico** | ráfaga pesada a un objetivo (el "shatter" Hielo→Fuego), bonus vs. ralentizados/congelados | blanco incandescente |
| **Fuego + Electricidad** | **PLASMA / Sobrecarga** | arco explosivo con pequeña AoE | violeta/magenta |
| **Hielo + Electricidad** | **FROST-ARC / Superconductor** | cadena fría que ralentiza varios objetivos (cadena de Elec + slow de Hielo) | cian-blanco |
| **Mismo elemento en ambos slots** | (sin combo) | **disparo ÚNICO POTENCIADO** de ese elemento (~1.5x), NO dos proyectiles idénticos | el del elemento |
| **ANTIMATERIA en cualquier slot** | (sin combo) | cae a disparo simple normal | — |

### Anti-dominancia (CRÍTICO — el revisor lo verifica con la skill de game-design)
El combo **NO** debe volverse lo único que hace el jugador (no debe matar el micro-loop
de swap RPS). Coste real, así spamear combos es caro en maná **y** en tiempo, y NUNCA es
más eficiente que swapear bien (elección táctica por **flexibilidad**, no botón de
victoria). **Cuatro** palancas, todas **provisionales/tunables**:

- **Ventana de doble gatillo:** ambos gatillos deben estar activos dentro de una ventana
  corta (`COMBO_WINDOW ≈ 0.12s`). Un segundo gatillo tardío se trata como dos disparos
  simples deliberados, no como combo.
- **Maná de ambos:** cada combo consume la **suma** del coste de los dos elementos
  (`combo_mana_cost()` = coste_primario + coste_secundario). Todo-o-nada: si no alcanza
  el maná combinado, no dispara y no gasta nada. Siempre cuesta **estrictamente más** que
  un disparo simple.
- **Cadencia más lenta:** el combo dispara con una cadencia **más lenta** que cualquiera
  de los dos intervalos simples — `combo_interval = max(intervalo_a, intervalo_b) ×
  COMBO_CADENCE_PREMIUM (1.6)`. Construido sobre los acumuladores por slot de TASK-038,
  con un **tercer** acumulador de combo independiente.
- **Combo-mode = intercambio, no suma (MEDIUM):** mientras AMBOS gatillos estén pulsados
  el jugador entra en **modo combo** y NO recibe además los disparos simples intermedios
  a cadencia rápida (el manager devuelve `suppress_singles=true` cada frame; el jugador
  silencia los dos simples). Sostener ambos **cambia** fuego simple rápido por el ritmo de
  combo lento y flexible — no se obtienen las dos cosas. (Coherente con "no te quedas sin
  hacer nada": sigues actuando, disparando combos, solo más lento.)

**Los combos RESPETAN la armadura (DENTRO del RPS, NO por encima — HIGH-1).** Un combo no
es una entrada propia en la tabla DD-006: resuelve su multiplicador de armadura **a través
de sus dos elementos base** (los constituyentes que lo formaron), usando la **MEDIA** de
los dos multiplicadores base (`ElementMatchup.multiplier` → `combo_components` pura,
determinista, conmutativa). La media (no el máximo) garantiza que un combo **nunca** supera
el x1.5 de un simple perfectamente correcto. Multiplicador derivado por combo×armadura:

| Combo (bases) | vs armadura Fuego | vs armadura Hielo | vs armadura Elec |
|---|---|---|---|
| **STEAM** (Fuego+Hielo) | 0.75 | 1.00 | 1.25 |
| **PLASMA** (Fuego+Elec) | 1.00 | 1.25 | 0.75 |
| **FROST-ARC** (Hielo+Elec) | 1.25 | 0.75 | 1.00 |

**Invariante dmg-por-maná (anti-dominancia dura, test `test_combo_anti_dominance.gd`):**
para CADA armadura, el mejor simple correcto (el jugador swapea óptimo) tiene dmg/maná
**>=** el mejor combo. Mejores simples por armadura: Fuego **1.8** (Rayo), Hielo **3.0**
(Fuego), Elec **2.25** (Hielo). Peor caso de cada combo: STEAM vs Elec
46·1.25/27 = **2.13** <= 2.25; PLASMA vs Hielo 42·1.25/25 = **2.10** <= 3.0; FROST-ARC vs
Fuego 28·1.25/22 = **1.59** <= 1.8. → Ningún combo gana en eficiencia a swapear bien contra
ninguna armadura; el combo gana en **utilidad/flexibilidad** (AoE, cadena+slow, ráfaga, no
tener que leer la armadura), nunca en dmg/maná crudo. La antimateria (DD-002) queda
**excluida** de la mezcla y es la ÚNICA que está por encima del RPS.

### Disparo POTENCIADO de mismo elemento (HIGH-2)
Mismo elemento en ambos slots + ambos gatillos NO dispara dos proyectiles idénticos: dispara
**UN solo disparo potenciado** de ese elemento con daño ×`EMPOWERED_MULTIPLIER (1.5)` (vía
`SpellData.duplicate()`, sin mutar el `.tres` origen) y **suprime el segundo simple**. Paga
el **coste de ambos manás** y va en la **misma cadencia de combo lenta**, así que mashear el
mismo elemento NO es un doblador de DPS gratis ni out-ratea el fuego simple normal. Sigue
DENTRO del RPS (es el multiplicador base del propio elemento).

### Mapeo (función pura) y datos
- `ComboTable.combo_for(element_a, element_b) -> ComboResult` es **pura, estática y
  determinista** (espejo de `AimAssist`): sin RNG, sin lookups de nodos, sin estado
  oculto. Devuelve `KIND_COMBO` (con el `SpellData` mezclado), `KIND_EMPOWERED`
  (mismo elemento → simple potenciado) o `KIND_NONE` (antimateria/no-mezcla → simple).
  Clave conmutativa `(min,max)`.
- **Data-driven** (NO scripts por combo): tres `SpellData .tres` reusando el sistema
  existente de `ShotType`/proyectil/`ProjectileStyle`:
  `resources/spells/combo_steam.tres` (STEAM, SINGLE, ráfaga),
  `combo_plasma.tres` (PLASMA, PIERCE/AoE), `combo_frostarc.tres` (FROSTARC, CHAIN +
  `applies_slow`). Tres elementos nuevos en `SpellData.Element` (STEAM/PLASMA/FROSTARC)
  para que el pipeline por-elemento (color/forma/escala) fluya sin código bespoke.
- El proyectil combo spawnea por el **mismo pool** (TASK-037) y lleva el
  elemento/shot_type/efecto del combo + su color en `ProjectileStyle`.

### Números provisionales (tunables en playtest)
- **Re-tuneados para cumplir la invariante dmg/maná (HIGH-1):** STEAM daño **46**, coste
  .tres 27 (= Fuego 15 + Hielo 12), SINGLE, ráfaga. PLASMA daño **42**, AoE max_targets 3,
  coste 25 (= Fuego 15 + Rayo 10). FROST-ARC daño **28**, cadena 4, `applies_slow`, coste
  **22** (= Hielo 12 + Rayo 10).
- En juego el coste real del combo es la **suma de los dos slots equipados**
  (`combo_mana_cost`), y la cadencia real es `combo_interval` (más lenta que ambos). El
  daño se escala en el impacto por el multiplicador **derivado de los dos elementos base**
  (media), así que el combo está sujeto a resist/weakness como cualquier elemento.
  `COMBO_WINDOW = 0.12s`, `COMBO_CADENCE_PREMIUM = 1.6`, `EMPOWERED_MULTIPLIER = 1.5`.

### Feature-vetting checklist (re-ejecutable por el revisor)

```
FEATURE: Dual-cast element mixing / combo (DD-013)
ONE-LINE: Hold BOTH triggers -> COMBO MODE: ONE blended combo projectile (Fire/Ice/Elec)
          at a slower cadence + summed mana, in-between singles suppressed (trade, not
          add); same element -> ONE 1.5x empowered shot. Combos RESPECT armor (mean of
          their two base elements) so they are inside the RPS, never above it.

--- GATE A: PILLARS (need >=1 "serves") ---
[x] Jailer-was-protector  : neutral — note: no toca la ficción del Imperio.
[x] Weapon-chooses-target : serves — note: mezclar elementos es un pequeño ENSAYO de la
    fantasía antimateria ("todos los elementos a la vez"), la dualidad creación/
    destrucción del arma; deliberadamente por debajo del ultimate (DD-002).
[x] Flight=freedom&doom   : neutral — note: es combate, no toca el vuelo ni los gates.
    >> 1 "serves", 0 "VIOLATES" => PASS.

--- GATE B: CORE-LOOP LAYER (need >=1, steals from none) ---
[x] Micro  : serves, steals from NONE — note: añade una decisión táctica segundo-a-segundo
    (¿entro en modo combo por flexibilidad, o sigo swapeando al elemento correcto?). NO
    roba el swap RPS porque: (1) los combos RESPETAN la armadura — su multiplicador es la
    MEDIA de sus dos elementos base (tabla: STEAM 0.75/1.00/1.25, PLASMA 1.00/1.25/0.75,
    FROST-ARC 1.25/0.75/1.00), así que están sujetos a resist/weakness; (2) invariante
    dmg/maná verificada (test_combo_anti_dominance.gd): para CADA armadura el mejor simple
    correcto >= el mejor combo (STEAM 2.13<=2.25, PLASMA 2.10<=3.0, FROST-ARC 1.59<=1.8),
    o sea swapear bien NUNCA es peor que mashear; (3) modo combo SUPRIME los simples
    intermedios (intercambio, no suma) + ventana + maná sumado + cadencia lenta.
[x] Minute : serves — note: herramienta extra por UTILIDAD para limpiar grupos/mini-jefes
    (FROST-ARC cadena+slow; PLASMA AoE; STEAM ráfaga), elegida por flexibilidad, no por
    eficiencia — no se vuelve dominante.
[x] Macro  : n/a — note: no cambia progresión permanente ni mapa.
    >> 2 "serves", 0 "steals" => PASS (anti-dominancia verificada por la invariante dmg/maná).

--- GATE C: CANON CONSISTENCY (need "consistent") ---
[x] Contradicts GDD?         : no — GDD §3 invita a mezcla/combos "Ice-then-Fire shatter".
[x] Contradicts LORE-BIBLE?  : no — la antimateria/ultimate sigue siendo el clímax aparte.
[x] Tone severe/tragic/cosmic: yes — el combo es contenido, costoso y deliberado; no es
    quippy ni un botón de victoria. La fantasía total/fatal se reserva al Sacrificio.
    >> Sin contradicciones, tono OK => PASS.

--- GATE D: TEACHES / REWARDS A VERB (need "yes") ---
[x] Which verb/element: recompensa el SWAP elemental (la mezcla premia conocer los dos
    slots equipados y leer la armadura — el combo mismo está sujeto al RPS) y ENSAYA la
    fantasía antimateria.
[x] If it gates traversal: n/a (no es un gate de traversía).
[x] If combat: preserve the RPS read (no dominant element)? : yes — los combos están DENTRO
    del RPS, NO por encima (solo la antimateria/DD-002 está por encima). Cada combo resuelve
    su daño a través de sus DOS elementos base (MEDIA de multiplicadores), así que es
    resistido/bonificado como cualquier elemento (ver tabla por armadura). Además cuesta la
    suma de ambos manás, dispara en cadencia más lenta, y en modo combo suprime los simples
    intermedios. Invariante verificada: ningún combo gana al mejor simple correcto en
    dmg/maná contra ninguna armadura (STEAM 2.13<=2.25, PLASMA 2.10<=3.0, FROST-ARC
    1.59<=1.8). El mismo-elemento es UN disparo potenciado 1.5x (no dos), también dentro del
    RPS y con el mismo coste/cadencia. Swapear bien nunca es peor que comboear.
    >> PASS.

--- IMPLEMENTATION HANDOFF (godot-game-dev) ---
[x] Maps to: SpellData element (STEAM/PLASMA/FROSTARC) + ShotType + ProjectilePool +
    ProjectileStyle; cadencia/maná en MagicManager; detección dual en player.gd.
[x] Data-driven where possible (.tres, not bespoke script)? : yes — 3 combo .tres +
    ComboTable puro; cero scripts por-combo.
[x] Test plan (GUT pure-logic): mapeo conmutativo/determinista, una sola bala combo (no
    dos simples), coste de ambos manás, cadencia más lenta, color/efecto del combo,
    multiplicador combo = media de bases (test_combo_matchup), invariante dmg/maná
    (test_combo_anti_dominance: mejor simple >= mejor combo por armadura), disparo
    potenciado mismo-elemento (1 disparo 1.5x, taxado, cadencia combo), modo-combo
    suprime simples intermedios, no-regresión del disparo simple (TASK-038). Held-axis +
    InputGate hygiene. SUITE COMPLETA GREEN 631/631 (×2).

VERDICT: SHIP — reason: sirve micro (sin robar el swap) + minuto, no contradice canon,
tono severo. La anti-dominancia ahora es REAL y VERIFICADA: los combos respetan la armadura
(media de sus dos bases, dentro del RPS) y la invariante dmg/maná garantiza que swapear bien
nunca es peor que comboear; el mismo-elemento es un disparo potenciado (no dos); el modo
combo intercambia fuego simple por el ritmo de combo (no suma). Números PROVISIONALES.
```

**Estado:** **PROVISIONAL** en números; el **modelo** (dual-cast → un combo mezclado o
disparo potenciado; mapeo puro conmutativo; combos DENTRO del RPS vía media de sus
elementos base; anti-dominancia por ventana + maná sumado + cadencia lenta + modo-combo que
intercambia simples + invariante dmg/maná verificada; antimateria excluida y única por
encima del RPS) queda como base de M2.1.

---

## DD-014 — Modo shoot-em-up de auto-scroll (TASK-064/065)  ·  **ACEPTADA (números provisionales)**

**Origen:** decisión del usuario — "un nuevo modo shmup AL LADO" de los sectores. Un nivel
de **shoot-em-up horizontal rápido** como **modo aparte y aditivo**, alcanzable desde el
selector de niveles (TASK-063). Los sectores `sector_01/02` quedan **exactamente como están**:
esto NO toca su FlightState/Player/combate. TASK-064 es el paraguas; **TASK-065 construye
sólo la FUNDACIÓN** (cámara + clamp + concesión de vuelo + esqueleto de nivel). El
**streaming de enemigos** (TASK-066) y la **condición de victoria/derrota + tuning**
(TASK-067) son tickets POSTERIORES y NO entran aquí.

**Decisión (modelo del modo):**

- **Nivel separado** `levels/shmup_01.tscn` (no un modo dentro de un sector), con su propio
  controlador `Shmup01`. Greybox primero (colisión = gameplay real): un carril de vuelo con
  suelo + techo + muro izquierdo como límites deliberados.
- **Auto-scroll** (la restricción clásica del shmup, recomendada y confirmada): una cámara
  `ShmupScroller` (subclase de `Camera2D`) avanza a la **derecha a velocidad constante**
  `SCROLL_SPEED` cada tick de física. El mundo pasa; el héroe NO impulsa el scroll. La cámara
  arranca **centrada en el spawn** y se hace `current` (sustituye a la cámara montada en el
  player de los sectores, que NO se toca).
- **Héroe SIEMPRE volando.** El vuelo es central en el shmup. El controlador, en `_ready`,
  **pre-concede** la habilidad de vuelo (`electricity` en `abilities`) y mete al héroe en
  `FlightState` desde el frame uno (FlightState no aplica gravedad → **gravedad off**).
- **El héroe queda CLAMPEADO al rect visible de la cámara** cada frame de física (el clamp
  vive en el controlador del nivel): puede maniobrar DENTRO del cuadro pero no salir; al
  avanzar la cámara, lo **arrastra hacia la derecha**. El rect se deriva del tamaño del
  viewport / zoom (NO números mágicos). `SCROLL_SPEED (180 px/s)` se fija **por debajo** de
  `FlightState.FLY_SPEED (260)` para que el jugador conserve autoridad de maniobra dentro del
  cuadro en vez de quedar pegado a la pared derecha.
- **Salir del vuelo está DESHABILITADO en el shmup, vía flag por-nivel.** Caer del vuelo =
  caer fuera de pantalla = muerte accidental. La salida por **doble-tap de JUMP** (TASK-062)
  Y la salida por **aterrizaje** (`is_on_floor`) de `FlightState` se **suprimen** cuando
  `Player.shmup_mode` está activo. El flag **default es FALSE**, lo pone SÓLO el controlador
  del shmup en `_ready`, y `FlightState` lo lee de forma defensiva: con el flag en false TODA
  transición de los sectores (enter/doble-tap/suppression DD-011/aterrizaje) es
  **byte-idéntica** (verificado por tests). El scoping por-nivel es el punto central: el modo
  shmup NO altera ningún default de Player/FlightState/combate de los sectores.
- **Victoria/derrota (INTENCIÓN, se implementa en TASK-067):** **Victoria = llegar al final
  del scroll** (recorrer el carril); **Derrota = respawn** (caer fuera/morir reaparece en el
  spawn registrado, DD-009). No se construye en TASK-065, sólo se documenta aquí.

**Coherencia con canon:** el shmup encaja en el pilar **"vuelo = libertad y condena"** — es
el clímax del verbo de vuelo llevado a un carril aéreo abierto donde el mundo corre hacia ti.
Reutiliza al Player, el vuelo y los sistemas de proyectil/combate M2.1 existentes (TASK-066
los hará streamear). El Imperio sigue siendo cuarentena, no maldad caricaturesca (pilar 1).

**Números provisionales (tunables, TASK-067):** `ShmupScroller.SCROLL_SPEED = 180 px/s`;
métricas del carril greybox (suelo y=+328 / techo y=-288, espejo de la banda flight-safe de
los sectores); el flag `Player.shmup_mode` (default FALSE). La velocidad de vuelo, cadencia
de disparo, longitud del carril y la condición de victoria se afinan en TASK-067.

### Actualización TASK-067 — tuning (velocidad/cadencia) + bucle victoria/derrota

**Tuning por-nivel vía seams SCOPED que default al no-op (sectores byte-idénticos):** el
shmup se siente más rápido que los sectores SIN tocar ningún default compartido. Dos seams,
ambos default `1.0`:

- **Velocidad de vuelo — `Player.fly_speed_scale` (default 1.0).** `FlightState` calcula la
  velocidad de vuelo libre como `input * FLY_SPEED * fly_speed_scale`. La const compartida
  `FlightState.FLY_SPEED` (260) NO se cambia; es un multiplicador por-player leído de forma
  defensiva (`"fly_speed_scale" in player`). El controlador del shmup lo fija en
  `Shmup01.FLY_SPEED_SCALE = 1.6` en `_ready`. Con el default 1.0 el vuelo de los sectores es
  byte-idéntico (verificado por test).
- **Cadencia de disparo — `MagicManager.cadence_scale` (default 1.0).** TODO intervalo
  hold-to-fire (el `fire_interval` por-elemento de cada slot Y el intervalo de combo) se
  multiplica por `cadence_scale` en tiempo de LECTURA — NUNCA muta el dato compartido
  `SpellData.fire_interval`. `< 1.0` => intervalos más cortos => disparo más rápido. El shmup
  lo fija en `Shmup01.FIRE_CADENCE_SCALE = 0.6`. Con el default 1.0 la cadencia M2.1
  (Fire 0.18 / Elec 0.28 / Ice 0.40) es byte-idéntica.

**Victoria = recorrer el carril.** `Shmup01.LEVEL_LENGTH` (6400 px, ~36s a 180 px/s) es la
distancia de meta medida desde la x de la cámara capturada en `_ready` (`progress()` =
`scroller.x - _start_x`). Cuando `check_progress()` (llamada cada frame de física, y
directamente por el test) ve `progress() >= LEVEL_LENGTH`, latcha el estado de victoria y
emite `shmup_victory` UNA sola vez — espejo de `sector_02.sector_victory`.

**Derrota = HP a 0 -> respawn en el inicio (DD-009).** La muerte usa el camino existente:
`Player.take_player_damage` lleva el HP a 0, la salud emite `died` y `Player.respawn()`
devuelve al héroe al spawn registrado (el inicio del nivel). `Shmup01` escucha el `died` de
la salud para emitir `shmup_defeat` (feedback breve de reintento); el bucle continúa (el héroe
revive en el inicio). No hay penalización dura — es demo/greybox.

**HUD mínimo (`ShmupBanner`, espejo del label de victoria de `boss_hud`):** dos Labels (VICTORY
terminal + DOWNED—RETRY breve auto-ocultable) que arrancan ocultos y se muestran por las señales
`shmup_victory` / `shmup_defeat` (desacoplado: el controlador emite, el banner muestra). Greybox.

**Fold de revisión TASK-066:** la detección de drone muerto en `ShmupSpawner` ahora consulta el
hijo `Health` (`get_node_or_null("Health").is_dead()`) — el `is_dead()` a nivel raíz era código
muerto para drones reales (la salud vive en el hijo, no en el `CharacterBody2D` raíz). Se
mantiene el fallback a un `is_dead()` raíz para fakes duck-typed. Test añadido con un fake con
forma de drone real (sin `is_dead()` raíz; hijo `Health` que reporta muerto).

### Feature-vetting checklist (re-ejecutable por el revisor)

```
FEATURE: Auto-scroll shoot-em-up mode — FOUNDATION (DD-014 / TASK-065)
ONE-LINE: A SEPARATE level with a constant-rightward auto-scroll camera; the hero is ALWAYS
          flying (flight pre-granted, gravity off) and clamped into the visible frame, the
          world scrolling past. Stop-flight (double-tap + landing) is disabled here via a
          per-level flag that defaults OFF (sectors byte-identical).

--- GATE A: PILLARS (need >=1 "serves") ---
[x] Jailer-was-protector  : neutral — note: no toca la ficción del Imperio (greybox aún).
[x] Weapon-chooses-target : neutral — note: reutiliza el combate existente; sin cambios.
[x] Flight=freedom&doom   : serves — note: el shmup ES el verbo de vuelo llevado al carril
    aéreo abierto donde el mundo corre hacia ti; "libertad y condena" hecho modo.
    >> 1 "serves", 0 "VIOLATES" => PASS.

--- GATE B: CORE-LOOP LAYER (need >=1, steals from none) ---
[x] Micro  : serves, steals from NONE — note: maniobra dentro del cuadro (esquivar/posicionar)
    segundo-a-segundo; el clamp + SCROLL_SPEED < FLY_SPEED preservan la autoridad del jugador.
    No roba el swap RPS (el combate no cambia).
[x] Minute : serves — note: recorrer el carril hasta el final es la meta de tamaño-minuto
    (la victoria llega en TASK-067; la fundación ya entrega el carril y el avance).
[x] Macro  : n/a — note: modo aparte aditivo; no cambia la progresión metroidvania.
    >> 1+ "serves", 0 "steals" => PASS.

--- GATE C: CANON CONSISTENCY (need "consistent") ---
[x] Contradicts GDD?         : no — un modo de vuelo rápido es coherente con "el juego se
    vuelve un side-scroller aéreo" al dominar Electricidad (skill game-design, tabla de verbos).
[x] Contradicts LORE-BIBLE?  : no — reutiliza vuelo/combate; sin nuevas afirmaciones de canon.
[x] Tone severe/tragic/cosmic: yes — severo: salir del vuelo = caer fuera = muerte; nada quippy.
    >> Sin contradicciones, tono OK => PASS.

--- GATE D: TEACHES / REWARDS A VERB (need "yes") ---
[x] Which verb/element: recompensa el VUELO (FlightState) como verbo central del modo.
[x] If it gates traversal: n/a — no es un gate metroidvania; es un modo aparte.
[x] If combat: preserve the RPS read? : n/a en TASK-065 (combate sin cambios; enemigos en 066).
    >> PASS.

--- IMPLEMENTATION HANDOFF (godot-game-dev) ---
[x] Maps to: Camera2D (ShmupScroller) + FSM FlightState (scoping por flag) + collision
    Environment layer (greybox bounds) + level controller (clamp); selector LEVEL_ENTRIES.
[x] Data-driven where possible? : el modelo es escena + controlador delgado; SCROLL_SPEED y el
    flag son constantes/vars nombradas y tunables.
[x] Test plan (GUT, determinista, headless): advance(delta) mueve x por SCROLL_SPEED*delta
    (sin frames reales); visible_world_rect derivado de viewport/zoom; clamp por cada borde;
    FlightState flag OFF byte-idéntico / ON sin salida; shmup_01 carga limpio + spawn + grant
    + flag + start-in-FlightState + cámara current + clamp; selector lista 3, guard de path.
    SUITE COMPLETA GREEN + CRUCIAL ×2.

VERDICT: SHIP — reason: sirve micro+minuto y el pilar de vuelo, no contradice canon, tono
severo. El scoping por-nivel (flag default OFF) garantiza que los sectores son byte-idénticos.
Sólo FUNDACIÓN; enemigos (066) y victoria/derrota + tuning (067) son tickets aparte. Números
PROVISIONALES.
```

**Estado:** **ACEPTADA** el **modelo** (nivel separado de auto-scroll; héroe siempre volando
con vuelo pre-concedido + gravedad off; clamp al rect visible; stop-flight deshabilitado por
flag por-nivel con default FALSE → sectores byte-idénticos; victoria = fin del scroll /
derrota = respawn como intención). **PROVISIONALES** los números (SCROLL_SPEED, métricas del
carril, tuning de vuelo/cadencia) y los tickets de enemigos/victoria-derrota (TASK-066/067).
