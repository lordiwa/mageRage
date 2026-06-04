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
| Dash | **B** (botón 1) | Shift |
| Planeo (mantener) | **LT** / gatillo izq (mantener) | Alt |
| Vuelo (toggle) | **Y** (botón 3) | F |
| Lanzar hechizo | **RT** / gatillo der | E / clic izq |
| Elemento directo (Fuego/Hielo/Elec) | **D-pad** ← / ↑ / → | 1 / 2 / 3 |
| Ciclar elemento | **RB** sig / **LB** ant (botones 5/4) | Q |

**Notas técnicas:** sticks con deadzone ~0.3; `Input.get_axis` da movimiento analógico
gratis. Gatillos = ejes 4 (LT) / 5 (RT) en Godot; planeo se mapea como *mantener*. El
casteo sigue siendo en la dirección de `facing` por ahora; **aim con stick derecho**
queda como mejora futura. Layout afinable en playtest.

> **Revisado por DD-008** — el layout de arriba (vuelo en Y, gatillos = planeo/cast,
> un solo cast, element_cycle) queda reemplazado por el esquema de DD-008.

---

## DD-008 — Esquema de control revisado (gamepad-first) + loadout de 2 elementos  ·  **ACEPTADA (ajustable)**

Reemplaza el layout de DD-007. Gamepad principal, teclado additive.

### Movimiento
- **Mover / vertical de vuelo:** stick izquierdo (analógico, deadzone 0.3). Teclado A/D, ←/→, W/S.
- **Salto:** A (botón 0) / Espacio.
- **Vuelo:** **doble salto** — el segundo salto en el aire entra a `FlightState`. **No hay
  botón dedicado de vuelo.** Sigue gateado por Electricidad (sin Electricidad no hay
  segundo salto / vuelo). Se sale del vuelo al tocar piso.
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
| Salto / (doble = vuelo) | A | Espacio |
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
