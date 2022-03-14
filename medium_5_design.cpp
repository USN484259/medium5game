/*
https://www.bilibili.com/read/cv12782058

Hexagon battle-field, random-generated terrain, round-based game

schedule actions for every character first, then select 'end round', scheduled actions will run in parallel

characters move on the grid. moving across adjacent gird count 1 step. Characters could move multiple steps in each round, according to their speed and current terrain.
characters have sight distance. Area out of characters' sight are covered by fog. some skills could detect specific area.

projectiles fly in straight line towards target, regardless of grids. entities in the way could effect projectiles' behaviour.

terrain could affect character status and some skills

nearly every action consumes energy, characters have energy bar (or called MP), which has a max capacity, and recharge every round if not full
characters cannot issue an action if they don't have enough energy

character skills cost energy, and usually have cooldown time. some skills have preconditions
some skills are toggle-like, which remain active when on and keep consuming energy.
every character have some passive skills, which are always on and active under certain condition

character usually have a main weapon and some special items. some weapons could switch mode, some skills consume specific item. consumed item usually could regenerate after some time.
some skills have multiple modes, which have different effects

some skills have effect, either to target or to terrain, which usually have a duration
some skills could effect each other, like element change, strength / damage type change, distance / accuracy change etc

start of every round
entity_template ==(effects)=> entity_status

entity_template: health & energy, basic value of other fields
entity_status: values calculated from effects


steps of a round:
update
schedule
move
attack
final

skill type:
toggle
normal

*/
class game {
	uint biome;
	uint daylight;
	uint constellation;
	terrain field;
	table<entity> uints;
};


enum layer {
	HEIGHT,
	BIOME,	// water, dirt, plants, void, in percentage
	// WIND,
	LIGHT,
	STAR,

	// rain & wind as entity
};

class point {
	uint distance;
	uint index;
};

typedef map<point, uint> grid;

class terrain {
	uint scale;
	map<layer, grid> layers;

};

class entity {
	string name;
	point pos;
	uint size;
	uint speed;
	uint health;
	uint sight;
	map<element, uint> resistance;

	table<effect> buff_list;
	table<action> action_list;
};

class character : public entity {
	uint sanity;
	uint mental_resistance;
	int status;	// fly, hover, using ablity etc

	int generator;
	int energy;
	int energy_cap;

	table<item> inventory;
	table<skill> skill_list;
};

class action {	// callback on specific event
	uint type;
	function callback;
};

class item {	// item held by character, shared by some skills;
	string name;
	bool in_use;
	uint cooldown;
};

class skill {	// character skills, move, attack, using ablity etc
	uint type;
	uint element;
	uint cost;
	uint power;
	uint speed;
	uint accuracy;
	uint range;
	uint duration;
	uint cooldown;
	function condition;
	function trigger;
};

class effect {	// effects change entity status, some with duration
	uint type;
	uint priority;
	uint strength;
	uint duration;
	entity origin;
	function callback;
};
