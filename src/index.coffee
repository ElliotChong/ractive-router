events = require "./events"
isArray = require "lodash/lang/isArray"
isEqual = require "lodash/lang/isEqual"
isFunction = require "lodash/lang/isFunction"
isPlainObject = require "lodash/lang/isPlainObject"
isString = require "lodash/lang/isString"
merge = require "lodash/object/merge"
once = require "lodash/function/once"
page = undefined
Ractive = require "ractive"

# Ensure Page.js is only initialized once
initializePage = do ->
	isInitialized = false
	options = undefined

	(p_options) ->
		if isInitialized is true
			if Ractive.DEBUG is true and p_options? and not isEqual options, p_options
				console.warn "Page.js was initialized multiple times with different options"
				console.warn "In-Use Options:"
				console.warn options
				console.warn "Canceled Options:"
				console.warn p_options
			return

		page = require "page"

		isInitialized = true
		options = p_options

		if options?
			# Page.js doesn't have popState camel-cased for some reason
			options.popstate ?= options.popState
			delete options.popState

			# Page.js's `dispatch` can be a bit ambiguous, so proxying the more
			# descriptive `initialDispatch` to the `dispatch` property
			options.dispatch ?= options.initialDispatch
			delete options.initialDispatch

			# Override Page.js's default pushState functionality
			show = page.show.bind page
			page.show = (p_path, p_state, p_dispatch, p_push) ->
				show p_path, p_state, p_dispatch, p_push || options.pushState || options.pushstate

			# Always disable `dispatch` when an initial route is set since that
			# will be navigated to immediately
			if isString options.initialRoute
				options.dispatch = false

			# Set the router's base path when determining routes
			if isString options.base
				page.base options.base

		# Initialize Page.js
		page.start options

RouteContainer = Ractive.extend
	template: require "./template.html"

	data: ->
		defaultTitle: ""
		isLoading: true
		middleware: undefined # Array
		pageOptions: undefined # Object
		routes: undefined # Array
		routeContext: undefined # Object
		showContent: false

	computed:
		scope:
			get: ->
				scope = @get "routeContext.scope"

				if isFunction scope
					scope = scope.bind(@)()

				if not isPlainObject scope
					return

				return scope

		title:
			get: ->
				title = @get "routeContext.title"

				if isFunction title
					title = title.bind(@)()

				if not isString title
					return @get "defaultTitle"

				return title

	oninit: ->
		# Bail out if we're not in the DOM
		if not window?
			return

		@_super?.apply @, arguments

		options = @get "pageOptions"
		initializePage options

		# Parse and observe the routes
		@observe "routes", @parseRoutes

		# Attach a listener to the root Ractive instance for `navigate`
		@root.on "*.#{events.NAVIGATE} #{events.NAVIGATE}", @navigate

		# Immediately navigate to a specified route
		if isString options?.initialRoute
			@navigate options.initialRoute

	# Remove listeners attached to `this.root`
	onteardown: ->
		@_super?.apply @, arguments

		@root.off "*.#{events.NAVIGATE} #{events.NAVIGATE}", @navigate

	navigate: (p_event, p_path) ->
		if not p_path?
			if not isString p_event
				console.warn "A path wasn't passed to the `navigate` event handler."
				console.dir arguments
				return

			p_path = p_event
			p_event = null

		page.show p_path

	showContent: (p_component, p_context) ->
		# Hide the current content
		@set "showContent", false

		# Set the new route's context
		@set "routeContext", p_context

		# Extend the component with a given scope if applicable
		component = p_component
		scope = @get "scope"

		if component.extend? and scope?
			component = component.extend
				data: ->
					scope

		# Assign the component as the current content
		@components["route-content"] = component

		# Set the document's title if it's available
		if document?
			document.title = @get "title"

		# Disable any loader animations
		@set "isLoading", false

		# Show the newly set content
		@set "showContent", true

		@fire events.CONTENT_CHANGED

	preload: (p_path, p_context) ->
		page.show p_path, merge({ preload: true }, p_context), true, false

	parseRoutes: (p_routes) ->
		if not isArray p_routes
			return

		for routeDescriptor in p_routes
			@addRoute routeDescriptor.path, routeDescriptor

		# Show the current location
		page.show window.location.pathname + window.location.search + window.location.hash

	addRoute: (p_path, p_descriptor) ->
		# PageJS will call these methods when the path is changed
		middleware = [p_path]

		middleware.push (p_context, p_next) ->
			# Attach the `descriptor` to the context so that external
			# middleware have access as well
			p_context.routeDescriptor = p_descriptor

			# Attach the scope
			p_context.scope = p_context.routeDescriptor.scope

			# Attach the title
			p_context.title = p_context.routeDescriptor.title

			p_next()

		# Attach custom middleware passed to the Ractive instance
		instanceMiddleware = @get "middleware"
		if isArray instanceMiddleware
			for method in instanceMiddleware
				middleware.push method.bind @

		# Add any custom middleware in the format of `(p_context, p_next) ->`
		if p_descriptor.middleware?
			if isArray p_descriptor.middleware
				# Iterate through the supplied middleware and bind `this` to the current scope
				for method in p_descriptor.middleware
					middleware.push method.bind @

			else if isFunction p_descriptor.middleware
				middleware.push p_descriptor.middleware.bind @

			else
				throw new Error "Unknown middleware specified: #{p_descriptor.middleware}"

		# Show the new content via Ractive
		middleware.push (p_context) =>
			if p_context.preload is true or p_context.state.preload is true
				return

			component = p_context.component || p_context.routeDescriptor.component

			if not component?
				throw new Error "A `component` property is required to parse a route:\n#{JSON.stringify p_context.routeDescriptor, null, 4}\n#{JSON.stringify p_context, null, 4}"

			@showContent component, p_context

		page.apply null, middleware

RouteContainer.events = events

module.exports = RouteContainer
