expect = require('chai').expect
httplease = require '../index'
connect = require 'connect'
http = require 'http'
https = require 'https'
request = require 'request'
fs = require 'fs'
require 'colors'

generateEndHandler = -> (req, res) -> 
  res.end 'qux'

generateWriteEndHandler = -> (req, res) -> 
  res.write 'bar'
  res.end 'qux'

generateWriteHeadEndHandler = (statusCode = 200) -> (req, res) -> 
  res.writeHead statusCode, {'location': 'https://' + req.headers.host.replace('8000', '8001') + req.url}
  res.end 'qux'

testBody = (handler, expectedBody = 'qux', expectedStatusCode = 200) ->
  (done) ->
    server = http.createServer(connect().use(httplease()).use(handler)).listen(8000)
    request 'http://localhost:8000', (err, res, body) ->
      return done err if err
      expect(res.statusCode).to.equal expectedStatusCode
      expect(body).to.equal expectedBody
      server.close()
      done()
      
describe 'HTTP Please', ->

  describe 'when handling 2xx responses should do nothing', ->
    it 'when server calls only end', testBody(generateEndHandler())
    it 'when server calls write and end', testBody(generateWriteEndHandler(), 'barqux')
    it 'when server calls writeHead and end', testBody(generateWriteHeadEndHandler())

  describe 'when handling 4xx responses should do nothing', ->
    it 'when server calls writeHead and end', testBody(generateWriteHeadEndHandler(404), 'qux', 404)

  describe 'when handling 5xx responses should do nothing', ->
    it 'when server calls writeHead and end', testBody(generateWriteHeadEndHandler(503), 'qux', 503)

  describe 'when handling 3xx responses should redirect', ->
    it 'when server calls writeHead and end', (done) ->
      httpsOptions =
        key: fs.readFileSync('specs/key.pem')
        cert: fs.readFileSync('specs/key-cert.pem')

      httpsServer = https.createServer(httpsOptions, (req, res) ->
        res.writeHead(200)
        res.end("hello world\n")
      ).listen(8001)

      handler = generateWriteHeadEndHandler(301)

      server = http.createServer(connect().use(httplease(verbose: true)).use(handler)).listen(8000)

      process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0"
      request {url: 'http://localhost:8000', followRedirect: false}, (err, res, body) ->
        return done err if err
        expect(res.statusCode).to.equal 200
        expect(body).to.equal "hello world\n"
        httpsServer.close()
        server.close()
        done()
