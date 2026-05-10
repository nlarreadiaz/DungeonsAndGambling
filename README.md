# Dungeon & Gambling

Videojuego 2D desarrollado con Godot 4.6. Combina exploracion en un mundo de fantasia, seleccion de clase, inventario persistente, tienda de herreria, encuentros por turnos y una maquina de slots como minijuego.

El proyecto esta pensado como un RPG de vista superior con ambientacion medieval: el jugador elige un aventurero, explora la aldea principal, entra en zonas como la herreria o la mazmorra de agua, recoge objetos, administra inventario y resuelve combates contra enemigos como esbirros y la Reina Oscura.

## Caracteristicas principales

- Menu principal con transiciones y musica.
- Seleccion de rol entre guerrero, arquera y mago.
- Mundo 2D explorable con aldea principal, muelle, edificios y NPCs.
- Movimiento con teclado, carrera, salto visual, ataque y pausa.
- Sistema de inventario con 34 espacios, guardado y sincronizacion con base de datos.
- Sistema de combate por turnos con comandos de atacar, habilidad, objeto, defender y huir.
- Encuentros integrados en el mapa y retorno automatico a la escena anterior.
- Persistencia de estado de partida, oro, inventario, vida, mana y encuentros derrotados.
- Herreria con tienda, compra de armas/armaduras y consumo de oro.
- Mazmorra de agua con musica ambiental, enemigos y jefe final.
- Minijuego de slots con tirada de palanca y resultados aleatorios.
- Importacion de mapas desde Tiled mediante YATI.
- Base de datos SQLite local mediante el plugin `godot-sqlite`.

## Estado del proyecto

El juego se encuentra en fase de desarrollo. Ya existe un flujo jugable basico:

1. Abrir el menu principal.
2. Seleccionar clase.
3. Entrar en la aldea principal.
4. Explorar, abrir inventario e interactuar con zonas.
5. Entrar en la herreria y comprar equipo.
6. Activar encuentros de combate.
7. Volver al mapa tras victoria, derrota o huida.

Algunas partes pueden estar en construccion o usarse para pruebas, como escenas de dungeon alternativas, recursos temporales y previsualizaciones de assets.

## Requisitos

### Motor

- Godot Engine 4.6.x.
- Este proyecto usa GDScript, por lo que no necesita la version .NET/C# de Godot.
- Render configurado en modo `GL Compatibility`.
- Proyecto configurado con resolucion base de 480 x 270 y ventana de 1600 x 900.

### Sistema recomendado

- Windows 10/11, macOS o Linux de 64 bits.
- GPU compatible con OpenGL 3.3 como minimo.
- Espacio suficiente para assets, imports de Godot y plantillas de exportacion.

### Dependencias incluidas

El repositorio ya contiene estas dependencias dentro de `addons/`:

- `godot-sqlite` 4.7: acceso a SQLite desde Godot.
- `YATI` 2.2.7: importador de mapas de Tiled.

Si al abrir el proyecto Godot marca los plugins como desactivados, activarlos desde `Project > Project Settings > Plugins`.

## Como instalar Godot

Godot no requiere un instalador tradicional en Windows: se descarga, se extrae y se ejecuta.

### Windows

1. Entrar en la pagina oficial: <https://godotengine.org/download/windows/>.
2. Descargar `Godot Engine 4.6.x` para `x86_64`.
3. Extraer el archivo `.zip` en una carpeta fija, por ejemplo:

   ```text
   C:\Herramientas\Godot\
   ```

4. Ejecutar `Godot_v4.6.x-stable_win64.exe`.
5. Opcional: crear un acceso directo o anclarlo a la barra de tareas.
6. Para exportar juegos, descargar tambien `Export templates` desde la misma pagina o instalarlas desde el editor.

No descargues la version `.NET` salvo que vayas a trabajar con C#. Este proyecto usa GDScript.

### macOS

