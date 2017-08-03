https = require 'https'
url = require 'url'
require 'colors'

REDIRECT_STATUS_CODES = [301, 302]

module.exports = (options = {})->
  console.verbose = -> console.log.apply(console, arguments) if options.verbose
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

      # Check if status code is redirect
      redirectStatusCode = statusCode in REDIRECT_STATUS_CODES
      return false unless redirectStatusCode

      switch arguments.length
        when 3 then headers = arguments[2]
        when 2 then headers = arguments[1]
        else headers = null

      # Check if LOCATION header exists
      location = headers?.location or res.getHeader('location')
      return false unless location

      # Check if LOCATION header hostname and path matches original request
      locationUrl = url.parse(location)
      reqUrl = url.parse('https://'+ req.headers.host + req.url)
      identicalLocation = reqUrl.hostname is locationUrl.hostname and reqUrl.path is locationUrl.path
      return false unless identicalLocation

      console.verbose "HTTPlease: location hostname and url matches request", location.yellow

      # Overwrite destination hostname and port if necessary
      if options.host
        overwrittenUrl = url.parse("https://" + options.host)
      else if options.rewriteHost
        overwrittenUrl = url.parse("https://" + options.rewriteHost(req.headers.host))

      # Copy overwritten properties to destination URL
      if overwrittenUrl
        locationUrl.hostname = locationUrl.host = overwrittenUrl.hostname
        locationUrl.port =  overwrittenUrl.port
        # Add port to host
        if locationUrl.port
          locationUrl.host += ':' + locationUrl.port

      # Copy headers
      headers = {}
      for k, v of req.headers
        headers[k] = v

      # Adjust host header based on destination URL
      headers.host = locationUrl.host

      requestOptions =
        hostname: locationUrl.hostname
        port: locationUrl.port
        path: locationUrl.path
        headers: headers

      # This is a redirect to the exact same url, except with HTTPS protocol
      console.verbose "HTTPlease: follow redirect to", ("https://" + locationUrl.host).yellow
      redirectReq = https.request requestOptions, (redirectRes) ->
        restore()
        res.writeHead(redirectRes.statusCode, redirectRes.headers)
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
      unless handleRedirect.apply this, arguments
        restore()
        writeHead.apply res, arguments

    # Overwrite end to detect redirect
    res.end = ->
      unless handleRedirect res.statusCode
        restore()
        end.apply res, arguments

    next()
