defmodule DPSWeb do
  @moduledoc false

  @spec channel :: tuple()
  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
