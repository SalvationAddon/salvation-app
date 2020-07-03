const util = require('util');
const exec = util.promisify(require('child_process').exec);

async function buildLua() {
	console.log('building..');
	try {
		await exec('luabundler bundle ./src/salvation.lua -p "./src/?.lua" -o ./build/salvation.lua;');
		console.log('LUA Compiled!');
	} catch (err) {
		console.log('failed to build lua: ', err);
	}
}
buildLua();
