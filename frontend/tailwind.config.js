module.exports = {
	purge: ['./src/**/*.svelte', './src/**/*.html'],
	theme: {
		extend: {},
	},
	variants: {},
	plugins: [require('@tailwindcss/ui')],
};