1. Descargar Godot desde <https://godotengine.org/download/>.
2. Abrir el archivo descargado.
3. Mover `Godot.app` a la carpeta `Applications`.
4. Abrir Godot desde `Applications` o Spotlight.
5. Si macOS bloquea la app por seguridad, permitirla desde `System Settings > Privacy & Security`.

### Linux

1. Descargar Godot desde <https://godotengine.org/download/>.
2. Extraer el archivo.
3. Dar permisos de ejecucion si hace falta:

   ```bash
   chmod +x Godot_v4.6.x-stable_linux.x86_64
   ```

4. Ejecutar Godot:

   ```bash
   ./Godot_v4.6.x-stable_linux.x86_64
   ```

Tambien se puede instalar mediante gestores como Steam, itch.io, Flathub, Homebrew o paquetes de la distribucion, pero para este proyecto se recomienda usar una version 4.6.x estable.

## Instalacion del proyecto

### 1. Obtener el repositorio

Clonar el repositorio o descargarlo como `.zip`:

```bash
git clone <URL_DEL_REPOSITORIO>
cd DungeonsAndGambling
```

Si se descarga como `.zip`, extraerlo en una ruta sin caracteres raros y abrir esa carpeta desde Godot.

### 2. Abrir en Godot

1. Abrir Godot.
2. En el Project Manager, elegir `Import`.
3. Seleccionar el archivo `project.godot` de este repositorio.
4. Pulsar `Import & Edit`.
5. Esperar a que Godot importe todos los recursos. La primera importacion puede tardar.

### 3. Revisar plugins

Dentro del editor:

1. Ir a `Project > Project Settings > Plugins`.
2. Verificar que esten activos:
   - `Godot SQLite`
   - `YATI`
3. Si se activa algun plugin, reiniciar el editor si Godot lo solicita.

### 4. Ejecutar el juego

Desde el editor:

- Pulsar `F5` para ejecutar la escena principal.
- La escena principal configurada es:

  ```text
  res://Scenes/ui/menu.tscn
  ```

Desde terminal, ajustando la ruta del ejecutable de Godot:

```bash
godot --path .
```

En Windows, si Godot no esta en el `PATH`, usar la ruta completa al `.exe`:

```powershell
& "C:\Herramientas\Godot\Godot_v4.6.x-stable_win64.exe" --path .
```

## Controles

### Exploracion

| Accion | Tecla / entrada |
| --- | --- |
| Moverse | `WASD` o flechas |
| Correr | `Shift` mientras te mueves |
| Saltar | `Espacio` |
| Atacar | Click izquierdo |
| Abrir/cerrar inventario | `I` |
| Interactuar | `E` |
| Pausa / volver | `Esc` |

### Menus

| Accion | Tecla / entrada |
| --- | --- |
| Seleccionar botones | Mouse o teclado |
| Confirmar | Click / accion del boton |
| Volver | `Esc` |

### Combate

El combate se controla desde la interfaz:

- `Atacar`: realiza un ataque basico.
- `Habilidad`: muestra habilidades disponibles del personaje.
- `Objeto`: permite usar objetos de combate.
- `Defender`: reduce el riesgo durante el turno.
- `Huir`: intenta salir del combate.

Al terminar el combate, el juego vuelve automaticamente al mapa segun el resultado.

## Flujo de juego

1. El juego inicia en `Scenes/ui/menu.tscn`.
2. El boton de jugar lleva a `Scenes/ui/role_selection.tscn`.
3. La seleccion de rol guarda datos del personaje mediante `GameDatabase`.
4. El jugador entra en `Scenes/world/aldea_principal.tscn`.
5. Desde la aldea puede:
   - Explorar el mapa.
   - Abrir el inventario.
   - Entrar en la herreria.
   - Activar encuentros de combate.
6. Las batallas usan `Scenes/battle/battle_scene.tscn`.
7. Tras victoria, derrota o huida, `BattleManager` devuelve al jugador a la escena de origen.

## Estructura del proyecto

