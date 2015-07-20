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
test "RactiveRouter's events are defined", (p_assert) ->
	p_assert.ok RactiveRouter.events
	p_assert.ok RactiveRouter.events.NAVIGATE
	p_assert.ok RactiveRouter.events.CONTENT_CHANGED

	p_assert.end()

# Browser-Centric Tests
if isBrowser
	test "Content is displayed", (p_assert) ->
		ractive = new TestRactive
			data:
				routes: [
					{
						path: "/"
						component: Ractive.extend
							template: "foo"
					}
				]

		p_assert.equal ractive.toHTML(), "foo"

		p_assert.end()
