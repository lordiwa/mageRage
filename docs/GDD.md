# MAGE RAGE — GAME DESIGN DOCUMENT (GDD)

## 1. Resumen del Proyecto y Visión

**Nombre:** Mage Rage
**Género:** 2D Side-scroller / Metroidvania de Acción y Plataformas.

**Premisa (Pitch):** Un niño mago, un arma humana diseñada para acabar con una antigua guerra galáctica, escapa de su prisión en un imperio tecno-mágico dominando las energías elementales y la antimateria. Sin embargo, su propia liberación enciende un faro cósmico que revela la ubicación de la Tierra a sus depredadores.

**Pilares de Diseño:**
- **El carcelero era el protector:** El Imperio no es puramente malvado, sino una cuarentena que olvidó su propósito.
- **El arma decide su propio blanco:** El protagonista está diseñado para destruir, pero elige sacrificarse para purgar a los verdaderos parásitos ("Los Antiguos") de una dimensión superior.
- **El Vuelo es Libertad y Perdición:** Volar no es solo una mecánica; representa el despertar definitivo que desata el conflicto galáctico.

---

## 2. Bucle de Jugabilidad (Core Game Loop)

Siguiendo las mejores prácticas de diseño para mantener al jugador enganchado:

- **Momento a Momento (Micro):** Correr y evadir por los laberintos de la prisión. Intercambiar y mezclar Fuego, Hielo y Electricidad según el tipo de armadura de los drones, guardias y maquinaria tecno-mágica del Imperio.
- **Minuto a Minuto:** Limpiar sectores de la prisión, resolver puzzles de movilidad usando el entorno, y destruir jefes mecánicos menores.
- **Hora a Hora (Macro/Progresión):** Absorber y dominar permanentemente un nuevo elemento, lo que desencadena una evolución directa en las capacidades de movimiento (salto → planeo → vuelo) y abre nuevas rutas en el laberinto.

---

## 3. Mecánicas Core: Magia, Antimateria y Movilidad

El corazón del juego. Las energías elementales no solo son ataques, determinan la movilidad:

- **Fuego (Ataque y Agresión):** Magia de daño directo y empuje. **Mejora de Movimiento:** Permite el Salto / Dash explosivo (despegando los pies del suelo por primera vez).
- **Hielo (Control y Defensa):** Detiene o ralentiza los sistemas mecánicos del Imperio. **Mejora de Movimiento:** Permite el Planeo (ralentiza el descenso controlando el aire).
- **Electricidad (Alcance y Disrupción):** Daño en cadena que salta entre autómatas. **Mejora de Movimiento:** Permite Levitación y Vuelo Total, cambiando el juego definitivamente a un side-scroller aéreo.
- **La Cuarta Esfera (Antimateria - El Ultimate):** A diferencia de las otras energías nativas, la antimateria genera energía pura al tocar la realidad. Se cargará al combatir y, al liberarse, el protagonista entra en un estado temporal donde encarna el límite entre creación y destrucción, canalizando todos los elementos simultáneamente.

---

## 4. Facciones y Bucles de Retroalimentación (Feedback Loops)

El juego usa la dificultad dinámica justificada por el lore:

- **El Imperio (Carceleros Amnésicos):** Serán tus enemigos estándar. Cuanto más poder desatas, más fuertes son las contramedidas que envían para detenerte (Bucle de Retroalimentación Negativa / Balance).
- **Los Dioses Androides, Los Reptilianos y Los Antiguos:** Forman el trasfondo narrativo. Tu incremento de poder atrae lentamente a estas entidades, culminando en el clímax final del sacrificio del protagonista contra Los Antiguos (los titiriteros parasitarios).

---

## 5. Arquitectura Técnica y Buenas Prácticas en Godot 4

Dado que estamos creando un juego sistémico y complejo, es vital no crear "código espagueti". Para implementar este GDD, usaremos lo siguiente en Godot:

### A. Máquina de Estados Finitos (FSM) para la Movilidad
Pasar de caminar, a saltar, a planear y a volar libremente en 8 direcciones sería un infierno si solo usas bloques `if/else` y variables booleanas (ej. `is_flying`).

**La Solución:** Crea un sistema de Máquina de Estados basado en nodos. Tendrás un nodo `EstadoBase`, y de ahí heredarás nodos hijos como `MoveState`, `JumpState`, `GlideState` y `FlightState`. Cada uno tendrá su propia lógica. Cuando el niño absorbe la Electricidad, el juego simplemente permitirá la transición definitiva al `FlightState`.

### B. Recursos Personalizados (Custom Resources) para la Magia
En Godot 4, no crees un script entero para cada combinación de magia. Usa Recursos.

**La Solución:** Crea un script de clase `SpellData` que herede de `Resource`. Pon variables exportadas (`@export`) como `daño`, `velocidad`, `elemento_tipo` (Fuego, Hielo, Antimateria), y `efecto_visual`. Al crear combinaciones, solo creas un nuevo archivo `.tres` en tu editor, ajustas los valores, y tu `WeaponManager` / `MagicManager` solo leerá los datos. Crear un nuevo hechizo te tomará segundos.

### C. Gestión de Física con Capas y Máscaras (Collision Layers/Masks)
El Imperio tecno-mágico tendrá muchas interacciones.
- **Capa (Layer) = Lo que eres. Máscara (Mask) = Con lo que chocas / Lo que detectas.**
- Configura `Layer 1: Entorno` (los muros del laberinto), `Layer 2: Jugador`, `Layer 3: Enemigos` (Imperio).
- Asegúrate de que la magia del jugador (proyectiles/áreas) no esté en la capa del jugador, sino en su propia capa, pero que su "Máscara" busque la `Layer 3` (Enemigos). Esto evita que tu propio personaje se golpee con sus poderes y optimiza enormemente el rendimiento físico de Godot.

### D. Entorno y TileMapLayers
La prisión debe sentirse inmensa e industrial. Usa el nodo `TileMapLayer` introducido en Godot 4.3+.
Utiliza los Terrains (Autotiling) de Godot para que al pintar pisos, paredes tecnológicas y rejas, Godot conecte los bordes automáticamente de acuerdo a reglas lógicas.

---

> Para el canon narrativo completo (cosmología, facciones, arco del héroe, temas), ver [`LORE-BIBLE.md`](./LORE-BIBLE.md).
> Para decisiones de diseño que resuelven ambigüedades de este GDD (DDA, ultimate de
> antimateria, UI de mapa, anti-dominancia, idioma), ver [`DECISIONES-DISENO.md`](./DECISIONES-DISENO.md).
