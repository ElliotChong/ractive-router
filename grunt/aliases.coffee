module.exports = (grunt, options) ->
	default: ["build"]
	build: ["coffee:build", "notify:build"]
