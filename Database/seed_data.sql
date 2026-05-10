PRAGMA foreign_keys = ON;

INSERT OR IGNORE INTO save_slots (id, slot_index, save_name, saved_at, current_location, playtime_seconds) VALUES
    (1, 1, 'Partida principal', CURRENT_TIMESTAMP, 'aldea_principal', 5400),
    (2, 2, 'Partida secundaria', CURRENT_TIMESTAMP, 'campamento', 0),
    (3, 3, 'Partida libre', CURRENT_TIMESTAMP, 'aldea_principal', 0);

INSERT OR IGNORE INTO classes (id, name, description, role, base_max_hp, base_max_mana, base_attack, base_defense, base_speed) VALUES
    (1, 'Guerrero', 'Clase de primera linea resistente y ofensiva.', 'frontliner', 160, 20, 18, 14, 8),
    (2, 'Mago', 'Especialista en dano magico y control.', 'caster', 95, 120, 9, 7, 10),
    (3, 'Arquero', 'Especialista en dano fisico a distancia.', 'ranged', 110, 35, 14, 9, 14),
    (4, 'Sanador', 'Soporte con curacion y utilidad.', 'support', 105, 110, 8, 10, 11);

INSERT OR IGNORE INTO items (id, name, description, item_type, rarity, price, icon, max_stack, usable_in_battle, effect_data) VALUES
    (1, 'Pocion', 'Recupera 50 puntos de vida.', 'consumable', 'common', 25, 'res://assets/items/item_estrella.tres', 20, 1, '{"heal_hp":50}'),
    (2, 'Eter', 'Recupera 30 puntos de mana.', 'consumable', 'common', 40, 'res://assets/items/item_moneda.tres', 20, 1, '{"heal_mp":30}'),
    (3, 'Espada de Hierro', 'Arma basica para combatientes.', 'weapon', 'common', 120, 'res://assets/items/generated_pixel_equipment/iron_sword.png', 1, 0, '{"attack_bonus":8}'),
    (4, 'Armadura de Cuero', 'Proteccion ligera para aventureros.', 'armor', 'common', 90, 'res://assets/items/generated_pixel_equipment/leather_helmet.png', 1, 0, '{"defense_bonus":6}'),
    (5, 'Amuleto de la Suerte', 'Accesorio con un ligero bono general.', 'accessory', 'rare', 160, 'res://assets/items/item_estrella.tres', 1, 0, '{"speed_bonus":2,"defense_bonus":1}'),
    (6, 'Hierba Antidoto', 'Elimina estados alterados leves.', 'consumable', 'common', 18, 'res://assets/items/item_moneda.tres', 10, 1, '{"cure_status":"poison"}'),
    (7, 'Armadura de Malla', 'Anillas reforzadas para resistir golpes directos.', 'armor', 'uncommon', 145, 'res://assets/items/generated_pixel_equipment/mail_chestplate.png', 1, 0, '{"defense_bonus":10}'),
    (8, 'Coraza de Guardia', 'Placas firmes con buen equilibrio de peso.', 'armor', 'rare', 220, 'res://assets/items/generated_pixel_equipment/guard_boots.png', 1, 0, '{"defense_bonus":15}');

INSERT OR IGNORE INTO skills (id, name, description, mana_cost, damage, damage_type, target_type, cooldown_turns) VALUES
    (1, 'Golpe Fuerte', 'Ataque fisico de alto impacto.', 0, 24, 'physical', 'single_enemy', 0),
    (2, 'Bola de Fuego', 'Hechizo ofensivo de fuego.', 12, 36, 'fire', 'single_enemy', 1),
    (3, 'Disparo Certero', 'Ataque a distancia muy preciso.', 6, 22, 'physical', 'single_enemy', 0),
    (4, 'Curacion Menor', 'Restaura vida a un aliado.', 10, -32, 'holy', 'single_ally', 1);

