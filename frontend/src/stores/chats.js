import { writable, get } from 'svelte/store';
import axios from 'axios';

const store = writable([]);
export default store;

// Loads the initial characters and set the store state
export async function loadChatLog() {
	let resp = await axios.get(`/api/chats`);
	store.set(resp.data.chats);
}

export async function insertNewMessage(msgPayload) {
	let chatLog = get(store);
	chatLog = [msgPayload, ...chatLog];
	store.set(chatLog);
}
