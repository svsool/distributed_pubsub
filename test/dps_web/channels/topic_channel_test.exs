defmodule DPSWeb.TopicChanelTest do
  use DPSWeb.ChannelCase

  alias DPS.TopicServer

  test "client should join topics:matrix" do
    {:ok, _, socket} =
      DPSWeb.Socket
      |> socket("user:1", %{})
      |> subscribe_and_join(DPSWeb.TopicChannel, "topics:matrix")

    subscribers = TopicServer.subscribers("topics:matrix")

    [subscriber] = subscribers
    channel_pid = socket.channel_pid

    assert length(subscribers) == 1
    assert %{channel_pid: ^channel_pid, topic_client_worker_pid: _} = subscriber
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

  test "multiple subscribers should receive the event" do
    {:ok, _, socket1} =
      DPSWeb.Socket
      |> socket("user:1", %{})
      |> subscribe_and_join(DPSWeb.TopicChannel, "topics:matrix")

    {:ok, _, _socket2} =
      DPSWeb.Socket
      |> socket("user:2", %{})
      |> subscribe_and_join(DPSWeb.TopicChannel, "topics:matrix")

    subscribers = TopicServer.subscribers("topics:matrix")

    assert length(subscribers) == 2

    ref = push(socket1, "publish", ["event", %{"message" => "red pill or blue pill?"}])

    assert_reply ref, :ok

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

  test "subscribers should unsubscribe" do
    {:ok, _, socket1} =
      DPSWeb.Socket
      |> socket("user:1", %{})
      |> subscribe_and_join(DPSWeb.TopicChannel, "topics:matrix")

    {:ok, _, socket2} =
      DPSWeb.Socket
      |> socket("user:2", %{})
      |> subscribe_and_join(DPSWeb.TopicChannel, "topics:matrix")

    Process.monitor(socket1.channel_pid)
    Process.unlink(socket1.channel_pid)
    Process.monitor(socket2.channel_pid)
    Process.unlink(socket2.channel_pid)

    subscribers = TopicServer.subscribers("topics:matrix")

    assert length(subscribers) == 2

    # unsubscribe first one
    leave(socket1)

    assert_receive {:DOWN, _, _, _, {:shutdown, :left}}

    subscribers = TopicServer.subscribers("topics:matrix")
    [subscriber] = subscribers
    channel_pid = socket2.channel_pid

    assert length(subscribers) == 1
    assert %{channel_pid: ^channel_pid, topic_client_worker_pid: _} = subscriber

    # unsubscribe second one
    leave(socket2)

    assert_receive {:DOWN, _, _, _, {:shutdown, :left}}

    subscribers = TopicServer.subscribers("topics:matrix")

    assert Enum.empty?(subscribers)
  end
end
