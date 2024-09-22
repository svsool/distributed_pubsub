defmodule DPSWeb.TopicChanelTest do
  use DPSWeb.ChannelCase

  test "client should join topics:matrix" do
    {result, _, socket} =
      DPSWeb.Socket
      |> socket("user:1", %{})
      |> subscribe_and_join(DPSWeb.TopicChannel, "topics:matrix")

    assert result == :ok
  end

  test "client should publish an event to topics:matrix and receive it" do
    {:ok, _, socket} =
      DPSWeb.Socket
      |> socket("user:1", %{})
      |> subscribe_and_join(DPSWeb.TopicChannel, "topics:matrix")

    ref = push(socket, "publish", ["event", %{"message" => "red pill or blue pill?"}])

    assert_reply ref, :ok

    assert_broadcast "event", %{"message" => "red pill or blue pill?"}

    assert_receive %Phoenix.Socket.Message{
      topic: "topics:matrix",
      event: "event",
      payload: %{"message" => "red pill or blue pill?"}
    }
  end

  test "multiple clients should receive the event" do
    {:ok, _, socket1} =
      DPSWeb.Socket
      |> socket("user:1", %{})
      |> subscribe_and_join(DPSWeb.TopicChannel, "topics:matrix")

    {:ok, _, socket2} =
      DPSWeb.Socket
      |> socket("user:2", %{})
      |> subscribe_and_join(DPSWeb.TopicChannel, "topics:matrix")

    push(socket1, "publish", ["event", %{"message" => "red pill or blue pill?"}])

    assert_receive %Phoenix.Socket.Message{
      topic: "topics:matrix",
      event: "event",
      payload: %{"message" => "red pill or blue pill?"}
    }

    assert_receive %Phoenix.Socket.Message{
      topic: "topics:matrix",
      event: "event",
      payload: %{"message" => "red pill or blue pill?"}
    }
  end
end