```text
DungeonsAndGambling/
├── addons/                 Plugins de Godot incluidos en el proyecto.
├── assets/                 Sprites, musica, tilesets, UI, personajes y recursos.
├── Database/               Base de datos, esquema SQL, seeds y scripts de acceso.
├── images/                 Imagenes usadas en seleccion de rol y otras escenas.
├── Scenes/                 Escenas del juego separadas por UI, mundo y combate.
├── Scripts/                Scripts GDScript del jugador, UI, mundo, combate e inventario.
├── _asset_previews/        Previsualizaciones de trabajo para assets.
├── tmp/                    Recursos temporales de desarrollo.
├── export_presets.cfg      Presets de exportacion.
├── project.godot           Configuracion principal del proyecto.
├── Memoria_D&G.pdf         Documento/memoria del proyecto.
└── README.md               Documentacion principal.
```

## Escenas importantes

| Escena | Uso |
| --- | --- |
| `Scenes/ui/menu.tscn` | Menu principal y punto de entrada del juego. |
| `Scenes/ui/role_selection.tscn` | Seleccion de guerrero, arquera o mago. |
| `Scenes/world/aldea_principal.tscn` | Mapa principal de exploracion. |
| `Scenes/world/herreria.tscn` | Interior de herreria y tienda. |
| `Scenes/dungeonAgua.tscn` | Mazmorra de agua con encuentros. |
| `Scenes/battle/battle_scene.tscn` | Sistema de combate por turnos. |
| `Scenes/ui/inventory_ui.tscn` | Interfaz de inventario. |
| `Scenes/slots.tscn` | Minijuego de maquina tragaperras. |

## Scripts importantes

| Script | Responsabilidad |
| --- | --- |
| `Scripts/menu.gd` | Logica del menu principal. |
| `Scripts/role_selection.gd` | Seleccion de clase, estadisticas y persistencia del rol. |
| `Scripts/player.gd` | Movimiento, ataque, salto, inventario y guardado del jugador. |
| `Scripts/aldea_principal.gd` | Logica del mapa, encuentros, entrada a herreria y pausa. |
| `Scripts/herreria.gd` | Tienda, compra de equipo y gasto de oro. |
| `Scripts/dungeon_agua.gd` | Encuentros de mazmorra, musica ambiental y jefe final. |
| `Scripts/battle/battle_manager.gd` | Transicion entre mundo y combate. |
| `Scripts/battle/battle_scene.gd` | Flujo de turnos, comandos y resultado de combate. |
| `Database/database_manager.gd` | Conexion SQLite, schema, seeds, inventario y estado de partida. |

## Base de datos

El proyecto usa SQLite para guardar datos de RPG:

- Ranuras de guardado.
- Clases.
- Objetos.
- Habilidades.
- Enemigos.
- Inventario.
- Equipo.
- Estado de personajes.
- Misiones.
- Logs de combate.
- Estado general de partida.

Archivos clave:

```text
Database/schema.sql
Database/seed_data.sql
Database/game_database.db
Database/database_manager.gd
Database/queries.gd
```

Al iniciar el juego, `DatabaseManager` copia la base plantilla desde:

```text
res://Database/game_database.db
```

hacia:

```text
user://Database/game_database.db
```

Esto evita modificar directamente la base incluida en el repositorio durante una partida. Si SQLite no esta disponible, el proyecto intenta usar datos de respaldo en JSON para que algunas funciones sigan operativas.

Para reiniciar datos de partida durante desarrollo, borrar la carpeta `user://Database` desde los datos de usuario de Godot o ejecutar una limpieza desde el editor. No borres `Database/game_database.db` del repositorio salvo que quieras regenerar la plantilla.

## Plugins

### Godot SQLite

Necesario para la persistencia real de datos. Si falta o no esta activo, apareceran avisos relacionados con la clase `SQLite`.

Repositorio del plugin:

```text
https://github.com/2shady4u/godot-sqlite
```

### YATI