INSERT OR IGNORE INTO enemies (id, name, description, level, max_hp, max_mana, attack, defense, speed, status_default, experience_reward, gold_reward) VALUES
    (1, 'Slime Verde', 'Enemigo basico del bosque.', 1, 45, 0, 8, 3, 4, 'normal', 12, 6),
    (2, 'Goblin Ladron', 'Enemigo rapido que roba recursos.', 3, 78, 10, 14, 6, 11, 'normal', 28, 18),
    (3, 'Lobo Salvaje', 'Bestia agil con gran velocidad.', 4, 92, 0, 17, 8, 16, 'normal', 35, 20);

INSERT OR IGNORE INTO enemy_loot (id, enemy_id, item_id, drop_chance, min_quantity, max_quantity) VALUES
    (1, 1, 1, 0.60, 1, 2),
    (2, 2, 2, 0.30, 1, 1),
    (3, 2, 6, 0.55, 1, 2),
    (4, 3, 1, 0.45, 1, 3);

INSERT OR IGNORE INTO characters (id, save_slot_id, class_id, enemy_template_id, name, character_type, level, experience, max_hp, current_hp, max_mana, current_mana, attack, defense, speed, current_state, is_active) VALUES
    (1, 1, 1, NULL, 'Ariadna', 'player', 4, 180, 170, 145, 25, 18, 22, 15, 9, 'normal', 1),
    (2, 1, 2, NULL, 'Selene', 'player', 4, 160, 108, 90, 135, 104, 11, 8, 12, 'normal', 1),
    (3, 1, NULL, 2, 'Goblin Jefe', 'enemy', 5, 0, 120, 120, 10, 10, 19, 10, 12, 'normal', 1);

INSERT OR IGNORE INTO inventory (id, save_slot_id, character_id, item_id, quantity, slot_index) VALUES
    (1, 1, 1, 1, 5, 0),
    (2, 1, 1, 3, 1, 1),
    (3, 1, 1, 4, 1, 2),
    (4, 1, 1, 5, 1, 3),
    (5, 1, 2, 2, 4, 0),
    (6, 1, 2, 6, 3, 1);

INSERT OR IGNORE INTO equipment (id, save_slot_id, character_id, item_id, equip_slot) VALUES
    (1, 1, 1, 3, 'weapon'),
    (2, 1, 1, 4, 'armor'),
    (3, 1, 1, 5, 'accessory');

INSERT OR IGNORE INTO character_skills (id, save_slot_id, character_id, skill_id, learned_at_level, cooldown_remaining) VALUES
    (1, 1, 1, 1, 1, 0),
    (2, 1, 2, 2, 1, 0),
    (3, 1, 2, 4, 2, 0);

INSERT OR IGNORE INTO quests (id, save_slot_id, title, description, status, reward_experience, reward_gold, objective_data) VALUES
    (1, 1, 'La primera apuesta', 'Habla con el herrero y consigue un arma para empezar la aventura.', 'active', 80, 50, '{"blacksmith_interaction":1,"iron_sword":1}'),
    (2, 1, 'Limpieza del bosque', 'Derrota slimes cerca de la aldea para proteger a los habitantes.', 'inactive', 120, 75, '{"slime_kills":5}');

INSERT OR IGNORE INTO quest_rewards (id, quest_id, item_id, quantity) VALUES
    (1, 1, 1, 3),
    (2, 2, 2, 2);

INSERT OR IGNORE INTO battle_logs (id, save_slot_id, turn_number, attacker_character_id, target_character_id, skill_id, damage_done, result) VALUES
    (1, 1, 1, 1, 3, 1, 26, 'Golpe critico sobre Goblin Jefe.');

INSERT OR IGNORE INTO game_state (id, save_slot_id, gold, current_location, main_progress, important_flags, updated_at) VALUES
    (1, 1, 235, 'aldea_principal', 2, '{"tutorial_done":1,"blacksmith_unlocked":1,"queen_seen":1}', CURRENT_TIMESTAMP),
    (2, 2, 0, 'campamento', 0, '{}', CURRENT_TIMESTAMP),
    (3, 3, 0, 'aldea_principal', 0, '{}', CURRENT_TIMESTAMP);
