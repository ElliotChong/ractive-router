test = require "tape"
Ractive = require "ractive"
RactiveRouter = require "../lib/"
isBrowser = window? and not window.process?

TestRactive = Ractive.extend
	template: "<ractive-router routes='{{routes}}' pageOptions='{{options}}'/>"

	components:
		"ractive-router": RactiveRouter

	navigate: (p_path) ->
		@fire RactiveRouter.events.NAVIGATE, p_path

# Global Tests
test "RactiveRouter's events are defined", (p_test) ->
	p_test.ok RactiveRouter.events
	p_test.ok RactiveRouter.events.NAVIGATE
	p_test.ok RactiveRouter.events.CONTENT_CHANGED

	p_test.end()

# Browser-Centric Tests
if isBrowser
	test "Content is displayed", (p_test) ->
		ractive = new TestRactive
			data:
				routes: [
					{
						path: "/"
						component: Ractive.extend
							template: "foo"
					}
				]

		p_test.equal ractive.toHTML(), "foo"

		p_test.end()
