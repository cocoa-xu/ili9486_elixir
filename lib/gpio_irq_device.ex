defmodule GPIOIRQDevice do
  @moduledoc """
  GenServer that listens for Circuits.GPIO interrupts and forwards them to a user callback.
  """

  use GenServer

  @typedoc "IRQ pin number"
  @type irq_pin :: non_neg_integer()

  @typedoc "IRQ timestamp (from Circuits.GPIO)"
  @type irq_timestamp :: non_neg_integer()

  @typedoc "IRQ status value"
  @type irq_status :: 0 | 1

  @typedoc "Callback invoked on IRQ"
  @type irq_callback :: (irq_pin(), irq_timestamp(), irq_status() -> any())

  @doc """
  Set the IRQ callback. Returns the pid of the spawned listener process.
  """
  @spec set_callback(pid(), irq_callback()) :: pid()
  def set_callback(pid, callback) when is_function(callback, 3) do
    GenServer.call(pid, {:set_callback, callback})
  end

  @impl true
  @spec init(irq_pin()) :: {:ok, any()}
  def init(irq_pin) do
    {:ok, gpio} = Circuits.GPIO.open(irq_pin, :input)
    {:ok, gpio}
  end

  @impl true
  @spec handle_call({:set_callback, irq_callback()}, GenServer.from(), any()) ::
          {:reply, pid(), any()}
  def handle_call({:set_callback, callback}, _from, gpio) when is_function(callback, 3) do
    child = spawn(GPIOIRQDevice, :irq_event_loop_init, [gpio, callback])
    {:reply, child, gpio}
  end

  @spec irq_event_loop_init(any(), irq_callback()) :: no_return()
  def irq_event_loop_init(gpio, callback) do
    :ok = Circuits.GPIO.set_interrupts(gpio, :both)
    irq_event_loop(gpio, callback)
  end

  @spec irq_event_loop(any(), irq_callback()) :: no_return()
  def irq_event_loop(gpio, callback) do
    receive do
      {:circuits_gpio, pin, ts, status} ->
        callback.(pin, ts, status)
        irq_event_loop(gpio, callback)

      "error" <> _ ->
        irq_event_loop_init(gpio, callback)

      _msg ->
        irq_event_loop(gpio, callback)
    end
  end
end
