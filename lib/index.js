(function() {
  var Ractive, RouteContainer, events, initializePage, isArray, isEqual, isFunction, isPlainObject, isString, merge, once, page;

  events = require("./events");

  isArray = require("lodash/lang/isArray");

  isEqual = require("lodash/lang/isEqual");

  isFunction = require("lodash/lang/isFunction");

  isPlainObject = require("lodash/lang/isPlainObject");

  isString = require("lodash/lang/isString");

  merge = require("lodash/object/merge");

  once = require("lodash/function/once");

  page = void 0;

  Ractive = require("ractive");

  initializePage = (function() {
    var isInitialized, options;
    isInitialized = false;
    options = void 0;
    return function(p_options) {
      var show;
      if (isInitialized === true) {
        if (Ractive.DEBUG === true && (p_options != null) && !isEqual(options, p_options)) {
          console.warn("Page.js was initialized multiple times with different options");
          console.warn("In-Use Options:");
          console.warn(options);
          console.warn("Canceled Options:");
          console.warn(p_options);
        }
        return;
      }
      page = require("page");
      isInitialized = true;
      options = p_options;
      if (options != null) {
        if (options.popstate == null) {
          options.popstate = options.popState;
        }
        delete options.popState;
        if (options.dispatch == null) {
          options.dispatch = options.initialDispatch;
        }
        delete options.initialDispatch;
        show = page.show.bind(page);
        page.show = function(p_path, p_state, p_dispatch, p_push) {
          return show(p_path, p_state, p_dispatch, p_push || options.pushState || options.pushstate);
        };
        if (isString(options.initialRoute)) {
          options.dispatch = false;
        }
        if (isString(options.base)) {
          page.base(options.base);
        }
      }
      return page.start(options);
    };
  })();

  RouteContainer = Ractive.extend({
    template: {"v":3,"t":[{"t":4,"f":[{"t":7,"e":"route-content"}],"r":".showContent"}]},
    data: function() {
      return {
        defaultTitle: "",
        isLoading: true,
        middleware: void 0,
        pageOptions: void 0,
        routes: void 0,
        routeContext: void 0,
        showContent: false
      };
    },
    computed: {
      currentPath: {
        get: function() {
          return page != null ? page.current : void 0;
        }
      },
      scope: {
        get: function() {
          var scope;
          scope = this.get("routeContext.scope");
          if (isFunction(scope)) {
            scope = scope.bind(this)();
          }
          if (!isPlainObject(scope)) {
            return;
          }
          return scope;
        }
      },
      title: {
        get: function() {
          var title;
          title = this.get("routeContext.title");
          if (isFunction(title)) {
            title = title.bind(this)();
          }
          if (!isString(title)) {
            return this.get("defaultTitle");
          }
          return title;
        }
      }
    },
    oninit: function() {
      var options, _ref;
      if (typeof window === "undefined" || window === null) {
        return;
      }
      if ((_ref = this._super) != null) {
        _ref.apply(this, arguments);
      }
      options = this.get("pageOptions");
      initializePage(options);
      this.observe("routes", this.parseRoutes);
      this.root.on("*." + events.NAVIGATE + " " + events.NAVIGATE, this.navigate);
      if (isString(options != null ? options.initialRoute : void 0)) {
        return this.navigate(options.initialRoute);
      }
    },
    onteardown: function() {
      var _ref;
      if ((_ref = this._super) != null) {
        _ref.apply(this, arguments);
      }
      return this.root.off("*." + events.NAVIGATE + " " + events.NAVIGATE, this.navigate);
    },
    _wrapMiddleware: function(p_middleware) {
      return (function(_this) {
        return function(p_context, p_next) {
          if (p_context.instances[_this._guid].finalized === true) {
            return p_next();
          }
          return p_middleware.apply(_this, arguments);
        };
      })(this);
    },
    navigate: function(p_event, p_path) {
      if (p_path == null) {
        if (!isString(p_event)) {
          console.warn("A path wasn't passed to the `navigate` event handler.");
          console.dir(arguments);
          return;
        }
        p_path = p_event;
        p_event = null;
      }
      return page.show(p_path);
    },
    showContent: function(p_component, p_context) {
      var component, scope;
      this.set("showContent", false);
      this.set("routeContext", p_context);
      component = p_component;
      scope = this.get("scope");
      if ((component.extend != null) && (scope != null)) {
        component = component.extend({
          data: function() {
            return scope;
          }
        });
      }
      this.components["route-content"] = component;
      if (typeof document !== "undefined" && document !== null) {
        document.title = this.get("title");
      }
      this.set("isLoading", false);
      this.set("showContent", true);
      return this.fire(events.CONTENT_CHANGED);
    },
    preload: function(p_path, p_context) {
      return page.show(p_path, merge({
        preload: true
      }, p_context), true, false);
    },
    parseRoutes: function(p_routes) {
      var routeDescriptor, _i, _len;
      if (!isArray(p_routes)) {
        return;
      }
      for (_i = 0, _len = p_routes.length; _i < _len; _i++) {
        routeDescriptor = p_routes[_i];
        this.addRoute(routeDescriptor.path, routeDescriptor);
      }
      return page.show(window.location.pathname + window.location.search + window.location.hash);
    },
    addRoute: function(p_path, p_descriptor) {
      var instanceMiddleware, method, middleware, _i, _j, _len, _len1, _ref;
      if (p_descriptor.final == null) {
        p_descriptor.final = p_descriptor.isFinal;
      }
      delete p_descriptor.isFinal;
      middleware = [p_path];
      middleware.push((function(_this) {
        return function(p_context, p_next) {
          var _base, _name;
          if (p_context.instances == null) {
            p_context.instances = {};
          }
          if ((_base = p_context.instances)[_name = _this._guid] == null) {
            _base[_name] = {
              matches: 0,
              finalized: false
            };
          }
          p_context.instances[_this._guid].matches++;
          if (p_context.instances[_this._guid].finalized === true) {
            return p_next();
          }
          p_context.routeDescriptor = p_descriptor;
          p_context.scope = p_context.routeDescriptor.scope;
          p_context.title = p_context.routeDescriptor.title;
          return p_next();
        };
      })(this));
      instanceMiddleware = this.get("middleware");
      if (isArray(instanceMiddleware)) {
        for (_i = 0, _len = instanceMiddleware.length; _i < _len; _i++) {
          method = instanceMiddleware[_i];
          middleware.push(this._wrapMiddleware(method));
        }
      } else if (isFunction(instanceMiddleware)) {
        middleware.push(this._wrapMiddleware(instanceMiddleware));
      }
      if (p_descriptor.middleware != null) {
        if (isArray(p_descriptor.middleware)) {
          _ref = p_descriptor.middleware;
          for (_j = 0, _len1 = _ref.length; _j < _len1; _j++) {
            method = _ref[_j];
            middleware.push(this._wrapMiddleware(method));
          }
        } else if (isFunction(p_descriptor.middleware)) {
          middleware.push(this._wrapMiddleware(p_descriptor.middleware));
        } else {
          throw new Error("Unknown middleware specified: " + p_descriptor.middleware);
        }
      }
      middleware.push(this._wrapMiddleware(function(p_context, p_next) {
        var component;
        if (p_descriptor.final === true) {
          p_context.instances[this._guid].finalized = true;
        }
        if (p_context.preload === true || p_context.state.preload === true) {
          return p_next();
        }
        component = p_context.component || p_context.routeDescriptor.component;
        if (component != null) {
          this.showContent(component, p_context);
        }
        return p_next();
      }));
      return page.apply(null, middleware);
    }
  });

  RouteContainer.events = events;

  module.exports = RouteContainer;

}).call(this);
