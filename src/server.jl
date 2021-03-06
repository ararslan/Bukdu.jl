# module Bukdu

include("server/error.jl")
include("server/handler.jl")

module Farm

import HttpServer
servers = Dict{Type,Vector{Tuple{HttpServer.Server,Task}}}()

end # module Bukdu.Farm


import HttpServer
import HttpCommon: Request, Response

"""
    Bukdu.start(port::Int; host=getaddrinfo("localhost"))

Start Bukdu server with port.

```jula
julia> Bukdu.start(8080)
Listening on 127.0.0.1:8080...
```
"""
function start(port::Int, host=getaddrinfo("localhost"); kw...)::Void
    Bukdu.start([port], host; kw...)
end

function start{AE<:ApplicationEndpoint}(::Type{AE}, port::Int, host=getaddrinfo("localhost"); kw...)::Void
    Bukdu.start(AE, [port], host; kw...)
end

"""
    Bukdu.start(ports::Vector{Int}; host=getaddrinfo("localhost"))

Start Bukdu server with multiple ports.

```jula
julia> Bukdu.start([8080, 8081])
Listening on 127.0.0.1:8080...
```
"""
function start(ports::Vector{Int}, host=getaddrinfo("localhost"); kw...)::Void
    Bukdu.start(Endpoint, ports, host; kw...)
end

function start{AE<:ApplicationEndpoint}(::Type{AE}, ports::Vector{Int}, host=getaddrinfo("localhost"); kw...)::Void
    handler = (req::Request, res::Response) -> Server.handler(AE, req, res)
    for port in ports
        server = HttpServer.Server(handler)
        server.http.events["listen"] = (port) -> Logger.info("Listening on $port..."; LF=!isdefined(:Juno))
        task = @async begin
            HttpServer.run(server, host=host, port=port; kw...)
        end
        if :queued == task.state
            if !haskey(Farm.servers, AE)
                Farm.servers[AE] = Vector{Tuple{HttpServer.Server,Task}}()
            end
            push!(Farm.servers[AE], (server, task))
        end
    end
    nothing
end

"""
    Bukdu.stop()

Stop the Bukdu server.
"""
function stop()::Void
    Bukdu.stop(Endpoint)
end

function stop{AE<:ApplicationEndpoint}(::Type{AE})::Void
    stopped = 0
    for (server, task) in Farm.servers[AE]
        try
            if Base.StatusActive == server.http.sock.status
                stopped += 1
                close(server)
            end
        catch e
        end
    end
    if stopped >= 1
        Logger.info("Stopped.")
        empty!(Farm.servers[AE])
        delete!(Farm.servers, AE)
    end
    nothing
end

function reset()
    for x in [Routing.routes,
              Routing.router_routes,
              Routing.endpoint_routes,
              Routing.endpoint_contexts,
              RouterScope.stack,
              RouterScope.pipes,
              ViewFilter.filters]
        empty!(x)
    end
    Logger.have_color(Base.have_color)
end
