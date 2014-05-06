connect-http-please
================

![Build status](https://travis-ci.org/gadr/connect-http-please.png)

Follows HTTPS redirects for you, seamlessly.

### Idea

Don't want to enter HTTPS while in development?  
Don't want to fiddle around self-signed certificates for your HTTPS proxy?

Add `connect-http-please` to your middleware chain and it will **follow HTTPS redirects for you**.

### Usage

    httplease = require 'connect-http-please'
    
    (...)
    
    middlewares = [
        httplease()
        myproxy( { to: 'somesite.com' } )
      ]
      
    (...)
    
    server.listen(80)
      
Now, imagine your browser issues a request to `localhost/secure`.  
This gets proxied to `somesite.com/secure`.  
However, `somesite.com/secure` won't accept HTTP: instead, it sends a  

    301 - location: https://somesite.com/secure
    
Then, `connect-http-please` detects that this is  

- a redirect (`301`/`302`) to 
- to the exact same *URI*
- changing to HTTPS protocol

So, it saves your browser the trouble, fetches the content via HTTPS and returns your original request.  
Your browser never knew he had to spoke HTTPS.

## DISCLAIMER

This middleware is meant as a facilitator for **DEVELOPMENT PURPOSES**.  
**Do not** use it in production or in critical environments.  
Even though **this middleware makes the requests via https**, there's no
guarantee of safety between your browser and this proxy.

*You have been warned.*
