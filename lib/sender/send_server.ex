defmodule SendServer do
  use GenServer

  def init(args) do
    IO.puts("Received arguments: #{inspect(args)}")
    max_retries = Keyword.get(args, :max_retries, 5)
    state = %{emails: [], max_retries: max_retries}
    # To continue fetching from the database after init \
    # use the callback via handle continue
    Process.send_after(self(), :retry, 5000)
    {:ok, state, {:continue, :fetch_from_database}}
  end

  def handle_continue(:fetch_from_database, state) do
    # called after init/1
    {:noreply, %{state | max_retries: 2}}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:send, email}, state) do
    status =
      case Sender.send_email(email) do
        {:ok, "email sent"} -> "sent"
        :error -> "failed"
      end

    emails = [%{email: email, status: status, retries: 0}] ++ state.emails
    IO.inspect(emails)
    {:noreply, Map.put(state, :emails, emails)}
  end

  def handle_info(:retry, state) do
    {failed, done} =
      Enum.split_with(state.emails, fn item ->
        item.status == "failed" && item.retries < state.max_retries
      end)

    retried =
      Enum.map(failed, fn item ->
        IO.puts("retrying email #{item.email}..")

        new_status =
          case Sender.send_email(item.email) do
            {:ok, "email sent"} -> "sent"
            _ -> "failed"
          end

        %{email: item.email, status: new_status, retries: item.retries + 1}
      end)

    Process.send_after(self(), :retry, 5_000)
    {:noreply, Map.put(state, :emails, retried ++ done)}
  end
end
