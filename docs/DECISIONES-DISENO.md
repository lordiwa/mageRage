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
