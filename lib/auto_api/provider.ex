defmodule AutoApi.Provider do
  @macrocallback generate(opts :: List.t) :: Macro.t

  defmacro __using__(_opts) do
    quote do
      import AutoApi.Provider

      @behaviour AutoApi.Provider
    end
  end
end
