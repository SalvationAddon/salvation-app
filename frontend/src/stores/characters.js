import { writable, get } from 'svelte/store';
import axios from 'axios';

const store = writable([]);
export default store;

// Loads the initial characters and set the store state
export async function loadCharacters() {
	let resp = await axios.get(`/api/characters`);
	store.set(resp.data.characters);
}

// remove a character from the system
export async function removeCharacter(id) {
	let resp = await axios.delete(`/api/characters/${id}`);
	if (resp.data) {
		store.set(resp.data.characters);
	}
}

// checks if a character exists in the store, and is online
export async function isCharacterOnline(id) {
	for (const char of get(store)) {
		if (char.id == id) {
			if (char.online) {
				return true;
			} else {
				return false;
			}
		}
	}
	return false;
}
