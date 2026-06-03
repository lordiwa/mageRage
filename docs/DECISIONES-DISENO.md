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
