# Rest Api Builder

This library helps to create Plug compatible Rest API routers that can be manually created or generated based upon a Resource Provider library. 

## Provider Implementations

* `ecto_schema_store`               - Implements a resource provider based upon a single Ecto Schema.

## Installation

```elixir
def deps do
  [{:rest_api_builder, "~> 0.5.0"}]
end
```

## Creating an API resource router

All API routers are based upon `Plug.Router` and may be included into any standard `Plug.Router` path
or forwarded to in a Phoenix Router definition.

In a APi Router the floowing paths are built in:

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
  def preload(%Plug.Conn{path_params: %{"id" => id}, assigns: assigns} = conn) do
    assign(conn, :resource, %{id: id})
  end

  def index(conn) do
    # Will send back a 200 status with the resource in the body as JSON.
    send_resource conn, [%{id: 1}, %{id: 2}]
  end

  def create(conn) do
    # Will send back a 201 status with the resource in the body as JSON.
    send_resource conn, %{id: 3}
  end

  def show(%Plug.Conn{assigns: %{resource: resource}} = conn) do
    # Will send back a 200 status with the resource in the body as JSON.
    send_resource conn, resource
  end

  def update(%Plug.Conn{assigns: %{resource: resource}} = conn) do
    # Will send back a 403 status with an errors JSON body containing the content provided.
    send_errors conn, 403, "Cannot update resource"
  end

  def delete(%Plug.Conn{assigns: %{resource: resource}} = conn) do
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

  provider EctoSchemaStore.ApiProvider, store: CustomerStore
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

```
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

```
defmodule CustomersApi do
  use RestApiBuilder, plural_name: :customers, singular_name: :customer, activate: :all
end
```

Actions can also be activate one at a time.

```
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

```
defmodule CustomersApi do
  use RestApiBuilder, plural_name: :customers, singular_name: :customer

  activate [:index, :show, :create, :update, :delete]
end
```

`:all` is the same as listing all of the actions. Providing a subset of the list of action will only turn on those actions producing an error for others.

## Plugs

Since a REST API module is based upon Plug Router, it predefines plugs that facilitate its functionality.
to append your own plugs, you must tell the library to allow for custom plugs.

Although you could use the plug statment directly, it would never fire since the :dispatcher plug will have already fired.
The plugs command is provided to allow you to drop your plugs into the middle of the process. Your plugs will fire after
the `preload` function has done its work if you would like to use the loaded resource.

All plugs will be applied at every level of a REST path so any parent resources will have any security checks applied before any children.
More on children later.

```
defmodule CustomersApi do
  use RestApiBuilder, plural_name: :customers, singular_name: :customer, activate: :all, default_plugs: false
  import Plug.Conn

  provider EctoSchemaStore.ApiProvider, store: CustomerStore

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

  provider EctoSchemaStore.ApiProvider, store: CustomerStore

  group_link :google, "http://www.google.com"
  link :author, "/author"

  export_links()
end
```

The `export_links` macro will write out the links to the resource depending upon the encoding used for the resource.
Custom links can also be added using `group_link` and `link`.



## Plug Router Matching

You can provide Plug Router level matching since Plug,Router is imported into the API module. You nned to make sure you
activate any REST actions after the custom matching or the the REST actions may pre-empt the path.

```elixir
defmodule CustomersApi do
  use RestApiBuilder, plural_name: :customers, singular_name: :customer
  import Plug.Conn

  provider EctoSchemaStore.ApiProvider, store: CustomerStore

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

  provider EctoSchemaStore.ApiProvider, store: CustomerStore

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