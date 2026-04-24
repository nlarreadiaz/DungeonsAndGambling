# Database

Sistema SQLite local para el RPG por turnos.

## Dependencia necesaria

Este proyecto no trae el plugin SQLite instalado. Los scripts de `Database/` estan preparados para el plugin oficial:

- [godot-sqlite](https://github.com/2shady4u/godot-sqlite)

Instalacion recomendada en Godot 4:

1. Abrir `AssetLib`.
2. Buscar `godot-sqlite`.
3. Instalarlo dentro de `addons/`.
4. Activarlo en `Project > Project Settings > Plugins`.

## Archivos

- `database_manager.gd`: punto central de acceso a la base de datos.
- `queries.gd`: consultas SQL de personajes, inventario, equipo y estado de partida.
- `schema.sql`: estructura completa de tablas e indices.
- `seed_data.sql`: datos iniciales de ejemplo.
- `game_database.db`: base SQLite de plantilla para desarrollo.

## Uso desde otros scripts

El proyecto registra `GameDatabase` como autoload.

```gdscript
var new_character_id = GameDatabase.create_character({
	"save_slot_id": 1,
	"name": "Nora",
	"class_id": 3,
	"character_type": "player",
	"level": 1,
	"max_hp": 110,
	"current_hp": 110,
	"max_mana": 35,
	"current_mana": 35,
	"attack": 14,
	"defense": 8,
	"speed": 14
})

var characters = GameDatabase.get_characters(1)
var inventory = GameDatabase.get_inventory(new_character_id, 1)

GameDatabase.add_item_to_inventory(new_character_id, 1, 3, 1)
GameDatabase.reduce_character_health(new_character_id, 25, 1)
GameDatabase.equip_item(new_character_id, 3, "weapon", 1)
GameDatabase.save_basic_game_state(1, {
	"save_name": "Partida principal",
	"current_location": "aldea_principal",
	"playtime_seconds": 7200,
	"gold": 350,
	"main_progress": 3,
	"important_flags": {
		"tutorial_done": true,
		"blacksmith_unlocked": true
	}
})
```
