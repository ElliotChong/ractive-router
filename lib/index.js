(function() {
  var Promise, Ractive, Router, assign, clone, events, globalOptions, initializePage, isArray, isEqual, isFunction, isPlainObject, isString, merge, once, page, processPath, qs, removeCallback, resolveScope, selectiveDispatch, _base;

  events = require("./events");

  isArray = require("lodash/lang/isArray");

  isEqual = require("lodash/lang/isEqual");

  isFunction = require("lodash/lang/isFunction");

  isPlainObject = require("lodash/lang/isPlainObject");

  isString = require("lodash/lang/isString");

  clone = require("lodash/lang/clone");

  assign = require("lodash/object/assign");

  merge = require("lodash/object/merge");

  once = require("lodash/function/once");

  page = void 0;

  qs = require("qs");

  Ractive = require("ractive");

  Promise = Ractive.Promise;

  globalOptions = void 0;

  initializePage = (function() {
    var isInitialized, passedOptions;
    isInitialized = false;
    passedOptions = void 0;
    return function(p_options) {
      var show;
      if (isInitialized === true) {
        if (Ractive.DEBUG === true && (p_options != null) && !isEqual(passedOptions, p_options)) {
          console.warn("Page.js was initialized multiple times with different options");
          console.warn("In-Use Options:");
          console.warn(passedOptions);
          console.warn("Canceled Options:");
          console.warn(p_options);
        }
        return;
      }
      page = require("page");
      isInitialized = true;
      passedOptions = p_options;
      globalOptions = p_options != null ? clone(p_options) : void 0;
      if (globalOptions != null) {
        if ((globalOptions.popState != null) && (globalOptions.popstate == null)) {
          globalOptions.popstate = globalOptions.popState;
        }
        delete globalOptions.popState;
        if ((globalOptions.pushState != null) && (globalOptions.pushstate == null)) {
          globalOptions.pushstate = globalOptions.pushState;
        }
        delete globalOptions.pushState;
        show = page.show.bind(page);
        page.show = function(p_path, p_state, p_dispatch, p_push) {
          return show(p_path, p_state, p_dispatch, p_push || globalOptions.pushstate);
        };
        if (isString(globalOptions.base)) {
          page.base(globalOptions.base);
        }
      } else {
        globalOptions = {};
      }
      globalOptions.dispatch = false;
      return page.start(globalOptions);
    };
  })();

  selectiveDispatch = function(p_context, p_callbacks) {
    var i, j, nextEnter;
    i = 0;
    j = 0;
    if (p_callbacks == null) {
      p_callbacks = page.callbacks;
    }
    nextEnter = function() {
      var method;
      method = p_callbacks[i++];
      if (p_context.path !== page.current) {
        p_context.handled = false;
        return;
      }
      if (method == null) {
        return;
      }
      return method(p_context, nextEnter);
    };
    return nextEnter();
  };

  removeCallback = function(p_callback, p_collection) {
    var index;
    if (p_collection == null) {
      throw new Error("`collection` is a required parameter.");
    }
    index = p_collection.indexOf(p_callback);
    if (index === -1) {
      throw new Error("Expected callback to exist in collection");
    }
    return p_collection.splice(index, 1);
  };

  processPath = function(p_path, p_callbacks) {
    var context, _ref;
    if ((p_callbacks == null) && isArray(p_path)) {
      p_callbacks = p_path;
      p_path = void 0;
    }
    if (p_path == null) {
      p_path = ((_ref = page.current) != null ? _ref.length : void 0) > 0 ? page.current : (typeof window !== "undefined" && window !== null ? window.location : void 0) != null ? window.location.pathname + window.location.search + window.location.hash : "/";
    }
    context = new page.Context(p_path);
    return selectiveDispatch.call(page, context, p_callbacks);
  };

  resolveScope = function(p_scopes) {
    var scope, scopes;
    if (p_scopes == null) {
      return void 0;
    }
    if (!isArray(p_scopes)) {
      p_scopes = [p_scopes];
    } else if (p_scopes.length === 0) {
      return void 0;
    }
    scopes = (function() {
      var _i, _len, _results;
      _results = [];
      for (_i = 0, _len = p_scopes.length; _i < _len; _i++) {
        scope = p_scopes[_i];
        if (isFunction(scope)) {
          scope = scope.call(this);
        }
        if (!isPlainObject(scope)) {
          continue;
        }
        _results.push(scope);
      }
      return _results;
    }).call(this);
    scopes.unshift({});
    return assign.apply(void 0, scopes);
  };

  Router = Ractive.extend({
    template: {"v":3,"t":[{"t":4,"f":[{"t":7,"e":"route-content"}],"r":".showContent"}]},
    data: function() {
      return {
        defaultTitle: void 0,
        isLoading: true,
        middleware: void 0,
        pageOptions: void 0,
        routes: void 0,
        routeContext: void 0,
        currentComponent: void 0,
        showContent: false,
        finalizeCallback: void 0
      };
    },
    computed: {
      scope: {
        get: function() {
          var scopes;
          scopes = this.get("scopes");
          return resolveScope.call(this, scopes);
        }
      },
      scopes: {
        get: function() {
          return this.get("routeContext.instances." + this._guid + ".scopes");
        }
      },
      title: {
        get: function() {
          var title;
          title = this.get("routeContext.title");
          if (isFunction(title)) {
            title = title.bind(this)();
          }
          if (!isString(title) || (title != null ? title.length : void 0) === 0) {
            return this.get("defaultTitle");
          }
          return title;
        }
      }
    },
    oninit: function() {
      var options, _ref, _ref1;
      if ((_ref = this._super) != null) {
        _ref.apply(this, arguments);
      }
      if (typeof window === "undefined" || window === null) {
        return;
      }
      if ((_ref1 = this._super) != null) {
        _ref1.apply(this, arguments);
      }
      options = this.get("pageOptions");
      initializePage(options);
      this.observe("routes", this.parseRoutes);
      this.navigate = this.navigate.bind(this);
      this.root.on("*." + events.NAVIGATE + " " + events.NAVIGATE, this.navigate);
      if (isString(options != null ? options.initialRoute : void 0)) {
        return this.navigate(options.initialRoute);
      }
    },
    onunrender: function() {
      var finalizeCallback, routeDescriptor, routes, _i, _len, _ref;
      if ((_ref = this._super) != null) {
        _ref.apply(this, arguments);
      }
      this.root.off("*." + events.NAVIGATE + " " + events.NAVIGATE, this.navigate);
      routes = this.get("routes");
      if ((routes != null ? routes.length : void 0) > 0) {
        for (_i = 0, _len = routes.length; _i < _len; _i++) {
          routeDescriptor = routes[_i];
          this.removeRoute(routeDescriptor);
        }
      }
      finalizeCallback = this.get("finalizeCallback");
      if (finalizeCallback != null) {
        removeCallback(finalizeCallback, page.callbacks);
        return removeCallback(finalizeCallback, this.get("callbacks"));
      }
    },
    _wrapMiddleware: function(p_middleware) {
      return (function(_this) {
        return function(p_context, p_next) {
          var instance, _ref;
          instance = (_ref = p_context.instances) != null ? _ref[_this._guid] : void 0;
          if ((instance == null) || instance.finalized === true) {
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
      if (p_path === Router.currentPath()) {
        return;
      }
      return page.show(p_path);
    },
    showContent: function(p_component, p_context) {
      var isNewContent, promise, title;
      isNewContent = true;
      p_context.handled = true;
      promise = Promise.resolve();
      if (p_component !== this.get("currentComponent")) {
        promise = promise.then(this.set("showContent", false));
        promise = promise.then(this.set("routeContext", p_context));
        promise = promise.then(this.set("currentComponent", p_component));
        promise = promise.then(new Promise((function(_this) {
          return function(p_fulfill, p_reject) {
            var component, scopes;
            component = _this.get("currentComponent");
            scopes = _this.get("scopes");
            if (component.extend == null) {
              return p_reject(new Error("`component` didn't have the required method `extend`"));
            }
            component = component.extend({
              oninit: function() {
                var _ref;
                if ((scopes != null ? scopes.length : void 0) > 0) {
                  this.applyScope(this.resolveScope(scopes));
                }
                return (_ref = this._super) != null ? _ref.apply(this, arguments) : void 0;
              },
              onunrender: function() {
                var _ref;
                this.scope = void 0;
                scopes = void 0;
                return (_ref = this._super) != null ? _ref.apply(this, arguments) : void 0;
              },
              resolveScope: function(p_scopes) {
                return resolveScope.call(this, p_scopes);
              },
              applyScope: function(p_scope) {
                this.scope = p_scope;
                if (p_scope != null) {
                  return this.set(p_scope);
                }
              }
            });
            _this.components["route-content"] = component;
            return p_fulfill();
          };
        })(this)));
      } else {
        isNewContent = false;
        if (this.get("showContent") === false) {
          promise = promise.then(this.set("showContent", true));
          isNewContent = true;
        }
        if (p_context !== this.get("routeContext")) {
          promise = promise.then(this.set("routeContext", p_context));
        }
        promise = promise.then(new Promise((function(_this) {
          return function(p_fulfill, p_reject) {
            var instance, scope;
            instance = _this.findComponent("route-content");
            if (instance == null) {
              return p_reject(new Error("A `route-content` instance wasn't found."));
            }
            scope = instance.resolveScope(_this.get("scopes"));
            if (!isEqual(scope, instance.scope)) {
              instance.applyScope(scope);
              isNewContent = true;
            }
            return p_fulfill();
          };
        })(this)));
      }
      if (typeof document !== "undefined" && document !== null) {
        title = this.get("title");
        if (title != null) {
          document.title = title;
        }
      }
      if (this.get("isLoading") === true) {
        promise = promise.then(this.set("isLoading", false));
      }
      if (this.get("showContent") === false) {
        promise = promise.then(this.set("showContent", true));
      }
      return promise.then(new Promise((function(_this) {
        return function(p_fulfill, p_reject) {
          if (isNewContent !== false) {
            _this.fire(events.CONTENT_CHANGED);
          }
          return p_fulfill(isNewContent);
        };
      })(this)));
    },
    preload: function(p_path, p_context) {
      return page.show(p_path, merge({
        preload: true
      }, p_context), true, false);
    },
    parseRoutes: function(p_routes, p_oldRoutes, p_keypath) {
      var callbacks, finalizeCallback, path, route, routeCallbacks, _i, _j, _len, _len1;
      if ((p_keypath != null) && p_keypath !== "routes") {
        return;
      }
      if ((p_keypath == null) && (p_oldRoutes == null)) {
        p_oldRoutes = this.get("routes");
      }
      if ((p_oldRoutes != null ? p_oldRoutes.length : void 0) > 0) {
        for (_i = 0, _len = p_oldRoutes.length; _i < _len; _i++) {
          route = p_oldRoutes[_i];
          this.removeRoute(route);
        }
      }
      if (!isArray(p_routes)) {
        return;
      }
      callbacks = [];
      for (_j = 0, _len1 = p_routes.length; _j < _len1; _j++) {
        route = p_routes[_j];
        routeCallbacks = this.addRoute(route);
        if (isArray(routeCallbacks)) {
          callbacks = callbacks.concat(routeCallbacks);
        }
      }
      finalizeCallback = this.get("finalizeCallback");
      if (finalizeCallback != null) {
        removeCallback(finalizeCallback, page.callbacks);
        page.callbacks.push(finalizeCallback);
      } else {
        page("*", (function(_this) {
          return function(p_context, p_next) {
            var contentShown, _ref, _ref1;
            if ((p_context != null ? (_ref = p_context.instances) != null ? (_ref1 = _ref[_this._guid]) != null ? _ref1.finalized : void 0 : void 0 : void 0) !== true) {
              contentShown = _this.get("showContent");
              _this.set("showContent", false);
              if (contentShown === true) {
                _this.fire(events.CONTENT_CHANGED);
              }
            }
            if (globalOptions.unhandledRedirect !== true) {
              p_context.handled = true;
            }
            return p_next();
          };
        })(this));
        finalizeCallback = page.callbacks.slice(-1)[0];
        this.set("finalizeCallback", finalizeCallback);
      }
      callbacks.push(finalizeCallback);
      this.set("callbacks", callbacks);
      this.set("finalizeCallback", finalizeCallback);
      path = page.current;
      if ((path == null) || path.length === 0) {
        path = (typeof window !== "undefined" && window !== null ? window.location : void 0) != null ? window.location.pathname + window.location.search + window.location.hash : "/";
        return page.show(path);
      } else {
        return processPath(path, callbacks);
      }
    },
    addRoute: function(p_descriptor) {
      var callbacks, initialLength, instanceMiddleware, method, middleware, _base, _i, _j, _len, _len1, _name, _ref;
      if (p_descriptor == null) {
        throw new Error("A descriptor is required to add a route.");
      }
      if ((p_descriptor.path == null) || p_descriptor.path.length === 0) {
        throw new Error("`path` is a required property of a route descriptor.");
      }
      if (p_descriptor.final == null) {
        p_descriptor.final = p_descriptor.isFinal;
      }
      delete p_descriptor.isFinal;
      middleware = [p_descriptor.path];
      middleware.push((function(_this) {
        return function(p_context, p_next) {
          var index, key, param, value, _base, _i, _len, _name, _ref, _ref1, _ref2;
          if (p_context.finalize == null) {
            p_context.finalize = function(p_instance) {
              if (p_instance == null) {
                throw new Error("`instance` is a required parameter for finalize()");
              }
              if (p_instance._guid != null) {
                p_instance = p_instance._guid;
              }
              p_context.instances[p_instance].finalized = true;
              return p_context.handled = true;
            };
          }
          if (p_context.instances == null) {
            p_context.instances = {};
          }
          if ((_base = p_context.instances)[_name = _this._guid] == null) {
            _base[_name] = {
              matches: 0,
              finalized: false,
              scopes: []
            };
          }
          p_context.instances[_this._guid].matches++;
          if (p_context.instances[_this._guid].finalized === true) {
            return p_next();
          }
          if (((_ref = p_context.querystring) != null ? _ref.length : void 0) > 0) {
            if (p_context.query == null) {
              p_context.query = qs.parse(p_context.querystring);
            }
          } else {
            p_context.query = {};
          }
          p_context.routeDescriptor = p_descriptor;
          if (p_context.routeDescriptor.scope != null) {
            p_context.instances[_this._guid].scopes.push(p_context.routeDescriptor.scope);
          }
          if (p_context.routeDescriptor.title != null) {
            p_context.title = p_context.routeDescriptor.title;
          }
          if (p_context.routeDescriptor.params != null) {
            if (isArray(p_context.routeDescriptor.params)) {
              _ref1 = p_context.routeDescriptor.params;
              for (index = _i = 0, _len = _ref1.length; _i < _len; index = ++_i) {
                param = _ref1[index];
                if (!isString(param)) {
                  continue;
                }
                p_context.params[param] = p_context.params[index];
              }
            } else if (isPlainObject(p_context.routeDescriptor.params)) {
              _ref2 = p_context.routeDescriptor.params;
              for (key in _ref2) {
                value = _ref2[key];
                if (!isString(value)) {
                  continue;
                }
                p_context.params[value] = p_context.params[key];
              }
            }
          }
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
        component = p_context.component || p_context.routeDescriptor.component;
        if (p_descriptor.final === true || (component != null)) {
          p_context.finalize(this._guid);
        }
        if (p_context.preload === true || p_context.state.preload === true) {
          return p_next();
        }
        if (component != null) {
          this.showContent(component, p_context);
        }
        return p_next();
      }));
      initialLength = page.callbacks.length;
      page.apply(null, middleware);
      callbacks = page.callbacks.slice(initialLength);
      if (p_descriptor._instances == null) {
        p_descriptor._instances = {};
      }
      if ((_base = p_descriptor._instances)[_name = this._guid] == null) {
        _base[_name] = {
          callbacks: []
        };
      }
      p_descriptor._instances[this._guid].callbacks = p_descriptor._instances[this._guid].callbacks.concat(callbacks);
      return callbacks;
    },
    removeRoute: function(p_descriptor) {
      var callback, callbacks, _ref;
      if (((_ref = p_descriptor._instances) != null ? _ref[this._guid] : void 0) == null) {
        return;
      }
      callbacks = this.get("callbacks");
      while (p_descriptor._instances[this._guid].callbacks.length > 0) {
        callback = p_descriptor._instances[this._guid].callbacks.shift();
        removeCallback(callback, page.callbacks);
        removeCallback(callback, callbacks);
      }
      return delete p_descriptor._instances[this._guid];
    }
  });

  Router.events = events;

  Router.currentPath = function() {
    return page != null ? page.current : void 0;
  };

  if ((_base = Ractive.components)["router"] == null) {
    _base["router"] = Router;
  }

  module.exports = Router;

}).call(this);