Importador de mapas creados con Tiled. El proyecto contiene recursos `.tmx` en carpetas como `assets/Tiled_files/`, `assets/dungeon2/` y `assets/Herreria/Tiled_files/`.

## Assets y audio

El proyecto incluye:

- Tilesets de aldea, muelle, mazmorra y herreria.
- Sprites de jugador, NPCs, enemigos y jefe.
- UI de fantasia.
- Musica para menu, aldea, mazmorra y combates.
- Recursos de inventario, armas y armaduras.
- Fondos para escenas de combate.

Antes de publicar el juego, revisar las licencias de cada paquete de assets. Hay archivos de licencia en carpetas como:

```text
assets/Herreria/license.txt
assets/Boss-DarkQueen/Licens.txt
assets/GUI/Cute_Fantasy_UI/read_me.txt
```

## Exportar el juego

El proyecto incluye `export_presets.cfg`, con un preset de macOS. Para exportar a otras plataformas:

1. Abrir Godot.
2. Ir a `Editor > Manage Export Templates`.
3. Instalar las plantillas de exportacion para Godot 4.6.x.
4. Ir a `Project > Export`.
5. Crear o revisar presets para Windows, Linux, macOS, Web o Android.
6. Asegurarse de que los recursos y plugins requeridos esten incluidos.
7. Exportar el proyecto.

Para Windows, crear un preset `Windows Desktop`. Para Linux, crear `Linux/X11`. Para macOS, completar identificador, version, icono y opciones de firmado si se va a distribuir fuera de pruebas.

## Buenas practicas de desarrollo

- Mantener `project.godot` como fuente principal de configuracion.
- No subir la carpeta `.godot/`; ya esta ignorada.
- Evitar guardar datos personales o partidas locales en el repositorio.
- Revisar que los plugins sigan activos despues de clonar.
- Probar la escena principal antes de hacer cambios grandes.
- Probar tambien escenas concretas con `F6` cuando se editen sistemas aislados.
- Documentar nuevas escenas, controles o sistemas en este README.
- Mantener los assets temporales separados de los assets finales.

## Problemas comunes

### Godot dice que falta la clase SQLite

Verificar:

1. Que existe `addons/godot-sqlite/`.
2. Que el plugin esta activo en `Project Settings > Plugins`.
3. Que se esta usando Godot 4.6.x.
4. Reiniciar Godot despues de activar el plugin.

### La primera apertura tarda mucho

Es normal. Godot debe importar sprites, musica, fuentes, tilesets y escenas. La carpeta `.godot/` se genera localmente y no debe subirse al repositorio.

### Las escenas aparecen sin recursos

Usar `Project > Reload Current Project` o cerrar y abrir Godot. Si se movieron archivos manualmente, revisar rutas `res://`.

### No se guarda la partida

Comprobar que `Godot SQLite` esta activo. Si no lo esta, el juego puede usar estado de respaldo, pero la persistencia principal depende de SQLite.

### El proyecto abre con otra version de Godot

Usar Godot 4.6.x. Abrir con versiones mayores puede modificar imports o recursos. Si se actualiza de version, hacerlo en una rama separada y revisar los cambios generados.

## Roadmap sugerido

- Completar pantallas de victoria, derrota y progreso narrativo.
- Anadir guardado/carga visible desde menu.
- Pulir dialogos de NPCs.
- Expandir recompensas y loot de combates.
- Integrar el sistema de equipo en estadisticas de combate.
- Crear presets de exportacion para Windows y Linux.
- Revisar licencias de assets antes de distribuir.
- Anadir capturas o GIFs al README cuando haya builds estables.

## Licencia

El repositorio incluye un archivo `LICENSE` con licencia MIT. Antes de publicar una build comercial o publica, revisar la titularidad del proyecto y las licencias de terceros, especialmente plugins, musica, sprites y paquetes graficos.

Godot Engine es software libre bajo licencia MIT. Los assets incluidos pueden tener licencias distintas y deben respetarse de forma individual.
