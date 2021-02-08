defmodule SendServer do
  use GenServer

  def init(args) do
    IO.puts("Received arguments: #{inspect(args)}")
    max_retries = Keyword.get(args, :max_retries, 5)
    state = %{emails: [], max_retries: max_retries}
    # To continue fetching from the database after init \
    # use the callback via handle continue
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
    Sender.send_email(email)
    state = [%{email: email, status: "sent", retries: 0}] ++ state.emails

    {:noreply, state}
  end
end
