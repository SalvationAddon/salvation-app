const db = require('./db');
const { getCharacter } = require('./characters');

function getRecentChats() {
	const statement = db.prepare('SELECT cl.*, c.name as character_name FROM chat_log cl LEFT JOIN characters c ON (c.id = cl.character_id) ORDER BY timestamp DESC LIMIT 50');
	const chats = statement.all();
	return chats;
}
exports.getRecentChats = getRecentChats;

function getChatByID(id) {
	const statement = db.prepare('SELECT cl.*, c.name as character_name FROM chat_log cl LEFT JOIN characters c ON (c.id = cl.character_id) WHERE cl.id = ?');
	const chat = statement.get(id);
	return chat;
}
exports.getChatByID = getChatByID;

function createChatLogEntry({ character_id, realm, to, from, message, is_response, is_auto_responder }) {
	if (!is_auto_responder) {
		is_auto_responder = 0;
	}

	if (character_id) {
		const insert = db.prepare(
			`INSERT INTO chat_log (character_id, "to", "from", message, realm, is_response, is_auto_responder, timestamp)
			VALUES (@character_id, @to, @from, @message, @realm, @is_response, @is_auto_responder, CURRENT_TIMESTAMP)
			`
		);
		let result = insert.run({ character_id, to, from, message, realm, is_response, is_auto_responder });
		return getChatByID(result.lastInsertRowid);
	}

	return;
}
exports.createChatLogEntry = createChatLogEntry;
