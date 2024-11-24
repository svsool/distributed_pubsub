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
    assert %{channel_pid: ^channel_pid} = subscriber
  end

  test "client should publish an event to topics:matrix and receive it exactly once" do
    {:ok, _, socket} =
      DPSWeb.Socket
      |> socket("user:1", %{})
      |> subscribe_and_join(DPSWeb.TopicChannel, "topics:matrix")

    socket_join_ref = socket.join_ref

    ref = push(socket, "publish", ["event", %{"message" => "red pill or blue pill?"}])

    assert_reply ref, :ok

    assert_receive %Phoenix.Socket.Message{
      topic: "topics:matrix",
      event: "event",
      payload: %{"message" => "red pill or blue pill?"},
      join_ref: ^socket_join_ref
    }

    refute_receive %Phoenix.Socket.Message{
      topic: "topics:matrix",
      event: "event",
      payload: %{"message" => "red pill or blue pill?"},
      join_ref: ^socket_join_ref
    }
  end

  test "multiple subscribers should receive an event exactly once" do
    {:ok, _, socket1} =
      DPSWeb.Socket
      |> socket("user:1", %{})
      |> subscribe_and_join(DPSWeb.TopicChannel, "topics:matrix")

    {:ok, _, socket2} =
      DPSWeb.Socket
      |> socket("user:2", %{})
      |> subscribe_and_join(DPSWeb.TopicChannel, "topics:matrix")

    socket1_join_ref = socket1.join_ref
    socket2_join_ref = socket2.join_ref

    subscribers = TopicServer.subscribers("topics:matrix")

    assert length(subscribers) == 2

    ref = push(socket1, "publish", ["event", %{"message" => "red pill or blue pill?"}])

    assert_reply ref, :ok

    assert_receive %Phoenix.Socket.Message{
      topic: "topics:matrix",
      event: "event",
      payload: %{"message" => "red pill or blue pill?"},
      join_ref: ^socket1_join_ref
    }

    assert_receive %Phoenix.Socket.Message{
      topic: "topics:matrix",
      event: "event",
      payload: %{"message" => "red pill or blue pill?"},
      join_ref: ^socket2_join_ref
    }

    # there should be no duplicate messages received

    refute_receive %Phoenix.Socket.Message{
      topic: "topics:matrix",
      event: "event",
      payload: %{"message" => "red pill or blue pill?"},
      join_ref: ^socket1_join_ref
    }

    refute_receive %Phoenix.Socket.Message{
      topic: "topics:matrix",
      event: "event",
      payload: %{"message" => "red pill or blue pill?"},
      join_ref: ^socket2_join_ref
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
    assert %{channel_pid: ^channel_pid} = subscriber

    # unsubscribe second one
    leave(socket2)

    assert_receive {:DOWN, _, _, _, {:shutdown, :left}}

    subscribers = TopicServer.subscribers("topics:matrix")

    assert Enum.empty?(subscribers)
  end

  test "client should receive an error if topic name is invalid" do
    assert {:error, "invalid topic name" <> _} =
             DPSWeb.Socket
             |> socket("user:1", %{})
             # short topic name
             |> subscribe_and_join(DPSWeb.TopicChannel, "topics:s")

    assert {:error, "invalid topic name" <> _} =
             DPSWeb.Socket
             |> socket("user:1", %{})
             # long topic name
             |> subscribe_and_join(DPSWeb.TopicChannel, "topics:s#{String.duplicate("a", 64)}")

    assert {:error, "invalid topic name" <> _} =
             DPSWeb.Socket
             |> socket("user:1", %{})
             # non-alphanumeric topic name
             |> subscribe_and_join(DPSWeb.TopicChannel, "topics:matrix%$#")
  end
end
