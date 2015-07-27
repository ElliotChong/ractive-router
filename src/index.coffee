events = require "./events"
isArray = require "lodash/lang/isArray"
isEqual = require "lodash/lang/isEqual"
isFunction = require "lodash/lang/isFunction"
isPlainObject = require "lodash/lang/isPlainObject"
isString = require "lodash/lang/isString"
merge = require "lodash/object/merge"
once = require "lodash/function/once"
page = undefined
qs = require "qs"
Ractive = require "ractive"
Promise = Ractive.Promise

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

# Remove the specified callback from Page.js
removeCallback = (p_callback) ->
	if not page?
		throw new Error "Page.js cannot have callbacks removed if it hasn't been initialized yet."

	index = page.callbacks.indexOf p_callback

	if index is -1
		throw new Error "Expected callback to exist in Page.js"

	# Remove callbacks which were added by this instance
	page.callbacks.splice index, 1

showCurrent = ->
	# Show the current location
	if page.current?.length > 0
		page.show page.current
	else if window?.location?
		page.show window.location.pathname + window.location.search + window.location.hash

RouteContainer = Ractive.extend
	template: require "./template.html"

	data: ->
		defaultTitle: undefined
		isLoading: true
		middleware: undefined # Array
		pageOptions: undefined # Object
		routes: undefined # Array
		routeContext: undefined # Object
		showContent: false

	computed:
		# The current path being processed
		currentPath:
			get: ->
				RouteContainer.currentPath()

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
		@_super?.apply @, arguments

		# Bail out if we're not in the DOM
		if not window?
			return

		@_super?.apply @, arguments

		options = @get "pageOptions"
		initializePage options

		# Parse and observe the routes
		@observe "routes", @parseRoutes

		# Attach a listener to the root Ractive instance for `navigate`
		@navigate = @navigate.bind @
		@root.on "*.#{events.NAVIGATE} #{events.NAVIGATE}", @navigate

		# Immediately navigate to a specified route
		if isString options?.initialRoute
			@navigate options.initialRoute

	# Remove listeners attached to `this.root`
	onteardown: ->
		@_super?.apply @, arguments

		@root.off "*.#{events.NAVIGATE} #{events.NAVIGATE}", @navigate

		routes = @get "routes"
		if routes?.length > 0
			for routeDescriptor in routes
				@removeRoute routeDescriptor

	# Wrap all middleware in a finalized check for early exits
	_wrapMiddleware: (p_middleware) ->
		(p_context, p_next) =>
			# If the current Ractive-Router instance has been finalized exit immediately
			instance = p_context.instances?[@_guid]
			if not instance? or instance.finalized is true
				return p_next()

			p_middleware.apply @, arguments

	# Update the router to a new location
	navigate: (p_event, p_path) ->
		if not p_path?
			if not isString p_event
				console.warn "A path wasn't passed to the `navigate` event handler."
				console.dir arguments
				return

			p_path = p_event
			p_event = null

		# If the current path has already been handled exit early
		if p_path is @get "currentPath"
			return

		page.show p_path

	showContent: (p_component, p_context) ->
		isNewContent = true
		promise = Promise.resolve()

		if p_component isnt @components["route-content"]
			# Hide the current content
			promise = promise.then @set "showContent", false

			# Set the new route's context
			promise = promise.then @set "routeContext", p_context

			# Extend the component with a given scope if applicable
			promise = promise.then new Promise (p_fulfill, p_reject) =>
				component = p_component
				scope = @get "scope"

				if component.extend? and scope?
					component = component.extend
						data: ->
							scope

				# Assign the component as the current content
				@components["route-content"] = component

				p_fulfill()

		else if p_context isnt @get "routeContext"
			promise = promise.then @set "routeContext", p_context

		else
			isNewContent = false

		# Set the document's title if it's available
		if document?
			title = @get "title"

			if title?
				document.title = title

		# Disable any loader animations
		promise = promise.then @set "isLoading", false

		# Show the newly set content
		promise = promise.then @set "showContent", true

		promise.then new Promise (p_fulfill, p_reject) =>
			if isNewContent isnt false
				@fire events.CONTENT_CHANGED

			p_fulfill isNewContent

	preload: (p_path, p_context) ->
		page.show p_path, merge({ preload: true }, p_context), true, false

	parseRoutes: (p_routes, p_oldRoutes, p_keypath) ->
		# An update occurred that wasn't to the primary `routes` Array
		if p_keypath? and p_keypath isnt "routes"
			return

		p_oldRoutes ?= @get "routes"

		# Remove the current routes before applying the new routes
		if p_oldRoutes?.length > 0
			for route in p_oldRoutes
				@removeRoute route

		# Exit early
		if not isArray p_routes
			return

		for route in p_routes
			@addRoute route

		showCurrent()

	addRoute: (p_descriptor) ->
		if not p_descriptor?
			throw new Error "A descriptor is required to add a route."

		if not p_descriptor.path? or p_descriptor.path.length is 0
			throw new Error "`path` is a required property of a route descriptor."

		# Support `final` or `isFinal` properties
		p_descriptor.final ?= p_descriptor.isFinal
		delete p_descriptor.isFinal

		# PageJS will call these methods when the path is changed
		middleware = [p_descriptor.path]

		middleware.push (p_context, p_next) =>
			# Store instance-level data on the Context
			p_context.instances ?= {}
			p_context.instances[@_guid] ?=
				matches: 0
				finalized: false

			p_context.instances[@_guid].matches++

			# When an instance's route has been finalized future Ractive-Router
			# defined middleware will be skipped
			if p_context.instances[@_guid].finalized is true
				return p_next()

			# Parse the query string
			if p_context.querystring?.length > 0
				if not p_context.query?
					p_context.query = qs.parse p_context.querystring
			else
				p_context.query = {}

			# Attach the `descriptor` to the context so that external
			# middleware have access as well
			p_context.routeDescriptor = p_descriptor

			# Attach the scope
			if p_context.routeDescriptor.scope?
				p_context.scope = p_context.routeDescriptor.scope

			# Attach the title
			p_context.title = p_context.routeDescriptor.title

			# Alias parameters - Useful when working with RegExp paths
			# that contain capture groups
			if p_context.routeDescriptor.params?
				if isArray p_context.routeDescriptor.params
					for param, index in p_context.routeDescriptor.params
						if not isString param
							continue

						p_context.params[param] = p_context.params[index]
				else if isPlainObject p_context.routeDescriptor.params
					for key, value of p_context.routeDescriptor.params
						if not isString value
							continue

						p_context.params[value] = p_context.params[key]

			p_next()

		# Attach custom middleware passed to the Ractive instance
		instanceMiddleware = @get "middleware"
		if isArray instanceMiddleware
			for method in instanceMiddleware
				middleware.push @_wrapMiddleware method
		else if isFunction instanceMiddleware
			middleware.push @_wrapMiddleware instanceMiddleware

		# Add any custom middleware in the format of `(p_context, p_next) ->`
		if p_descriptor.middleware?
			if isArray p_descriptor.middleware
				# Iterate through the supplied middleware and bind `this` to
				# the current scope
				for method in p_descriptor.middleware
					middleware.push @_wrapMiddleware method

			else if isFunction p_descriptor.middleware
				middleware.push @_wrapMiddleware p_descriptor.middleware

			else
				throw new Error "Unknown middleware specified: #{p_descriptor.middleware}"

		# Show the new content via Ractive
		middleware.push @_wrapMiddleware (p_context, p_next) ->
			if p_descriptor.final is true
				p_context.instances[@_guid].finalized = true

			# Allow asynchronously loaded content to be fetched but not displayed
			if p_context.preload is true or p_context.state.preload is true
				return p_next()

			component = p_context.component || p_context.routeDescriptor.component

			if component?
				@showContent component, p_context

			p_next()

		initialLength = page.callbacks.length
		page.apply null, middleware

		# Keep a reference to the created callbacks in case of teardown later
		callbacks = page.callbacks.slice initialLength, -1

		p_descriptor._instances ?= {}
		p_descriptor._instances[@_guid] ?= callbacks: []
		p_descriptor._instances[@_guid].callbacks = p_descriptor._instances[@_guid].callbacks.concat callbacks
		return callbacks

	removeRoute: (p_descriptor) ->
		if not p_descriptor._instances?[@_guid]?
			return

		while p_descriptor._instances[@_guid].callbacks.length > 0
			removeCallback p_descriptor._instances[@_guid].callbacks.shift()

		delete p_descriptor._instances[@_guid]

RouteContainer.events = events

RouteContainer.currentPath = ->
	return page?.current

module.exports = RouteContainer
