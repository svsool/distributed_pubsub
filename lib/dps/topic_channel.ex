defmodule DPS.TopicChannel do
  defmacro __using__(_opts) do
    quote location: :keep do
      import DPS.TopicRouter

      @impl true
      def join("topics:" <> topic_name = topic, payload, socket) do
        if valid_topic_name?(topic_name) do
          {:ok, topic_server_worker_pid} = resolve_topic_server_worker_pid(topic)

          start = System.monotonic_time()

          topic_channel_pid = self()

          :ok =
            GenServer.call(
              topic_server_worker_pid,
              {:join, topic, topic_channel_pid}
            )

          duration = System.monotonic_time() - start

          :telemetry.execute(
            [:dps, :topic_channel, :join],
            %{duration: duration},
            %{
              socket_id: socket.id,
              topic: topic,
              payload: payload,
              topic_channel_pid: topic_channel_pid,
              topic_server_worker_pid: topic_server_worker_pid
            }
          )

          {:ok, socket}
        else
          report_join_error()
        end
      end

      @impl true
      def join(_topic, _payload, _socket), do: report_join_error()

      @impl true
      def handle_in("publish", [event, payload], socket) do
        {:ok, topic_server_worker_pid} = resolve_topic_server_worker_pid(socket.topic)

        start = System.monotonic_time()

        :ok = GenServer.call(topic_server_worker_pid, {:publish, socket.topic, event, payload})

        duration = System.monotonic_time() - start

        :telemetry.execute(
          [:dps, :topic_channel, :publish],
          %{duration: duration},
          %{
            socket_id: socket.id,
            topic: socket.topic,
            event: event,
            payload: payload,
            topic_server_worker_pid: topic_server_worker_pid
          }
        )

        {:reply, :ok, socket}
      end

      @impl true
      def handle_info({:publish, topic, event, payload}, socket) do
        start = System.monotonic_time()

        push(socket, event, payload)

        duration = System.monotonic_time() - start

        :telemetry.execute(
          [:dps, :topic_client, :publish],
          %{duration: duration},
          %{
            topic: topic,
            event: event,
            payload: payload
          }
        )

        {:noreply, socket}
      end

      @impl true
      def handle_out(event, payload, socket) do
        start = System.monotonic_time()

        :ok = push(socket, "event", payload)

        duration = System.monotonic_time() - start

        :telemetry.execute(
          [:dps, :topic_channel, :handle_out],
          %{duration: duration},
          %{
            socket_id: socket.id,
            topic: socket.topic,
            event: event,
            payload: payload
          }
        )

        {:noreply, socket}
      end

      defp valid_topic_name?(topic_name) do
        if byte_size(topic_name) > 1 and byte_size(topic_name) <= 64 and
             Regex.match?(~r/^[a-zA-Z0-9]+$/, topic_name) do
          true
        else
          false
        end
      end

      defp report_join_error do
        {:error,
         "invalid topic name, must be between 2 and 64 characters long and only contain alphanumeric characters"}
      end
    end
  end
end
