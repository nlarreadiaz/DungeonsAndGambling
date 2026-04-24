PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS save_slots (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    slot_index INTEGER NOT NULL UNIQUE,
    save_name TEXT NOT NULL,
    saved_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    current_location TEXT NOT NULL DEFAULT 'aldea_principal',
    playtime_seconds INTEGER NOT NULL DEFAULT 0 CHECK (playtime_seconds >= 0)
);

CREATE TABLE IF NOT EXISTS classes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL DEFAULT '',
    role TEXT NOT NULL DEFAULT '',
    base_max_hp INTEGER NOT NULL DEFAULT 100 CHECK (base_max_hp >= 1),
    base_max_mana INTEGER NOT NULL DEFAULT 0 CHECK (base_max_mana >= 0),
    base_attack INTEGER NOT NULL DEFAULT 5 CHECK (base_attack >= 0),
    base_defense INTEGER NOT NULL DEFAULT 5 CHECK (base_defense >= 0),
    base_speed INTEGER NOT NULL DEFAULT 5 CHECK (base_speed >= 0)
);

CREATE TABLE IF NOT EXISTS items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL DEFAULT '',
    item_type TEXT NOT NULL,
    rarity TEXT NOT NULL DEFAULT 'common',
    price INTEGER NOT NULL DEFAULT 0 CHECK (price >= 0),
    icon TEXT NOT NULL DEFAULT '',
    max_stack INTEGER NOT NULL DEFAULT 1 CHECK (max_stack >= 1),
    usable_in_battle INTEGER NOT NULL DEFAULT 0 CHECK (usable_in_battle IN (0, 1)),
    effect_data TEXT NOT NULL DEFAULT '{}'
);

CREATE TABLE IF NOT EXISTS skills (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL DEFAULT '',
    mana_cost INTEGER NOT NULL DEFAULT 0 CHECK (mana_cost >= 0),
    damage INTEGER NOT NULL DEFAULT 0,
    damage_type TEXT NOT NULL DEFAULT 'physical',
    target_type TEXT NOT NULL DEFAULT 'single_enemy',
    cooldown_turns INTEGER NOT NULL DEFAULT 0 CHECK (cooldown_turns >= 0)
);

CREATE TABLE IF NOT EXISTS enemies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL DEFAULT '',
    level INTEGER NOT NULL DEFAULT 1 CHECK (level >= 1),
    max_hp INTEGER NOT NULL DEFAULT 1 CHECK (max_hp >= 1),
    max_mana INTEGER NOT NULL DEFAULT 0 CHECK (max_mana >= 0),
    attack INTEGER NOT NULL DEFAULT 0 CHECK (attack >= 0),
    defense INTEGER NOT NULL DEFAULT 0 CHECK (defense >= 0),
    speed INTEGER NOT NULL DEFAULT 0 CHECK (speed >= 0),
    status_default TEXT NOT NULL DEFAULT 'normal',
    experience_reward INTEGER NOT NULL DEFAULT 0 CHECK (experience_reward >= 0),
    gold_reward INTEGER NOT NULL DEFAULT 0 CHECK (gold_reward >= 0)
);

CREATE TABLE IF NOT EXISTS enemy_loot (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    enemy_id INTEGER NOT NULL,
    item_id INTEGER NOT NULL,
    drop_chance REAL NOT NULL CHECK (drop_chance >= 0.0 AND drop_chance <= 1.0),
    min_quantity INTEGER NOT NULL DEFAULT 1 CHECK (min_quantity >= 0),
    max_quantity INTEGER NOT NULL DEFAULT 1 CHECK (max_quantity >= min_quantity),
    FOREIGN KEY (enemy_id) REFERENCES enemies(id) ON DELETE CASCADE,
    FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
    UNIQUE (enemy_id, item_id)
);

