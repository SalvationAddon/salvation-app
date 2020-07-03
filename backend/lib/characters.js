const db = require('./db');

function upsert(characterPayload) {
	const insert = db.prepare(
		`INSERT INTO characters (name, class, level, xp, max_xp, realm, online, zone, faction, sub_zone, coins, last_ping)
		VALUES (@name, @class, @level, @xp, @max_xp, @realm, TRUE, @zone, @faction, @sub_zone, @coins, CURRENT_TIMESTAMP)
		ON CONFLICT(name, realm) DO UPDATE SET
			name=@name,
			online=TRUE,
			level=@level,
			class=@class,
			zone=@zone,
			faction=@faction,
			sub_zone=@sub_zone,
			xp=@xp,
			max_xp=@max_xp,
			coins=@coins,
			last_ping=CURRENT_TIMESTAMP
		`
	);
	insert.run(characterPayload);

	// Get the character after inserting and return it
	return getCharacter(characterPayload.name, characterPayload.realm);
}
exports.upsert = upsert;

function getCharacter(name, realm) {
	const statement = db.prepare('SELECT * FROM characters WHERE name = @name AND realm=@realm');
	const character = statement.get({ name, realm });
	return character;
}
exports.getCharacter = getCharacter;

function getCharacterByID(id) {
	const statement = db.prepare('SELECT * FROM characters WHERE id = ?');
	const character = statement.get(id);
	return character;
}
exports.getCharacterByID = getCharacterByID;

function deleteCharacter(id) {
	const statement = db.prepare('DELETE FROM characters WHERE id = ?');
	statement.run(id);
}
exports.deleteCharacter = deleteCharacter;

function getAllCharacters() {
	const statement = db.prepare('SELECT * FROM characters ORDER BY online DESC');
	const characters = statement.all();
	return characters;
}
exports.getAllCharacters = getAllCharacters;

// timeoutCharacters marks any online characters "offline" that haven't checked in for double the heartbeat duration.
function timeoutCharacters(timeoutMs) {
	try {
		const statement = db.prepare(`
		select id, name, realm, Cast ((
			JulianDay('now') - JulianDay(last_ping)
		) * 24 * 60 * 60 * 1000 As Integer) as seconds_since_ping from characters
		where
		seconds_since_ping >= ?
		AND online = 1
		`);
		const characters = statement.all(timeoutMs);

		for (const char of characters) {
			console.log(`Timing out character: (${char.id}) ${char.name} - ${char.realm}`);
			const statement = db.prepare(`
			UPDATE characters SET online = '0' WHERE id = ?;
			`);
			statement.run(char.id);
		}
	} catch (e) {
		console.log('Failed to timeout character:');
		console.log(e);
	}
}
exports.timeoutCharacters = timeoutCharacters;
