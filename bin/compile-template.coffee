fs = require "fs"
Ractive = require "ractive"

basePath = "#{__dirname}/../lib"

try
	template = fs.readFileSync("#{basePath}/template.html").toString()
	index = fs.readFileSync("#{basePath}/index.js").toString()
catch
	process.exit()

index = index.replace /require\("\.\/template\.html"\)/g, JSON.stringify Ractive.parse template

fs.writeFileSync "#{basePath}/index.js", index
fs.unlinkSync "#{basePath}/template.html"
