https = require 'https'
require 'colors'

REDIRECT_STATUS_CODES = [301, 302]

module.exports = (options = {})->
  console.verbose = -> console.log.apply(console, arguments) if options.verbose
  options.replaceHost or= (h) -> h
  (req, res, next) ->
    # HTTP requests don't have req.connection.encrypted object
    return next() if req.connection.encrypted

    # Save original response functions
    writeHead = res.writeHead
    end = res.end

    # Restore original response functions
    restore = ->
      res.writeHead = writeHead
      res.end = end

    handleRedirect = (statusCode) ->
      # Overwrite with no-op so handleRedirect is only called once
      res.writeHead = res.end = ->

      redirectStatusCode = statusCode in REDIRECT_STATUS_CODES
      location = res.getHeader('location')
      identicalLocation = location?.indexOf('https://'+ req.headers.host + req.url) is 0
      return false if not (redirectStatusCode and identicalLocation)

      # This is a redirect to the exact same url, except with HTTPS protocol
      console.verbose "HTTPlease: follow redirect to", location.yellow
      req.headers.host = options.host or options.replaceHost(req.headers.host)
      requestOptions =
        host: req.headers.host
        path: req.url
        headers: req.headers

      redirectReq = https.request requestOptions, (redirectRes) ->
        restore()
        redirectRes.pipe(res)

      redirectReq.on 'error', (err) ->
        restore()
        next err
        res.writeHead(500)
        res.end(err.toString())

      redirectReq.end()
      return true
      
    # Overwrite writeHead to detect redirect
    res.writeHead = ->
      unless handleRedirect arguments[0]
        restore()
        writeHead.apply res, arguments

    # Overwrite end to detect redirect
    res.end = ->
      unless handleRedirect res.statusCode
        restore()
        end.apply res, arguments

    next()
