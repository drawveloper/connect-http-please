expect = require('chai').expect
httplease = require '../index'
connect = require 'connect'
http = require 'http'
https = require 'https'
request = require 'request'
require 'colors'

generateEndHandler = -> (req, res) -> 
  res.end 'qux'

generateWriteEndHandler = -> (req, res) -> 
  res.write 'bar'
  res.end 'qux'

generateWriteHeadEndHandler = (statusCode = 200) -> (req, res) -> 
  res.writeHead statusCode, {'location': 'https://' + req.headers.host + req.url}
  res.end 'qux'

generateWriteHeadWriteEndHandler = (statusCode = 200) -> (req, res) -> 
  res.writeHead statusCode, {'location': 'https://' + req.headers.host + req.url}
  res.write 'bar'
  res.end 'qux'

notRedirectTestBody = (handler, expectedBody = 'qux', expectedStatusCode = 200) ->
  (done) ->
    server = http.createServer(connect().use(httplease()).use(handler)).listen(8000)
    request 'http://localhost:8000', (err, res, body) ->
      return done err if err
      expect(res.statusCode).to.equal expectedStatusCode
      expect(body).to.equal expectedBody
      server.close()
      done()
      
redirectTestBody = (handler) ->
  (done) ->
    server = http.createServer(connect().use(httplease()).use(handler)).listen(8000)
    options =
      uri: 'http://localhost:8000/'
      headers:
        host: 'google.starttest.com'

    request 'https://google.starttest.com/', (googErr, googRes, googBody) ->
      return done googErr if googErr
      request options, (err, res, body) ->
        return done err if err
        expect(res.statusCode).to.equal 200
        expect(body).to.equal googBody
        server.close()
        done()
      
describe 'HTTP Please', ->

  describe 'when handling 2xx responses should do nothing', ->
    it 'when server calls only end', notRedirectTestBody(generateEndHandler())
    it 'when server calls write and end', notRedirectTestBody(generateWriteEndHandler(), 'barqux')
    it 'when server calls writeHead and end', notRedirectTestBody(generateWriteHeadEndHandler())
    it 'when server calls writeHead, write and end', notRedirectTestBody(generateWriteHeadWriteEndHandler(), 'barqux')

  describe 'when handling 3xx responses should redirect', ->
    @timeout 5000
    
    it 'should redirect when server calls writeHead and end', redirectTestBody(generateWriteHeadEndHandler(301))
    it 'should redirect when server calls writeHead, write and end', redirectTestBody(generateWriteHeadWriteEndHandler(301))
    
  describe 'when handling 4xx responses should do nothing', ->
    it 'when server calls writeHead and end', notRedirectTestBody(generateWriteHeadEndHandler(404), 'qux', 404)
    it 'when server calls writeHead, write and end', notRedirectTestBody(generateWriteHeadWriteEndHandler(404), 'barqux', 404)
  
  describe 'when handling 5xx responses should do nothing', ->
    it 'when server calls writeHead and end', notRedirectTestBody(generateWriteHeadEndHandler(503), 'qux', 503)
    it 'when server calls writeHead, write and end', notRedirectTestBody(generateWriteHeadWriteEndHandler(503), 'barqux', 503)
