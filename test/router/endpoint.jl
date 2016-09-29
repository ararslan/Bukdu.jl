importall Bukdu
import Bukdu: has_called
using Base.Test

@test !has_called(Router)
@test !has_called(Endpoint)

Router() do
end

@test has_called(Router)
@test !has_called(Endpoint)

Bukdu.start(8082)

@test has_called(Endpoint)

immutable Endpoint2 <: ApplicationEndpoint
end

Bukdu.start(Endpoint2, 8083)

@test !has_called(Endpoint2)

sleep(0.1)
Bukdu.stop()

@test !has_called(Endpoint)

Bukdu.stop(Endpoint2)

@test !has_called(Endpoint2)

immutable EndpointController <: ApplicationController
end

index(::EndpointController) = ""

Router() do
    get("/first", EndpointController, index)
end

Endpoint() do
    plug(Router)
end

immutable Router2 <: ApplicationRouter
end

Router2() do
    get("/second", EndpointController, index)
end

Endpoint2() do
    plug(Router2)
end

conn = (Router)(get, "/first")
@test 200 == conn.status

conn = (Router2)(get, "/second")
@test 200 == conn.status

conn = (Endpoint)("/first")
@test 200 == conn.status

conn = (Endpoint2)("/second")
@test 200 == conn.status

Logger.set_level(:fatal)
@test_throws NoRouteError (Router)(get, "/second")
@test_throws NoRouteError (Router2)(get, "/first")
@test_throws NoRouteError (Endpoint)("/second")
@test_throws NoRouteError (Endpoint2)("/first")


type WelcomeController <: ApplicationController
end

first(::WelcomeController) = 1
second(::WelcomeController) = 2

@test_throws NoRouteError (Endpoint)("/")

Router() do
    get("/", WelcomeController, first)
end

@test !isempty(Bukdu.RouterRoute.routes)

conn = (Router)(get, "/")
@test 200 == conn.status

@test_throws NoRouteError (Endpoint)("/")


type SecondRouter <: ApplicationRouter
end

SecondRouter() do
end

@test isempty(Bukdu.RouterRoute.routes)

SecondRouter() do
    get("/", WelcomeController, second)
end

@test !isempty(Bukdu.RouterRoute.routes)

Endpoint() do
    plug(Router)
    plug(SecondRouter)
end

conn = (Router)(get, "/")
@test 200 == conn.status

conn = (SecondRouter)(get, "/")
@test 200 == conn.status

conn = (Endpoint)("/")
@test 1 == conn.resp_body

type SecondEndpoint <: ApplicationEndpoint
end

SecondEndpoint() do
    plug(SecondRouter)
    plug(Router)
end

conn = (Endpoint)("/")
@test 1 == conn.resp_body

conn = (SecondEndpoint)("/")
@test 2 == conn.resp_body


type NothingRouter <: ApplicationRouter
end

type NothingEndpoint <: ApplicationEndpoint
end

NothingRouter() do
end

NothingEndpoint() do
end

@test_throws NoRouteError (NothingRouter)(get, "/")

@test_throws NoRouteError (NothingEndpoint)("/")

NothingEndpoint() do
    plug(NothingRouter)
end

@test_throws NoRouteError (NothingEndpoint)("/")

conn = (Endpoint)("/")
@test 200 == conn.status