module.exports = (grunt) ->
	grunt.loadNpmTasks "grunt-notify"

	require('load-grunt-config') grunt, jitGrunt:
		staticMappings:
			changelog: "grunt-conventional-changelog"
