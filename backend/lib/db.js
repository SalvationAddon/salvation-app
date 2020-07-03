const fs = require('fs');
const dbFile = `${__dirname}/../../.data/sqlite.db`;

const db = require('better-sqlite3')(dbFile);
module.exports = db;

// This will create the tables for the database, these should always be run with "IF NOT EXISTS"
createTables();

async function createTables() {
	let createStatement = `
	CREATE TABLE IF NOT EXISTS "characters" (
		id integer PRIMARY KEY AUTOINCREMENT,
		name varchar NOT NULL,
		class varchar NOT NULL,
		level int NOT NULL,
		xp int NOT NULL DEFAULT '0',
		max_xp int NOT NULL DEFAULT '0',
		realm varchar NOT NULL,
		faction varchar NOT NULL,
		online bool NOT NULL DEFAULT 'false',
		zone varchar NOT NULL,
		sub_zone varchar NOT NULL,
		coins int NOT NULL DEFAULT '0',
		last_ping DATETIME DEFAULT CURRENT_TIMESTAMP,
		UNIQUE(name,realm)
	);

	CREATE TABLE IF NOT EXISTS "chat_log" (
		id integer PRIMARY KEY AUTOINCREMENT,
		character_id integer NOT NULL,
		"from" varchar NOT NULL,
		"to" varchar NOT NULL,
		message varchar NOT NULL,
		realm varchar NOT NULL,
		is_response bool NOT NULL DEFAULT 'false',
		is_auto_responder bool NOT NULL DEFAULT 'false',
		timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
	);
	 `;

	db.exec(createStatement);
}
