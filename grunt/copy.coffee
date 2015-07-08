module.exports = (grunt, options) ->
	build:
		files: [
			{
				expand: true
				src: ["**/*", "!**/*.coffee"]
				cwd: "src/"
				dest: "lib/"
				filter: "isFile"
			}
		]
