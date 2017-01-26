defmodule AutoApi.Router do
  
  defmacro __using__(_opts) do
    quote do
      use Plug.Router

      import AutoApi.Router

      plug :match
      plug :dispatch
    end
  end


end
