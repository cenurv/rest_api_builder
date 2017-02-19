defmodule RestApiBuilder.Router do
  
  defmacro __using__(_opts) do
    quote do
      use Plug.Router

      import RestApiBuilder.Router

      plug :match
      plug :dispatch
    end
  end


end
