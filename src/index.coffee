events = require "./events"
isArray = require "lodash/lang/isArray"
isEqual = require "lodash/lang/isEqual"
isFunction = require "lodash/lang/isFunction"
isPlainObject = require "lodash/lang/isPlainObject"
isString = require "lodash/lang/isString"
clone = require "lodash/lang/clone"
assign = require "lodash/object/assign"
merge = require "lodash/object/merge"
once = require "lodash/function/once"
page = undefined
qs = require "qs"
Ractive = require "ractive"
Promise = Ractive.Promise

# Ensure Page.js is only initialized once
globalOptions = undefined

initializePage = do ->
	isInitialized = false
	passedOptions = undefined

	(p_options) ->
		if isInitialized is true
			if Ractive.DEBUG is true and p_options? and not isEqual passedOptions, p_options
				console.warn "Page.js was initialized multiple times with different options"
				console.warn "In-Use Options:"
				console.warn passedOptions
				console.warn "Canceled Options:"
				console.warn p_options
			return

		page = require "page"

		isInitialized = true
		passedOptions = p_options
		globalOptions = if p_options? then clone(p_options) else undefined

		if globalOptions?
			# Page.js doesn't have popState camel-cased for some reason
			if globalOptions.popState? and not globalOptions.popstate?
				globalOptions.popstate = globalOptions.popState

			delete globalOptions.popState

			if globalOptions.pushState? and not globalOptions.pushstate?
				globalOptions.pushstate = globalOptions.pushState

			delete globalOptions.pushState

			# Override Page.js's default pushState functionality
			show = page.show.bind page
			page.show = (p_path, p_state, p_dispatch, p_push) ->
				show p_path, p_state, p_dispatch, p_push || globalOptions.pushstate

			# Set the router's base path when determining routes
			if isString globalOptions.base
				page.base globalOptions.base
		else
			globalOptions = {}

		# Default to disabling `dispatch` since the routes haven't been initialized yet
		globalOptions.dispatch = false

		# Initialize Page.js
		page.start globalOptions

# Override Page.js's `dispatch` befhavior to optionall accept an
# Array of callbacks
selectiveDispatch = (p_context, p_callbacks) ->
	i = 0
	j = 0
	p_callbacks ?= page.callbacks

	nextEnter = ->
		method = p_callbacks[i++]

		if p_context.path isnt page.current
			p_context.handled = false
			return

		if not method?
			return

		method p_context, nextEnter

	nextEnter()

# Remove the specified callback from Page.js
removeCallback = (p_callback, p_collection) ->
	if not p_collection?
		throw new Error "`collection` is a required parameter."

	index = p_collection.indexOf p_callback

	if index is -1
		throw new Error "Expected callback to exist in collection"

	# Remove callbacks which were added by this instance
	p_collection.splice index, 1

processPath = (p_path, p_callbacks) ->
	if not p_callbacks? and isArray p_path
		p_callbacks = p_path
		p_path = undefined

	# Show the current location
	p_path ?= if page.current?.length > 0
		page.current
	else if window?.location?
		window.location.pathname + window.location.search + window.location.hash
	else
		"/"

	context = new page.Context p_path
	selectiveDispatch.call page, context, p_callbacks

resolveScope = (p_scopes) ->
	if not p_scopes?
		return undefined

	if not isArray p_scopes
		p_scopes = [p_scopes]
	else if p_scopes.length is 0
		return undefined

	scopes = for scope in p_scopes
		if isFunction scope
			scope = scope.call @

		if not isPlainObject scope
			continue

		scope

	scopes.unshift {}

	assign.apply undefined, scopes

