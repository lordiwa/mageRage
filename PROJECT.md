---
name: mage-rage
type: other
created_at: 2026-06-03T02:43:24.900Z
schema_version: 1
---

# mage-rage

[![CI](https://github.com/lordiwa/mageRage/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/lordiwa/mageRage/actions/workflows/ci.yml)

## Description
Metroidvania / side-scroller 2D de accion y plataformas en Godot 4: un nino mago, arma humana disenada para acabar una guerra galactica, escapa de una prision tecno-magica dominando fuego, hielo, electricidad y antimateria.

## Target users
Jugadores de metroidvanias y action-platformers 2D, y el equipo de desarrollo del juego.

## Primary use cases
- other

## Success criteria
El jugador recorre la prision, domina un elemento que evoluciona su movilidad (salto -> planeo -> vuelo) y eso abre nuevas rutas del laberinto (loop metroidvania), con combate elemental contra drones y guardias del Imperio segun su tipo de armadura.

## Milestone M1 — "Vertical Slice: Fuga del Sector"

Primer milestone medible. Prueba el **loop central metroidvania** end-to-end en un único
sector jugable: traversía + combate elemental + un gate de progresión + jefe de sector.
Reconcilia el vuelo-desde-el-inicio del build actual con el gating metroidvania vía
**DD-011** (gate híbrido: elemental-sobre-entorno + zona anti-magia que anula el vuelo).

**Definición de hecho (una frase):** M1 está hecho cuando, en un único build CI-verde, un
jugador puede recorrer un sector de prisión **conectado** de principio a fin —arrancando
con el vuelo ya disponible—, enfrentar combate elemental contra enemigos con armadura,
superar un **gate de progresión híbrido** (una ruta sellada que solo se abre aplicando un
elemento al entorno **y** una zona anti-magia que anula el vuelo hasta purgarla con el
elemento correcto), y derrotar al jefe de sector (Warden) para alcanzar el estado de
victoria.

**Criterios de éxito verificables:**
1. Existe **UN nivel conectado** (no escenas-arena sueltas) jugable inicio → jefe →
   victoria en un solo build; la escena principal del proyecto apunta a él.
2. El héroe **inicia con el vuelo disponible** (respeta DD-008 / DD-011); el gate **no** es
   "desbloquear volar".
3. **Gate elemental-entorno:** ≥1 ruta físicamente intransitable hasta aplicar el elemento
   correcto al entorno. *Verificable:* sin el elemento la ruta permanece cerrada; con el
   elemento se abre y se puede pasar.
4. **Zona anti-magia de vuelo:** ≥1 zona donde el `FlightState` queda deshabilitado hasta
   purgar el campo con el elemento correcto. *Verificable:* dentro de la zona sin purgar =
   no se puede volar; tras purgar = vuelo restaurado.
5. **Combate elemental** contra ≥2 tipos de armadura en la ruta, usando el RPS existente
   (DD-006).
6. **Derrotar al Warden** dispara el estado de victoria del sector.
7. La **suite GUT en CI queda verde** e incluye cobertura de la lógica nueva de ambos gates
   (al menos un test del estado abierto/cerrado del gate elemental y uno del vuelo
   deshabilitado/restaurado en la zona anti-magia).
