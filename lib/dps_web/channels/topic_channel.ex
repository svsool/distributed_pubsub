defmodule DPSWeb.TopicChannel do
  use Phoenix.Channel, log_join: false, log_handle_in: false

  use DPS.TopicChannel

  intercept ["event"]
end
