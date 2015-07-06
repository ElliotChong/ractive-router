# Ractive Router

Display [Ractive](http://www.ractivejs.org/) components based on route.

**_WARNING: This is an Alpha release of Ractive Router. Tests and documentation are still in progress._**

## Installation

```bash
$ npm install ractive-router
```

## Usage

```JavaScript
var Ractive = require("ractive");

var ractive = new Ractive({
	template: "<page routes='{{routes}}'/>"
	data: {
		routes: [
			{
				path: "/"
				title: "Home"
				component: Ractive.extend
					template: "Welcome Home!"
			},
			{
				path: "/foo"
				title: "Foo"
				component: Ractive.extend
					template: "Welcome to Foo!"
			},
			{
				path: "/bar"
				title: "Bar"
				component: Ractive.extend
					template: "Welcome to Bar!"
			},
			{
				path: "*"
				title: "Four Oh Four"
				component: Ractive.extend
					template: "This isn't the page you're looking for."
			}
		]
	},
	components: {
		"page": require("ractive-router")
	}
});

console.log(ractive.toHTML());
```

## License

(The MIT License)

Copyright (c) 2014 Elliot Chong &lt;code+ractive-router@elliotjameschong.com&gt;

	Permission is hereby granted, free of charge, to any person obtaining
	a copy of this software and associated documentation files (the
	'Software'), to deal in the Software without restriction, including
	without limitation the rights to use, copy, modify, merge, publish,
	distribute, sublicense, and/or sell copies of the Software, and to
	permit persons to whom the Software is furnished to do so, subject to
	the following conditions:

	The above copyright notice and this permission notice shall be
	included in all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
	EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
	MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
	IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
	CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
	TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
	SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