CREATE TABLE IF NOT EXISTS characters (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    save_slot_id INTEGER NOT NULL,
    class_id INTEGER,
    enemy_template_id INTEGER,
    name TEXT NOT NULL,
    character_type TEXT NOT NULL DEFAULT 'player',
    level INTEGER NOT NULL DEFAULT 1 CHECK (level >= 1),
    experience INTEGER NOT NULL DEFAULT 0 CHECK (experience >= 0),
    max_hp INTEGER NOT NULL CHECK (max_hp >= 1),
    current_hp INTEGER NOT NULL CHECK (current_hp >= 0),
    max_mana INTEGER NOT NULL DEFAULT 0 CHECK (max_mana >= 0),
    current_mana INTEGER NOT NULL DEFAULT 0 CHECK (current_mana >= 0),
    attack INTEGER NOT NULL DEFAULT 0 CHECK (attack >= 0),
    defense INTEGER NOT NULL DEFAULT 0 CHECK (defense >= 0),
    speed INTEGER NOT NULL DEFAULT 0 CHECK (speed >= 0),
    current_state TEXT NOT NULL DEFAULT 'normal',
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (save_slot_id) REFERENCES save_slots(id) ON DELETE CASCADE,
    FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE SET NULL,
    FOREIGN KEY (enemy_template_id) REFERENCES enemies(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS inventory (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    save_slot_id INTEGER NOT NULL,
    character_id INTEGER NOT NULL,
    item_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
    slot_index INTEGER NOT NULL CHECK (slot_index >= 0),
    FOREIGN KEY (save_slot_id) REFERENCES save_slots(id) ON DELETE CASCADE,
    FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE CASCADE,
    FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
    UNIQUE (save_slot_id, character_id, slot_index)
);

CREATE TABLE IF NOT EXISTS equipment (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    save_slot_id INTEGER NOT NULL,
    character_id INTEGER NOT NULL,
    item_id INTEGER NOT NULL,
    equip_slot TEXT NOT NULL,
    equipped_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (save_slot_id) REFERENCES save_slots(id) ON DELETE CASCADE,
    FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE CASCADE,
    FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
    UNIQUE (save_slot_id, character_id, equip_slot)
);

CREATE TABLE IF NOT EXISTS character_skills (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    save_slot_id INTEGER NOT NULL,
    character_id INTEGER NOT NULL,
    skill_id INTEGER NOT NULL,
    learned_at_level INTEGER NOT NULL DEFAULT 1 CHECK (learned_at_level >= 1),
    cooldown_remaining INTEGER NOT NULL DEFAULT 0 CHECK (cooldown_remaining >= 0),
    FOREIGN KEY (save_slot_id) REFERENCES save_slots(id) ON DELETE CASCADE,
    FOREIGN KEY (character_id) REFERENCES characters(id) ON DELETE CASCADE,
    FOREIGN KEY (skill_id) REFERENCES skills(id) ON DELETE CASCADE,
    UNIQUE (save_slot_id, character_id, skill_id)
);

CREATE TABLE IF NOT EXISTS quests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    save_slot_id INTEGER NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'inactive',
    reward_experience INTEGER NOT NULL DEFAULT 0 CHECK (reward_experience >= 0),
    reward_gold INTEGER NOT NULL DEFAULT 0 CHECK (reward_gold >= 0),
    objective_data TEXT NOT NULL DEFAULT '{}',
    FOREIGN KEY (save_slot_id) REFERENCES save_slots(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS quest_rewards (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    quest_id INTEGER NOT NULL,
    item_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
    FOREIGN KEY (quest_id) REFERENCES quests(id) ON DELETE CASCADE,
    FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
    UNIQUE (quest_id, item_id)
);

CREATE TABLE IF NOT EXISTS battle_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    save_slot_id INTEGER NOT NULL,
    turn_number INTEGER NOT NULL CHECK (turn_number >= 1),
    attacker_character_id INTEGER,
    target_character_id INTEGER,
    skill_id INTEGER,
    damage_done INTEGER NOT NULL DEFAULT 0,
    result TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (save_slot_id) REFERENCES save_slots(id) ON DELETE CASCADE,
    FOREIGN KEY (attacker_character_id) REFERENCES characters(id) ON DELETE SET NULL,
    FOREIGN KEY (target_character_id) REFERENCES characters(id) ON DELETE SET NULL,
    FOREIGN KEY (skill_id) REFERENCES skills(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS game_state (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    save_slot_id INTEGER NOT NULL UNIQUE,
    gold INTEGER NOT NULL DEFAULT 0 CHECK (gold >= 0),
    current_location TEXT NOT NULL DEFAULT 'aldea_principal',
    main_progress INTEGER NOT NULL DEFAULT 0 CHECK (main_progress >= 0),
    important_flags TEXT NOT NULL DEFAULT '{}',
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (save_slot_id) REFERENCES save_slots(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_characters_save_slot_id ON characters(save_slot_id);
CREATE INDEX IF NOT EXISTS idx_characters_class_id ON characters(class_id);
CREATE INDEX IF NOT EXISTS idx_characters_enemy_template_id ON characters(enemy_template_id);
CREATE INDEX IF NOT EXISTS idx_inventory_character_id ON inventory(character_id);
CREATE INDEX IF NOT EXISTS idx_inventory_item_id ON inventory(item_id);
CREATE INDEX IF NOT EXISTS idx_equipment_character_id ON equipment(character_id);
CREATE INDEX IF NOT EXISTS idx_equipment_item_id ON equipment(item_id);
CREATE INDEX IF NOT EXISTS idx_character_skills_character_id ON character_skills(character_id);
CREATE INDEX IF NOT EXISTS idx_character_skills_skill_id ON character_skills(skill_id);
CREATE INDEX IF NOT EXISTS idx_enemy_loot_enemy_id ON enemy_loot(enemy_id);
CREATE INDEX IF NOT EXISTS idx_enemy_loot_item_id ON enemy_loot(item_id);
CREATE INDEX IF NOT EXISTS idx_quests_save_slot_id ON quests(save_slot_id);
CREATE INDEX IF NOT EXISTS idx_battle_logs_save_slot_id ON battle_logs(save_slot_id);
CREATE INDEX IF NOT EXISTS idx_battle_logs_attacker_character_id ON battle_logs(attacker_character_id);
CREATE INDEX IF NOT EXISTS idx_battle_logs_target_character_id ON battle_logs(target_character_id);
