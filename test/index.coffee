test = require "tape"
Ractive = require "ractive"
RactiveRouter = require "../lib/"
isBrowser = window? and not window.process?
defaultPath = "/"

cleanupRactive = ->
	for key, ractive of arguments
		element = ractive.el

		# Reset Ractive to the default path
		ractive.navigate defaultPath

		# Teardown the existing instance
		ractive.teardown()
		document.body.removeChild element

BaseTester = Ractive.extend
	template: "<router routes='{{routes}}' pageOptions='{{options}}'/>"

	data: ->
		options:
			hashbang: true
			pushstate: false
			popstate: false

	components:
		"router": RactiveRouter

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
	testId = 0

	createElement = ->
		div = document.createElement "div"
		div.id = "test-#{testId++}"
		document.body.appendChild div
		return div

	test "Content is displayed", (p_assert) ->
		ractive = new BaseTester
			el: createElement()
			data: ->
				routes: [
					{
						path: "/"
						component: Ractive.extend
							template: "foo"
					}
				]

		p_assert.equal ractive.toHTML(), "foo"

		cleanupRactive ractive
		p_assert.end()

	test "Nested routers", (p_assert) ->
		ractive = new BaseTester
			el: createElement()
			template: "Page: <router routes='{{routes}}' pageOptions='{{options}}'/>"
			data: ->
				routes: [
					{
						path: "/"
						component: Ractive.extend
							template: "Sub-page: <router routes='{{routes}}'/>"
							data: ->
								routes: [
									path: "/"
									component: Ractive.extend
										template: "{{callout}} :)"
										data: ->
											callout: "foo"
								]
							components:
								"router": RactiveRouter
					}
				]

		p_assert.equal ractive.toHTML(), "Page: Sub-page: foo :)"

		cleanupRactive ractive
		p_assert.end()

	test "Multiple nested routers", (p_assert) ->
		ractive = new BaseTester
			el: createElement()
			template: "Page: <router routes='{{routes}}' pageOptions='{{options}}'/>"
			data: ->
				routes: [
					{
						path: "/"
						component: Ractive.extend
							template: "Sub-page A: <router routes='{{routesA}}'/> Sub-page B: <router routes='{{routesB}}'/>"
							data: ->
								routesA: [
									path: "/"
									component: Ractive.extend
										template: "{{callout}}"
										data: ->
											callout: "foo"
								]
								routesB: [
									path: "/"
									component: Ractive.extend
										template: "{{callout}}"
										data: ->
											callout: "bar"
								]
							components:
								"router": RactiveRouter
					}
				]

		p_assert.equal ractive.toHTML(), "Page: Sub-page A: foo Sub-page B: bar"

		cleanupRactive ractive
		p_assert.end()

	test "Nested routers don't call the parent's routes on instantiation", (p_assert) ->
		parentMiddlewareCalled = 0

		ractive = new BaseTester
			el: createElement()
			template: "Page: <router routes='{{routes}}' pageOptions='{{options}}'/>"
			data: ->
				routes: [
					{
						path: "/"
						middleware: (p_context, p_next) ->
							parentMiddlewareCalled++

							p_next()
						component: Ractive.extend
							template: "Sub-page: <router routes='{{routes}}'/>"
							data: ->
								routes: [
									path: "/"
									component: Ractive.extend
										template: "{{callout}}"
										data: ->
											callout: "bar"
								]
							components:
								"router": RactiveRouter
					}
				]

		p_assert.equal parentMiddlewareCalled, 1
		p_assert.equal ractive.toHTML(), "Page: Sub-page: bar"

		cleanupRactive ractive
		p_assert.end()

	test "Navigating to other routes", (p_assert) ->
		ractive = new BaseTester
			el: createElement()
			data: ->
				routes: [
					{
						path: "/"
						component: Ractive.extend
							template: "foo"
					}
					{
						path: "/test"
						component: Ractive.extend
							template: "bar"
					}
				]

		p_assert.equal ractive.toHTML(), "foo"
		ractive.navigate "/test"
		p_assert.equal ractive.toHTML(), "bar"

		cleanupRactive ractive
		p_assert.end()

	test "Navigating to other sub-routes doesn't re-render the parent page", (p_assert) ->
		parentMiddlewareCalled = 0
		parentInitialized = 0
		parentRendered = 0
		childInitialized = 0
		childRendered = 0

		ractive = new BaseTester
			el: createElement()
			name: "Page (Root) Instance"
			template: "Page: <router routes='{{routes}}' pageOptions='{{options}}'/>"
			data: ->
				routes: [
					{
						path: /\/?test\/?(.*?)$/
						middleware: (p_context, p_next) ->
							parentMiddlewareCalled++

							p_next()
						component: Ractive.extend
							name: "Sub-Page Instance"
							template: "Sub-page: <router routes='{{routes}}'/>"
							data: ->
								routes: [
									path: "/test/foo"
									component: Ractive.extend
										name: "/test/foo Instance"
										template: "{{callout}} :)"
										data: ->
											callout: "foo"
										oninit: ->
											@_super?.apply @, arguments
											childInitialized++
										onrender: ->
											@_super?.apply @, arguments
											childRendered++
								]
							components:
								"router": RactiveRouter
							oninit: ->
								@_super?.apply @, arguments
								parentInitialized++
							onrender: ->
								@_super?.apply @, arguments
								parentRendered++
					}
				]

		p_assert.comment "Default render"
		p_assert.equal parentMiddlewareCalled, 0, "parentMiddlewareCalled"
		p_assert.equal parentInitialized, 0, "parentInitialized"
		p_assert.equal parentRendered, 0, "parentRendered"
		p_assert.equal childInitialized, 0, "childInitialized"
		p_assert.equal childRendered, 0, "childRendered"
		p_assert.equal ractive.el.innerHTML, ractive.toHTML(), "innerHTML == toHTML()"
		p_assert.equal ractive.toHTML(), "Page: ", "toHTML()"

		p_assert.comment "/test"
		ractive.navigate "/test"
		p_assert.equal parentMiddlewareCalled, 1, "parentMiddlewareCalled"
		p_assert.equal parentInitialized, 1, "parentInitialized"
		p_assert.equal parentRendered, 1, "parentRendered"
		p_assert.equal childInitialized, 0, "childInitialized"
		p_assert.equal childRendered, 0, "childRendered"
		p_assert.equal ractive.el.innerHTML, ractive.toHTML(), "innerHTML == toHTML()"
		p_assert.equal ractive.toHTML(), "Page: Sub-page: ", "toHTML()"

		p_assert.comment "/test/foo"
		ractive.navigate "/test/foo"
		p_assert.equal parentMiddlewareCalled, 2, "parentMiddlewareCalled"
		p_assert.equal parentInitialized, 1, "parentInitialized"
		p_assert.equal parentRendered, 1, "parentRendered"
		p_assert.equal childInitialized, 1, "childInitialized"
		p_assert.equal childRendered, 1, "childRendered"
		p_assert.equal ractive.el.innerHTML, ractive.toHTML(), "innerHTML == toHTML()"
		p_assert.equal ractive.toHTML(), "Page: Sub-page: foo :)", "toHTML()"

		p_assert.comment "/test/bar"
		ractive.navigate "/test/bar"
		p_assert.equal parentMiddlewareCalled, 3, "parentMiddlewareCalled"
		p_assert.equal parentInitialized, 1, "parentInitialized"
		p_assert.equal parentRendered, 1, "parentRendered"
		p_assert.equal childInitialized, 1, "childInitialized"
		p_assert.equal childRendered, 1, "childRendered"
		p_assert.equal ractive.el.innerHTML, ractive.toHTML(), "innerHTML == toHTML()"
		p_assert.equal ractive.toHTML(), "Page: Sub-page: ", "toHTML()"

		p_assert.comment "/test/foo"
		ractive.navigate "/test/foo"
		p_assert.equal parentMiddlewareCalled, 4, "parentMiddlewareCalled"
		p_assert.equal parentInitialized, 1, "parentInitialized"
		p_assert.equal parentRendered, 1, "parentRendered"
		p_assert.equal childInitialized, 2, "childInitialized"
		p_assert.equal childRendered, 2, "childRendered"
		p_assert.equal ractive.el.innerHTML, ractive.toHTML(), "innerHTML == toHTML()"
		p_assert.equal ractive.toHTML(), "Page: Sub-page: foo :)", "toHTML()"

		p_assert.comment "/"
		ractive.navigate "/"
		p_assert.equal parentMiddlewareCalled, 4, "parentMiddlewareCalled"
		p_assert.equal parentInitialized, 1, "parentInitialized"
		p_assert.equal parentRendered, 1, "parentRendered"
		p_assert.equal childInitialized, 2, "childInitialized"
		p_assert.equal childRendered, 2, "childRendered"
		p_assert.equal ractive.el.innerHTML, ractive.toHTML(), "innerHTML == toHTML()"
		p_assert.equal ractive.toHTML(), "Page: ", "toHTML()"

		p_assert.comment "/test/foo"
		ractive.navigate "/test/foo"
		p_assert.equal parentMiddlewareCalled, 5, "parentMiddlewareCalled"
		p_assert.equal parentInitialized, 2, "parentInitialized"
		p_assert.equal parentRendered, 2, "parentRendered"
		p_assert.equal childInitialized, 3, "childInitialized"
		p_assert.equal childRendered, 3, "childRendered"
		p_assert.equal ractive.el.innerHTML, ractive.toHTML(), "innerHTML == toHTML()"
		p_assert.equal ractive.toHTML(), "Page: Sub-page: foo :)", "toHTML()"

		cleanupRactive ractive
		p_assert.end()

	test "Data changes that occur in `oninit` are not overwritten when scope is absent", (p_assert) ->
		ractive = new BaseTester
			el: createElement()
			data: ->
				routes: [
					{
						path: "/"
						component: Ractive.extend
							template: "{{dynamicValue}}"
							data: ->
								dynamicValue: "bar"
							oninit: ->
								@_super?.apply @, arguments

								@set "dynamicValue", "foo"
					}
				]

		p_assert.equal ractive.toHTML(), "foo"

		cleanupRactive ractive
		p_assert.end()

	test "Data changes that occur in `oninit` are not overwritten when scope is present", (p_assert) ->
		ractive = new BaseTester
			el: createElement()
			data: ->
				routes: [
					{
						path: "/"
						scope: ->
							scopeValue: "scoped!"
						component: Ractive.extend
							template: "{{dynamicValue}} {{scopeValue}}"
							data: ->
								dynamicValue: "bar"
							oninit: ->
								@_super?.apply @, arguments

								@set "dynamicValue", "foo"
					}
				]

		p_assert.equal ractive.toHTML(), "foo scoped!"

		cleanupRactive ractive
		p_assert.end()

	test "Defining scope as a Function", (p_assert) ->
		ractive = new BaseTester
			el: createElement()
			template: "Page: <router routes='{{routes}}' pageOptions='{{options}}'/>"
			data: ->
				routes: [
					{
						path: /\/?test\/?(.*?)$/
						component: Ractive.extend
							template: "Sub-page: <router routes='{{routes}}'/>"
							data: ->
								routes: [
									path: "/test/foo"
									scope: ->
										test: "bar"
									component: Ractive.extend
										name: "/test/foo Instance"
										template: "{{callout}} {{test}} :)"
										data: ->
											callout: "foo"
								]
					}
				]

		ractive.navigate "/test/foo"
		p_assert.equal ractive.toHTML(), "Page: Sub-page: foo bar :)", "toHTML()"

		cleanupRactive ractive
		p_assert.end()
