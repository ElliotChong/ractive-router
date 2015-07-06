module.exports = (grunt, options) ->
	build:
		expand: true
		flatten: true
		cwd: "src"
		src: ["*.coffee"]
		dest: "lib/"
		ext: ".js"
