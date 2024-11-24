defmodule DPS.TopicRouter do
  alias ExHashRing.Ring

  @process_group "topic_servers"

  @spec join_process_group(pid()) :: :ok
  def join_process_group(pid) do
    :ok = :pg.join(DPS.PG, @process_group, pid)
  end

  @spec resolve_topic_server_worker_pid(binary()) :: {:ok, pid()} | :error
  def resolve_topic_server_worker_pid(topic) do
    {:ok, node_name} = Ring.find_node(DPS.Ring, topic)

    members = :pg.get_members(DPS.PG, @process_group)

    topic_server_worker_pids =
      members |> Enum.filter(&(to_string(node(&1)) == node_name))

    if length(topic_server_worker_pids) > 0 do
      pid = Enum.random(topic_server_worker_pids)

      if pid == nil do
        {:error}
      else
        {:ok, pid}
      end
    else
      {:error}
    end
  end


end
