import { wrap, push } from 'svelte-spa-router';
import { get } from 'svelte/store';

import Login from './Login.svelte';
import Dashboard from './pages/Dashboard.svelte';
import ChatLog from './pages/ChatLog.svelte';
import NotFound from './pages/NotFound.svelte';

export const routes = {
	// Exact path
	'/': wrap(Dashboard, loginRequired),
	'/login': wrap(Login),
	'/chat-log': wrap(ChatLog, loginRequired),

	// // Using named parameters, with last being optional
	// '/author/:first/:last?': Author,

	// // Wildcard parameter
	// '/book/*': Book,

	// Catch-all
	// This is optional, but if present it must be the last
	'*': NotFound,
};

function loginRequired(detail) {
	let token = getCookie('salvation_auth');
	if (!token) {
		push('/login');
		return false;
	}
	return true;
}

//[todo]: move to utility
function getCookie(name) {
	let matches = document.cookie.match(new RegExp('(?:^|; )' + name.replace(/([\.$?*|{}\(\)\[\]\\\/\+^])/g, '\\$1') + '=([^;]*)'));
	return matches ? decodeURIComponent(matches[1]) : undefined;
}
