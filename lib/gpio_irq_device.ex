defmodule GPIOIRQDevice do
  use GenServer

  def set_callback(pid, callback) when is_function(callback) do
    GenServer.call(pid, {:set_callback, callback})
  end

  @impl true
  def init(irq_pin) do
    {:ok, gpio} = Circuits.GPIO.open(irq_pin, :input)
    {:ok, gpio}
  end

  @impl true
  def handle_call({:set_callback, callback}, _from, gpio) when is_function(callback) do
    child = spawn(GPIOIRQDevice, :irq_event_loop_init, [gpio, callback])
    {:reply, child, gpio}
  end

  def irq_event_loop_init(gpio, callback) do
    Circuits.GPIO.set_interrupts(gpio, :both)
    irq_event_loop(gpio, callback)
  end

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
