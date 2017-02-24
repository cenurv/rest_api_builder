# Rest Api Builder

This library helps to create Plug compatible Rest API routers that can be manually created or generated based upon a Resource Provider library. 

## Provider Implementations

* [rest_api_builder_essp](https://hex.pm/packages/rest_api_builder_essp) - Implements a resource provider based upon the [Ecto Schema Store](https://hex.pm/packages/ecto_schema_store) library.

## Installation

```elixir
def deps do
  [{:rest_api_builder, "~> 0.6"}]
end
```

## Creating an API resource router

All API routers are based upon `Plug.Router` and may be included into any standard `Plug.Router` path
or forwarded to in a Phoenix Router definition.

In a API module the following paths are built in:

* index      - `GET /`
* create     - `POST /`
* show       - `GET /:id`
* update     - `PUT /:id` or `PATCH /:id`
* delete     - `DELETE /:id`       

```elixir
defmodule CustomersApi do
  use RestApiBuilder, plural_name: :customers, singular_name: :customer, activate: :all
  import Plug.Conn

  # Called before a specific resource is loaded on show, update, or delete.
  # You will generally want to set the value into Plug.Conn.assigns
  def handle_preload(%Plug.Conn{path_params: %{"id" => id}, assigns: assigns} = conn) do
    assign(conn, :resource, %{id: id})
  end

  def handle_index(conn) do
    # Will send back a 200 status with the resource in the body as JSON.
    send_resource conn, [%{id: 1}, %{id: 2}]
  end

  def handle_create(conn) do
    # Will send back a 201 status with the resource in the body as JSON.
    send_resource conn, %{id: 3}
  end

  def handle_show(%Plug.Conn{assigns: %{resource: resource}} = conn) do
    # Will send back a 200 status with the resource in the body as JSON.
    send_resource conn, resource
  end

  def handle_update(%Plug.Conn{assigns: %{resource: resource}} = conn) do
    # Will send back a 403 status with an errors JSON body containing the content provided.
    send_errors conn, 403, "Cannot update resource"
  end

  def handle_delete(%Plug.Conn{assigns: %{resource: resource}} = conn) do
    # Will send back a 204 status with no content.
    send_resource conn, nil
  end
end
```

## Reference API Provider

Other libraries can implement a macro that will fill in the functions above based upon some factor relevent to the library.
For reference implementation purposes, the following documentation will use the `ecto_schem_store` api provider.
There will be other implementations but based upon this early release the reference implementation is based upon another
library I wrote for simplicity purposes.

The EctoSchemaStore library builds upon ecto to create customizable CRUD modules that utilize and Ecto Repo and Schema.

```elixir
defmodule Customer do
  use EctoTest.Web, :model

  schema "customers" do
    field :name, :string
    field :email, :string
    field :account_closed, :boolean, default: false

    timestamps
  end

  def changeset(model, params) do
    model
    |> cast(params, [:name, :email])
  end
end
```

You can create a store with the following:

```elixir
defmodule CustomerStore do
  use EctoSchemaStore, schema: Customer, repo: MyApp.Repo
end
```

To learn more about how to use that libary please visit that project. This will be enough for the following examples.

## Using a Provider

This library provides a macro to load a provider module into your API.

```elixir
defmodule CustomersApi do
  use RestApiBuilder, plural_name: :customers, singular_name: :customer, activate: :all

  provider RestApiBuilder.EctoSchemaStoreProvider, store: CustomerStore
end
```

That's it. Since the EctoSchemaStore library knows how to interact with itself, it will generate the REST action functions for us.
This same process can be followed any library that adds `use RestApiBuilder.Provider` to a module. More on building an API Provider later.

## Adding to Plug Router

If you have an existing `Plug.Router` module you can add your API with the following:

```elixir
forward "/customers", to: CustomerApi
```

## Adding to Phoenix Router

```elixir
forward "/customers", CustomerApi
```

Any pipeline of plugs can be applied before forwarding if you would like.

## Include Other API routers

Any API module can act as a base for other API modules which will utilize the plural name provided in those modules.
A better example of a real API would be to set up a version collection.

```elixir
defmodule ApiV1 do
  use RestApiBuilder

  include CustomersApi
  include PartnersApi
end
```

Then include this module in your router.

```elixir
# Plug Router
forward "/api/v1", to: ApiV1

# Phoenix Router
forward "/api/v1", ApiV1
```

To get to the rest resources you would submit to `/api/v1/customers` or to `/api/v1/partners`. The resource names were pulled from the child modules.

You can include any REST API module into any other.

## Activating Actions

By default no REST actions are activated and an eror will be returned if you attempt to use one of the built in actions.

To activate all you can provided a option on the `use` statement.

```elixir
defmodule CustomersApi do
  use RestApiBuilder, plural_name: :customers, singular_name: :customer, activate: :all
end
```

Actions can also be activate one at a time.

```elixir
defmodule CustomersApi do
  use RestApiBuilder, plural_name: :customers, singular_name: :customer

  activate :index
  activate :show
  activate :create
  activate :update
  activate :delete
end
```

Or combined into list.

```elixir
defmodule CustomersApi do
  use RestApiBuilder, plural_name: :customers, singular_name: :customer

  activate [:index, :show, :create, :update, :delete]
end
```

`:all` is the same as listing all of the actions. Providing a subset of the list of action will only turn on those actions producing an error for others.

## Plugs

Since a REST API module is based upon Plug Router, it predefines plugs that facilitate its functionality.
To append your own plugs, you must tell the library to allow for custom plugs.

Although you could use the plug statment directly, it would never fire since the :dispatcher plug will have already fired.
The plugs command is provided to allow you to drop your plugs into the middle of the process. Your plugs will fire after
the `preload` function has done its work if you would like to use the loaded resource.

All plugs will be applied at every level of a REST path so any parent resources will have any security checks applied before any children.
More on children later.

```elixir
defmodule CustomersApi do
  use RestApiBuilder, plural_name: :customers, singular_name: :customer, activate: :all, default_plugs: false
  import Plug.Conn

  provider RestApiBuilder.EctoSchemaStoreProvider, store: CustomerStore

  plugs do
    if Mix.env == :dev do
      plug :verify_active_customer, verify: false
    else
      plug :verify_active_customer, verify: true
    end

    plug prevent_inactive
  end

  def verify_active_customer(%{assigns: %{current: customer}} = conn, verify: true) do
    assign conn, :verified, !customer.account_closed
  end
  def verify_active_customer(conn, _opts) do 
    assign conn, :verified, true
  end

  def prevent_inactive(%{assigns: %{verified: true}} = conn, _opts), do: conn
  def prevent_inactive(%{assigns: %{verified: false}} = conn, _opts) do
    conn
      |> send_resp(404, "Not Found")
      |> halt
  end
end
```

## Links

A REST API module can add links to the resource. Some basic ones are automatically provided. A provider module may also add additional.
Links exist for both the entire resource group and for individual resources.

```elixir
defmodule CustomersApi do
  use RestApiBuilder, plural_name: :customers, singular_name: :customer

  provider RestApiBuilder.EctoSchemaStoreProvider, store: CustomerStore

  group_link :google, "http://www.google.com"
  link :author, "/author"

  export_links()
end
```

The `export_links` macro will write out the links to the resource depending upon the encoding used for the resource.
Custom links can also be added using `group_link` and `link`.



## Plug Router Matching

You can provide Plug Router level matching since Plug,Router is imported into the API module. You need to make sure you
activate any REST actions after the custom matching or the the REST actions may pre-empt the path.

```elixir
defmodule CustomersApi do
  use RestApiBuilder, plural_name: :customers, singular_name: :customer
  import Plug.Conn

  provider RestApiBuilder.EctoSchemaStoreProvider, store: CustomerStore

  post "/my_action" do
    conn
    |> send_resp(200, "You got to the action.")
  end

  activate :all

  get "/:id/my_action" do
    # Any route with :id in the first level will have the preload plug load the resource.
    send_resource conn, CustomerStore.to_map(conn.assigns[:current])
  end

  group_link :my_action, "/my_action"
  link :my_action, "/my_action"

  export_links()
end
```

## Features

Some helper macros are provided to help setup route matching. These add ons to the standard REST action are called
features in this library. There are group features which apply to the base path or regular features which apply to
an individual resource. Using features also sets up the link path for the proivided feature to be added to the
resource.

```elixir
defmodule CustomersApi do
  use RestApiBuilder, plural_name: :customers, singular_name: :customer
  import Plug.Conn

  provider RestApiBuilder.EctoSchemaStoreProvider, store: CustomerStore

  group_feature :my_action do
    conn
    |> send_resp(200, "You got to the action.")
  end

  activate :all

  feature :my_action do
    # Any route with :id in the first level will have the preload plug load the resource.
    send_resource conn, CustomerStore.to_map(conn.assigns[:current])
  end

  export_links()
end
```

## Children

Similar `include` the children macro will load another REST API module into the path but associated with a resource.
Providers can then use the parent resource to narrow down the child resources.

```elixir
# Child Resource
defmodule MessagesApi do
  use RestApiBuilder, plural_name: :messages, singular_name: :message, activate: :all

  provider RestApiBuilder.EctoSchemaStoreProvider, store: MessageStore,
                                        parent: :customer_id

  export_links()
end

# Parent Resource
defmodule CustomersApi do
  use RestApiBuilder, plural_name: :customers, singular_name: :customer

  provider RestApiBuilder.EctoSchemaStoreProvider, store: CustomerStore

  activate :all

  children MessagesApi

  export_links()
end
```

The messages resource can be reach via `/api/v2/customers/12/messages` a single child resource could be retrieved
via `/api/v2/customers/12/messages/37`.

The child resource will be filtered down by the API Provider library based upon the parent. If message 37 existed
but did not belong to customer 12, then a HTTP 404 would be returned even though the message id is valid. If
customer 12 did not exist or the user does not have access, then the message would never be looked up and the
parents error would be returned.

The exact enforcement of relationships is defined by the API provider. If you write your own then you will have to
define this enforcement and relatioship yourself.

If the relationships are validated, then links will be created for parenbt and children on the current resource.

## Modifying Actions

If the provider allows, then the actions can be overloaded in your code. This will allow you to perform some action before or
after the provider's default action.

```elixir
defmodule CustomersApi do
  use RestApiBuilder, plural_name: :customers, singular_name: :customer, activate: :all

  provider RestApiBuilder.EctoSchemaStoreProvider, store: CustomerStore

  def handle_create(conn) do
    # Do some action before the resource is created by the provider.
    
    conn = super(conn)

    # Do some action after the resource is created by the provider.

    conn
  end
end
```

## Event Announcements ##

An API module supports the concept of an event through the [Event Queues](https://hex.pm/packages/event_queues) library on Hex.
Event Queues must be included in your application and each queue and handler added to your application supervisor. Visit
the instructions at (https://hexdocs.pm/event_queues) for more details.

Events:

* `:after_create`
* `:after_update`
* `:after_delete`

Macros:

* `create_queue`               - Creates a Queue for instances where one is not already set up. Accessible at {api module name}.Queue
* `announces`                  - Register a what events to announce and what modules to send the event. By default will use {api module name}.Queue

```elixir
defmodule CustomersApi do
  use RestApiBuilder, plural_name: :customers, singular_name: :customer, activate: :all

  provider RestApiBuilder.EctoSchemaStoreProvider, store: CustomerStore

  create_queue()

  announces events: [:after_create, :after_update, :after_delete]

  defmodule Handler do
    use EventQueues, type: :handler, subscribe: SampleApi.Apis.UsersApi.Queue

    def handle(event) do
      IO.inspect event
    end
  end
end
```

The event queue and any handlers must be started as part of the application.

```elixir
# Start the event queue and handler.
CustomersApi.Queue.start_link
CustomersApi.Handler.start_link

# As part of the App supervisor
worker(CustomersApi.Queue, []),
worker(CustomersApi.Handler, [])
```

## Direct Access ##

The API can be accessed internally to your application without needing to make an HTTP call. When directly accessed
via other application code, the Plug.Conn being passed contains the `:direct_access` value in `assigns` set to `true`.

Direct access does not consume JSON text or generate the JSON response. These translations are skipped over as that
converting to JSON and back provides no advantage internally. Therefore, you may receive a more complete resource
from direct access then you would get as an HTTP call. For the Ecto Schema Store Provider, this will result in
a normal Ecto model being returned where as over the web you would get a generalized map version.

Execute process:

`process(http_method, path, opts)` or `process!(http_method, path, opts)`

Options:

* `params`        - Will set the params on Plug.Conn. Keyword list or map.
* `assigns`       - Will set values on the assigns of the Plug.Conn passed in. Keyword list or map.
* `headers`       - Map or list of tuples with headers.

The following convience methods can be used.

Functions:

* index, index!
* show, show!
* create, create!
* update, update!
* delete, delete!
* get, get!
* post, post!
* put, put!
* patch, patch!
* delete, delete!

All functions share the same parameters `(path, opts)`.

The path is always relative to the API module you are directly calling on.

```elixir
# Equivalent paths
{:ok, customers} = ApiV1.index "/customers"
{:ok, customers} = CustomersApi.index "/"

# Submitting resource
{:ok, customer} = ApiV1.create "/customers", params: %{name: "Bob Person"}
customer = ApiV1.create! "/customers", params: %{name: "Bob Person"}
```

Direct Access can be used to build an internal api. This will allow you to use your REST API as a traditional API.

```elixir
defmodule InternalApi do
  def list_customers do
    ApiV1.index! "/customers"
  end

  def create_customer(name) do
    ApiV1.create "/customers", params: %{name: name}
  end

  def create_customer!(name) do
    ApiV1.create! "/customers", params: %{name: name}
  end
end
```

When designing plugs, you will want to consider both web access and direct access and may want alternate functionality or
less security when the `:direct_access` value is present in assigns.

## Testing ##

Any API module can be tested using `Plug.Test` or the direct access methods directly on the modules. You can also
perform controller style tests like you would normally when using Phoenix Framework.

```elixir
defmodule CustomersApiTest do
  use MyApp.ConnCase

  test "Test Creating a Customer" do
    customer = ApiV1.create! "/customers", params: %{name: "Bob Person"}
    assert "Bob Person" == customer.name
  end

  test "Test Creating a Customer using Test Conn", %{conn: conn} do
    response =
      conn
      |> post("/api/v1/customers", %{customer: %{name: "Bob"}})
      |> json_response(201)

    assert "Bob Person" == response["customer"]["name"]
  end
end
```