Router = Ractive.extend
	template: require "./template.html"

	data: ->
		defaultTitle: undefined
		isLoading: true
		middleware: undefined # Array
		pageOptions: undefined # Object
		routes: undefined # Array
		routeContext: undefined # Object
		currentComponent: undefined # Function
		showContent: false

	computed:
		scope:
			get: ->
				scopes = @get "scopes"
				resolveScope.call @, scopes

		scopes:
			get: ->
				@get "routeContext.instances.#{@_guid}.scopes"

		title:
			get: ->
				title = @get "routeContext.title"

				if isFunction title
					title = title.bind(@)()

				if not isString(title) or title?.length is 0
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
	onunrender: ->
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
		if p_path is Router.currentPath()
			return

		page.show p_path

	showContent: (p_component, p_context) ->
		isNewContent = true
		p_context.handled = true
		promise = Promise.resolve()

		# If the new component is different from the currently set component
		# then initialize the new component
		if p_component isnt @get "currentComponent"
			# Hide the current content
			promise = promise.then @set "showContent", false

			# Set the new route's context
			promise = promise.then @set "routeContext", p_context

			# Store the original component
			promise = promise.then @set "currentComponent", p_component

			# Extend the component with a given scope if applicable
			promise = promise.then new Promise (p_fulfill, p_reject) =>
				component = @get "currentComponent"
				scopes = @get "scopes"

				if not component.extend?
					return p_reject new Error "`component` didn't have the required method `extend`"

				component = component.extend
					oninit: ->
						@_super?.apply @, arguments

						if scopes?.length > 0
							@applyScopes @resolveScope scopes

					onteardown: ->
						@_super?.apply @, arguments

						@scope = undefined
						scopes = undefined

					resolveScope: (p_scopes) ->
						resolveScope.call @, p_scopes

					applyScope: (p_scope) ->
						@reset()
						@scope = p_scope

						if p_scope?
							@set p_scope

				# Assign the component as the current content
				@components["route-content"] = component

				p_fulfill()

		# If the currently rendered component is the same as the new component
		# then instead of re-initializing it check if the scope has changed
		# and if so then apply it to the component
		else
			isNewContent = false

			if @get("showContent") is false
				promise = promise.then @set "showContent", true
				isNewContent = true

			# Set the new context
			if p_context isnt @get "routeContext"
				promise = promise.then @set "routeContext", p_context

			promise = promise.then new Promise (p_fulfill, p_reject) =>
				instance = @findComponent "route-content"

				if not instance?
					return p_reject new Error "A `route-content` instance wasn't found."

				scope = instance.resolveScope @get "scopes"

				if not isEqual scope, instance.scope
					instance.applyScope scope
					isNewContent = true

				p_fulfill()

		# Set the document's title if it's available
		if document?
			title = @get "title"

			if title?
				document.title = title

		# Disable any loader animations
		if @get("isLoading") is true
			promise = promise.then @set "isLoading", false

		# Show the newly set content
		if @get("showContent") is false
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

		# `parseRoutes` wasn't called via observer
		if not p_keypath? and not p_oldRoutes?
			p_oldRoutes = @get "routes"

		# Remove the current routes before applying the new routes
		if p_oldRoutes?.length > 0
			for route in p_oldRoutes
				@removeRoute route

		# Exit early
		if not isArray p_routes
			return

		callbacks = []
		for route in p_routes
			routeCallbacks = @addRoute route

			if isArray routeCallbacks
				callbacks = callbacks.concat routeCallbacks

		@set "callbacks", callbacks

		path = page.current

		# If `page.show` hasn't been called yet use that method, otherwise
		# just process the newly generated routes
		if not path? or path.length is 0
			path = if window?.location?
				window.location.pathname + window.location.search + window.location.hash
			else
				"/"

			page.show path
		else
			processPath path, callbacks

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
			p_context.finalize ?= (p_instance) ->
				if not p_instance?
					throw new Error "`instance` is a required parameter for finalize()"

				if p_instance._guid?
					p_instance = p_instance._guid

				p_context.instances[p_instance].finalized = true
				p_context.handled = true

			# Store instance-level data on the Context
			p_context.instances ?= {}
			p_context.instances[@_guid] ?=
				matches: 0
				finalized: false
				scopes: []

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
				p_context.instances[@_guid].scopes.push p_context.routeDescriptor.scope

			# Attach the title
			if p_context.routeDescriptor.title?
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
			component = p_context.component || p_context.routeDescriptor.component

			if p_descriptor.final is true or component?
				p_context.finalize @_guid

			# Allow asynchronously loaded content to be fetched but not displayed
			if p_context.preload is true or p_context.state.preload is true
				return p_next()

			if component?
				@showContent component, p_context

			p_next()

		initialLength = page.callbacks.length
		page.apply null, middleware
		page "*", (p_context, p_next) =>
			if p_context?.instances?[@_guid]?.finalized isnt true
				contentShown = @get "showContent"
				@set "showContent", false

				if contentShown is true
					@fire events.CONTENT_CHANGED

			if globalOptions.unhandledRedirect isnt true
				p_context.handled = true

			p_next()

		# Keep a reference to the created callbacks in case of teardown later
		callbacks = page.callbacks.slice initialLength

		p_descriptor._instances ?= {}
		p_descriptor._instances[@_guid] ?= callbacks: []
		p_descriptor._instances[@_guid].callbacks = p_descriptor._instances[@_guid].callbacks.concat callbacks
		return callbacks

	removeRoute: (p_descriptor) ->
		if not p_descriptor._instances?[@_guid]?
			return

		while p_descriptor._instances[@_guid].callbacks.length > 0
			callback = p_descriptor._instances[@_guid].callbacks.shift()
			removeCallback callback, page.callbacks

		delete p_descriptor._instances[@_guid]

Router.events = events

Router.currentPath = ->
	return page?.current

Ractive.components["router"] ?= Router

module.exports = Router
