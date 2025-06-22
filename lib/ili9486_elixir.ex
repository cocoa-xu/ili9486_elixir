defmodule ILI9486 do
  @moduledoc """
  ILI9486 Elixir driver
  """

  use GenServer
  use Bitwise

  @enforce_keys [:gpio, :opts, :lcd_spi, :data_bus, :display_mode, :chunk_size]
  defstruct [
    :gpio,
    :opts,
    :lcd_spi,
    :touch_spi,
    :touch_pid,
    :pix_fmt,
    :rotation,
    :mad_mode,
    :data_bus,
    :display_mode,
    :frame_rate,
    :diva,
    :rtna,
    :chunk_size
  ]

  @doc """
  New connection to an ILI9486

  - **port**: SPI port number

    Default value: `0`

  - **lcd_cs**: LCD chip-selection number

    Default value: `0`.

  - **touch_cs**: (Optional) Touch panel chip-selection number

    Default value: `nil`.

  - **touch_irq**: (Optional) Touch panel interrupt. Low level while the Touch Panel detects touching

    Default value: `nil`.

  - **touch_speed_hz**: SPI Speed for the touch panel

    Default value: `50000`.

  - **dc**: Command/data register selection

    Default value: `24`.

  - **rst**: Reset pin for ILI9486

    Default value: `nil`.

  - **width**: Width of display connected to ILI9486

    Default value: `480`.

  - **height**: Height of display connected to ILI9486

    Default value: `320`.

  - **offset_top**: Offset to top row

    Default value: `0`.

  - **offset_left**: Offset to left column

    Default value: `0`.

  - **speed_hz**: SPI speed (in Hz)

    Default value: `16_000_000`.

  - **pix_fmt**: either `:bgr565`, `:rgb565`, `:bgr666` or `:rgb666`

    Default value: `:bgr565`.

  - **rotation**: Screen rotation.

    Default value: `90`. Only `0`, `90`, `180` and `270` are valid.

  - **mad_mode**: MAD mode.

    Default value: `:right_down`. Valid values: `:right_down`, `:right_up` and `:rgb_mode`

  - **display_mode**: Display mode.

    Default value: `:normal`. Enters normal display mode after initialization.

  - **frame_rate**: Frame rate.

    Default value: `70`. Valid frame rate should be one of the following:

    - 28
    - 30
    - 32
    - 34
    - 36
    - 39
    - 42
    - 46
    - 50
    - 56
    - 62
    - 70
    - 81
    - 96
    - 117

  - **diva**: Division ratio for internal clocks.

    Default value: `0b00`.

    - `0b00`: focs
    - `0b01`: focs/2
    - `0b10`: focs/4
    - `0b11`: focs/8

  - **rtna**: `RTNA[4:0]` is used to set 1H (line) period of Normal mode at CPU interface.

    Default value: `0b10001`. Valid value starts from `0b10000` (16 clocks) to `0b11111` (31 clocks), i.e.,
    clocks increases by 1 as `rtna` increasing by 1.

  - **is_high_speed**: Is the high speed variant?

    Default value: `false`. Set `true` to make it compatible with the high speed variant. (125MHz SPI).

  - **chunk_size**: batch transfer size.

    Default value: `4096` for the lo-speed variant. `0x8000` for the hi-speed variant.

  - **spi_lcd**: pre-opened SPI handle for the LCD bus.

    Default value: `nil`. If provided, overrides `:port` and `:lcd_cs`.

  - **spi_touch**: pre-opened SPI handle for the touch panel bus.

    Default value: `nil`. If provided, overrides `:port` and `:touch_cs`.

  - **gpio_dc**: pre-opened GPIO pin for the D/C line.

    Default value: `nil`. If provided, overrides `:dc`.

  - **gpio_rst**: pre-opened GPIO pin for the reset line.

    Default value: `nil`. If provided, overrides `:rst`.

  **return**: `%ILI9486{}`

  ## Example
  ```elixir
  # default
  # assuming LCD device at /dev/spidev0.0
  # DC connects to PIN 24
  # RST not connected
  # SPI speed: 16MHz
  # Pixel Format: BGR565
  {:ok, disp} = ILI9486.new()
  ```

  ```elixir
  # default with touch panel
  # DC connects to PIN 24
  # RST connects to PIN 25
  # SPI speed: 16MHz
  # Pixel Format: RGB666 (for demo only, not necessary)
  # Touch panel device at /dev/spidev0.1
  # Touch panel IRQ PIN 17
  {:ok, disp} = ILI9486.new(
    speed_hz: 16_000_000,
    pix_fmt: :bgr666,
    rst: 25,
    touch_cs: 1,
    touch_irq: 17
  )
  ```

  high-speed variant (125MHz SPI)
  ```elixir
  # assuming LCD device at /dev/spidev0.0
  # DC connects to PIN 24
  # RST connects to PIN 25 (for demo only, not necessary)
  # SPI speed: 125MHz
  # Pixel Format: BGR666 (for demo only, not necessary)
  {:ok, disp} = ILI9486.new(
    is_high_speed: true,
    speed_hz: 125_000_000,
    pix_fmt: :bgr666,
    rst: 25
  )
  ```

  high-speed variant (125MHz SPI) with touch panel
  ```elixir
  # assuming LCD device at /dev/spidev0.0
  # DC connects to PIN 24
  # RST connects to PIN 25 (for demo only, not necessary)
  # SPI speed: 125MHz
  # Pixel Format: BGR666 (for demo only, not necessary)
  # Touch panel device at /dev/spidev0.1
  # Touch panel IRQ PIN 17
  {:ok, disp} = ILI9486.new(
    is_high_speed: true,
    speed_hz: 125_000_000,
    pix_fmt: :bgr666,
    rst: 25,
    touch_cs: 1,
    touch_irq: 17
  )
  ```
  """
  @doc functions: :client
  def new(opts \\ []) do
    GenServer.start(__MODULE__, opts)
  end

  def new!(opts \\ []) do
    {:ok, self} = GenServer.start(__MODULE__, opts)
    self
  end

  @impl true
  def init(opts) do
    # Make sure terminate/2 is called on shutdown
    Process.flag(:trap_exit, true)

    port = opts[:port] || 0
    lcd_cs = opts[:lcd_cs] || 0
    touch_cs = opts[:touch_cs]
    touch_irq = opts[:touch_irq]
    dc = opts[:dc] || 24
    speed_hz = opts[:speed_hz] || 16_000_000
    touch_speed_hz = opts[:touch_speed_hz] || 50000
    width = opts[:width] || 480
    height = opts[:height] || 320
    offset_top = opts[:offset_top] || 0
    offset_left = opts[:offset_left] || 0
    rst = opts[:rst]
    pix_fmt = opts[:pix_fmt] || :bgr565
    rotation = opts[:rotation] || 90
    mad_mode = opts[:mad_mode] || :right_down
    display_mode = opts[:display_mode] || :normal
    frame_rate = opts[:frame_rate] || 70
    diva = opts[:diva] || 0b00
    rtna = opts[:rtna] || 0b10001
    is_high_speed = opts[:is_high_speed] || false
    chunk_size = opts[:chunk_size]

    chunk_size =
      if chunk_size == nil do
        if is_high_speed do
          Enum.min([0x8000, Circuits.SPI.max_transfer_size()])
        else
          Enum.min([4096, Circuits.SPI.max_transfer_size()])
        end
      else
        Enum.min([chunk_size, Circuits.SPI.max_transfer_size()])
      end

    # supported data connection
    # 8-bit parallel MCU interface for low speed ones
    #  - Waveshare RPi 3.5 LCD (A) / Tested
    #  - Waveshare RPi 3.5 LCD (B)
    # 16-bit parallel MCU interface for the high speed one
    #  - Waveshare RPi 3.5 LCD (C) / Tested
    # :parallel_16bit and :parallel_8bit supported colors
    #   - 65K colors
    #   - 262K colors
    data_bus = if is_high_speed, do: :parallel_16bit, else: :parallel_8bit

    lcd_spi =
      Keyword.get_lazy(opts, :spi_lcd, fn ->
        {:ok, bus} = _init_spi(port, lcd_cs, speed_hz)
        bus
      end)

    touch_spi =
      Keyword.get_lazy(opts, :spi_touch, fn ->
        if touch_cs do
          {:ok, bus} = _init_spi(port, touch_cs, touch_speed_hz)
          bus
        end
      end)

    gpio_dc =
      Keyword.get_lazy(opts, :gpio_dc, fn ->
        {:ok, pin} = Circuits.GPIO.open(dc, :output)
        pin
      end)

    gpio_rst =
      Keyword.get_lazy(opts, :gpio_rst, fn ->
        if rst, do: _init_reset(rst)
      end)

    {:ok, touch_pid} = _init_touch_irq(touch_irq)

    self =
      %ILI9486{
        lcd_spi: lcd_spi,
        touch_spi: touch_spi,
        touch_pid: touch_pid,
        gpio: [
          dc: gpio_dc,
          rst: gpio_rst
        ],
        opts: [
          port: port,
          lcd_cs: lcd_cs,
          touch_cs: touch_cs,
          dc: dc,
          speed_hz: speed_hz,
          touch_speed_hz: touch_speed_hz,
          width: width,
          height: height,
          offset_top: offset_top,
          offset_left: offset_left,
          rst: rst
        ],
        pix_fmt: pix_fmt,
        rotation: rotation,
        mad_mode: mad_mode,
        data_bus: data_bus,
        display_mode: display_mode,
        frame_rate: frame_rate,
        diva: diva,
        rtna: rtna,
        chunk_size: chunk_size
      }
      |> _reset()
      |> _init(is_high_speed)

    {:ok, self}
  end

  @impl true
  def terminate(_reason, %ILI9486{
        lcd_spi: lcd_spi,
        touch_spi: touch_spi,
        gpio: [dc: dc_pin, rst: rst_pin]
      }) do
    Circuits.SPI.close(lcd_spi)
    if touch_spi, do: Circuits.SPI.close(touch_spi)
    Circuits.GPIO.close(dc_pin)
    if rst_pin, do: Circuits.GPIO.close(rst_pin)
    :ok
  end

  @doc """
  Reset the display, if reset pin is connected.

  - **self**: `%ILI9486{}`

  **return**: `self`
  """
  @doc functions: :client
  def reset(self_pid) do
    GenServer.call(self_pid, :reset)
  end

  defp _reset(self = %ILI9486{gpio: gpio}) do
    gpio_rst = gpio[:rst]

    if gpio_rst != nil do
      Circuits.GPIO.write(gpio_rst, 1)
      :timer.sleep(500)
      Circuits.GPIO.write(gpio_rst, 0)
      :timer.sleep(500)
      Circuits.GPIO.write(gpio_rst, 1)
      :timer.sleep(500)
    end

    self
  end

  @doc """
  Get screen size

  - **self**: `%ILI9486{}`

  **return**: `%{height: height, width: width}`
  """
  @doc functions: :client
  def size(self_pid) do
    GenServer.call(self_pid, :size)
  end

  defp _size(%ILI9486{opts: opts}) do
    %{height: opts[:height], width: opts[:width]}
  end

  @doc """
  Get display pixel format

  - **self**: `%ILI9486{}`

  **return**: one of `:bgr565`, `:rgb565`, `:bgr666`, `:rgb666`
  """
  @doc functions: :client
  def pix_fmt(self_pid) do
    GenServer.call(self_pid, :pix_fmt)
  end

  defp _pix_fmt(%ILI9486{pix_fmt: pix_fmt}) do
    pix_fmt
  end

  @doc """
  Set display pixel format

  - **self**: `%ILI9486{}`
  - **pix_fmt**: one of `:bgr565`, `:rgb565`, :bgr666`, `:rgb666`

  **return**: `self`
  """
  @doc functions: :client
  def set_pix_fmt(self_pid, pix_fmt)
      when pix_fmt == :bgr565 or pix_fmt == :rgb565 or pix_fmt == :bgr666 or pix_fmt == :rgb666 do
    GenServer.call(self_pid, {:set_pix_fmt, pix_fmt})
  end

  defp _set_pix_fmt(self = %ILI9486{}, pix_fmt)
       when pix_fmt == :bgr565 or pix_fmt == :rgb565 or pix_fmt == :bgr666 or pix_fmt == :rgb666 do
    %ILI9486{self | pix_fmt: pix_fmt}
    |> _command(kMADCTL(), cmd_data: _mad_mode(self))
  end

  @doc """
  Turn on/off display

  - **self**: `%ILI9486{}`
  - **status**: either `:on` or `:off`

  **return**: `self`
  """
  @doc functions: :client
  def set_display(self_pid, status) when status == :on or status == :off do
    GenServer.call(self_pid, {:set_display, status})
  end

  defp _set_display(self = %ILI9486{}, :on) do
    _command(self, kDISPON())
  end

  defp _set_display(self = %ILI9486{}, :off) do
    _command(self, kDISPOFF())
  end

  @doc """
  Set display mode

  - **self**: `%ILI9486{}`
  - **display_mode**: Valid values: `:normal`, `:partial`, `:idle`

  **return**: `self`
  """
  @doc functions: :client
  def set_display_mode(self_pid, display_mode) do
    GenServer.call(self_pid, {:set_display_mode, display_mode})
  end

  defp _set_display_mode(self = %ILI9486{}, display_mode = :normal) do
    %ILI9486{self | display_mode: display_mode}
    |> _command(kNORON())
  end

  defp _set_display_mode(self = %ILI9486{}, display_mode = :partial) do
    %ILI9486{self | display_mode: display_mode}
    |> _command(kPTLON())
  end

  defp _set_display_mode(self = %ILI9486{}, display_mode = :idle) do
    %ILI9486{self | display_mode: display_mode}
    |> _command(self, kIDLEON())
  end

  @doc """
  Set frame rate

  - **self**: `%ILI9486{}`
  - **frame_rate**: Valid value should be one of the following
    - 28
    - 30
    - 32
    - 34
    - 36
    - 39
    - 42
    - 46
    - 50
    - 56
    - 62
    - 70
    - 81
    - 96
    - 117

  **return**: `:ok` | `{:error, reason}`
  """
  @doc functions: :client
  def set_frame_rate(self_pid, frame_rate) do
    GenServer.call(self_pid, {:set_frame_rate, frame_rate})
  end

  defp _set_frame_rate(
         self = %ILI9486{display_mode: display_mode, diva: diva, rtna: rtna},
         frame_rate
       ) do
    index = Enum.find_index(_valid_frame_rates(display_mode), fn valid -> valid == frame_rate end)

    p1 =
      index
      |> bsl(4)
      |> bor(diva)

    %ILI9486{self | frame_rate: frame_rate}
    |> _command(kFRMCTR1())
    |> _data(p1)
    |> _data(rtna)
  end

  defp _valid_frame_rates(:normal) do
    [28, 30, 32, 34, 36, 39, 42, 46, 50, 56, 62, 70, 81, 96, 117, 117]
  end

  @doc """
  Write the provided 16bit BGR565/RGB565 image to the hardware.

  - **self**: `%ILI9486{}`
  - **image_data**: Should be 16bit BGR565/RGB565 format (same channel order as in `self`) and
    the same dimensions (width x height x 3) as the display hardware.

  **return**: `self`
  """
  @doc functions: :client
  def display_565(self_pid, image_data) when is_binary(image_data) or is_list(image_data) do
    GenServer.call(self_pid, {:display_565, image_data})
  end

  defp _display_565(self, image_data) when is_binary(image_data) do
    _display_565(self, :binary.bin_to_list(image_data))
  end

  defp _display_565(self, image_data) when is_list(image_data) do
    self
    |> _set_window(x0: 0, y0: 0, x1: nil, y2: nil)
    |> _send(image_data, true, false)
  end

  @doc """
  Write the provided 18bit BGR666/RGB666 image to the hardware.

  - **self**: `%ILI9486{}`
  - **image_data**: Should be 18bit BGR666/RGB666 format (same channel order as in `self`) and
    the same dimensions (width x height x 3) as the display hardware.

  **return**: `self`
  """
  @doc functions: :client
  def display_666(self_pid, image_data) when is_binary(image_data) or is_list(image_data) do
    GenServer.call(self_pid, {:display_666, image_data})
  end

  defp _display_666(self, image_data) when is_binary(image_data) do
    _display_666(self, :binary.bin_to_list(image_data))
  end

  defp _display_666(self, image_data) when is_list(image_data) do
    self
    |> _set_window(x0: 0, y0: 0, x1: nil, y2: nil)
    |> _send(image_data, true, false)
  end

  @doc """
  Write the provided 24bit BGR888/RGB888 image to the hardware.

  - **self**: `%ILI9486{}`
  - **image_data**: Should be 24bit format and the same dimensions (width x height x 3) as the display hardware.
  - **pix_fmt**: Either `:rgb888` or `:bgr888`. Indicates the channel order of the provided `image_data`.

  **return**: `self`
  """
  @doc functions: :client
  def display(self_pid, image_data, source_color)
      when is_binary(image_data) and (source_color == :rgb888 or source_color == :bgr888) do
    GenServer.call(self_pid, {:display, image_data, source_color})
  end

  defp _display(self = %ILI9486{pix_fmt: target_color}, image_data, source_color)
       when is_binary(image_data) and (source_color == :rgb888 or source_color == :bgr888) and
              (target_color == :rgb565 or target_color == :bgr565) do
    _display_565(self, _to_565(image_data, source_color, target_color))
  end

  defp _display(self = %ILI9486{pix_fmt: target_color}, image_data, source_color)
       when is_binary(image_data) and (source_color == :rgb888 or source_color == :bgr888) and
              (target_color == :rgb666 or target_color == :bgr666) do
    _display_666(self, _to_666(image_data, source_color, target_color))
  end

  defp _display(self, image_data, source_color)
       when is_list(image_data) and (source_color == :rgb888 or source_color == :bgr888) do
    _display(
      self,
      Enum.map(image_data, &Enum.into(&1, <<>>, fn bit -> <<bit::8>> end)),
      source_color
    )
  end

  @doc """
  Set touch panel callback function

  - **self**: `%ILI9486{}`
  - **callback**: callback function. 3 arguments: `pin`, `timestamp`, `status`
  """
  @doc functions: :client
  def set_touch_callback(self_pid, callback) when is_function(callback) do
    GenServer.call(self_pid, {:set_touch_callback, callback})
  end

  defp _set_touch_callback(self = %ILI9486{touch_pid: touch_pid}, callback)
       when is_function(callback) do
    GPIOIRQDevice.set_callback(touch_pid, callback)
    self
  end

  @doc """
  Write a byte to the display as command data.

  - **self**: `%ILI9486{}`
  - **cmd**: command data
  - **opts**:
    - **cmd_data**: cmd data to be sent.
      Default value: `[]`. (no data will be sent)
    - **delay**: wait `delay` ms after the cmd data is sent
      Default value: `0`. (no wait)

  **return**: `self`
  """
  @doc functions: :client
  def command(self_pid, cmd, opts \\ []) when is_integer(cmd) do
    GenServer.call(self_pid, {:command, cmd, opts})
  end

  defp _command(self, cmd, opts \\ [])

  defp _command(self = %ILI9486{data_bus: :parallel_8bit}, cmd, opts) when is_integer(cmd) do
    cmd_data = opts[:cmd_data] || []
    delay = opts[:delay] || 0

    self
    |> _send(cmd, false, false)
    |> _data(cmd_data)

    :timer.sleep(delay)
    self
  end

  defp _command(self = %ILI9486{data_bus: :parallel_16bit}, cmd, opts) when is_integer(cmd) do
    cmd_data = opts[:cmd_data] || []
    delay = opts[:delay] || 0

    self
    |> _send(cmd, false, true)
    |> _data(cmd_data)

    :timer.sleep(delay)
    self
  end

  @doc """
  Write a byte or array of bytes to the display as display data.

  - **self**: `%ILI9486{}`
  - **data**: display data

  **return**: `self`
  """
  @doc functions: :client
  def data(_self_pid, []), do: :ok

  def data(self_pid, data) do
    GenServer.call(self_pid, {:data, data})
  end

  defp _data(self, []), do: self

  defp _data(self = %ILI9486{data_bus: :parallel_8bit}, data) do
    _send(self, data, true, false)
  end

  defp _data(self = %ILI9486{data_bus: :parallel_16bit}, data) do
    _send(self, data, true, true)
  end

  @doc """
  Send bytes to the ILI9486

  - **self**: `%ILI9486{}`
  - **bytes**: The bytes to be sent to `self`

    - `when is_integer(bytes)`,
      `sent` will take the 8 least-significant bits `[band(bytes, 0xFF)]`
      and send it to `self`
    - `when is_list(bytes)`, `bytes` will be casting to bitstring and then sent
      to `self`

  - **is_data**:

    - `true`: `bytes` will be sent as data
    - `false`: `bytes` will be sent as commands

  **return**: `self`
  """
  @doc functions: :client
  def send(self_pid, bytes, is_data)
      when (is_integer(bytes) or is_list(bytes)) and is_boolean(is_data) do
    GenServer.call(self_pid, {:send, bytes, is_data})
  end

  defp to_be_u16(u8_bytes) do
    u8_bytes
    |> Enum.map(fn u8 -> [0x00, u8] end)
    |> IO.iodata_to_binary()
  end

  defp chunk_binary(binary, chunk_size) when is_binary(binary) do
    total_bytes = byte_size(binary)
    full_chunks = div(total_bytes, chunk_size)

    chunks =
      if full_chunks > 0 do
        for i <- 0..(full_chunks - 1), reduce: [] do
          acc -> [:binary.part(binary, chunk_size * i, chunk_size) | acc]
        end
      else
        []
      end

    remaining = rem(total_bytes, chunk_size)

    chunks =
      if remaining > 0 do
        [:binary.part(binary, chunk_size * full_chunks, remaining) | chunks]
      else
        chunks
      end

    Enum.reverse(chunks)
  end

  defp _send(self, bytes, is_data, to_be16 \\ false)

  defp _send(self = %ILI9486{}, bytes, true, to_be16) do
    _send(self, bytes, 1, to_be16)
  end

  defp _send(self = %ILI9486{}, bytes, false, to_be16) do
    _send(self, bytes, 0, to_be16)
  end

  defp _send(self = %ILI9486{}, bytes, is_data, to_be16)
       when (is_data == 0 or is_data == 1) and is_integer(bytes) do
    _send(self, <<Bitwise.band(bytes, 0xFF)>>, is_data, to_be16)
  end

  defp _send(self = %ILI9486{}, bytes, is_data, to_be16)
       when (is_data == 0 or is_data == 1) and is_list(bytes) do
    _send(self, IO.iodata_to_binary(bytes), is_data, to_be16)
  end

  defp _send(
         self = %ILI9486{gpio: gpio, lcd_spi: spi, chunk_size: chunk_size},
         bytes,
         is_data,
         to_be16
       )
       when (is_data == 0 or is_data == 1) and is_binary(bytes) do
    gpio_dc = gpio[:dc]
    bytes = if to_be16, do: to_be_u16(:binary.bin_to_list(bytes)), else: bytes

    Circuits.GPIO.write(gpio_dc, is_data)

    for xfdata <- chunk_binary(bytes, chunk_size) do
      {:ok, _ret} = Circuits.SPI.transfer(spi, xfdata)
    end

    self
  end

  @impl true
  def handle_call(:reset, _from, self) do
    {:reply, :ok, _reset(self)}
  end

  @impl true
  def handle_call(:size, _from, self) do
    ret = _size(self)
    {:reply, ret, self}
  end

  @impl true
  def handle_call(:pix_fmt, _from, self) do
    ret = _pix_fmt(self)
    {:reply, ret, self}
  end

  @impl true
  def handle_call({:set_pix_fmt, pix_fmt}, _from, self) do
    {:reply, :ok, _set_pix_fmt(self, pix_fmt)}
  end

  @impl true
  def handle_call({:set_display, status}, _from, self) do
    {:reply, :ok, _set_display(self, status)}
  end

  @impl true
  def handle_call({:set_display_mode, display_mode}, _from, self) do
    {:reply, :ok, _set_display_mode(self, display_mode)}
  end

  @impl true
  def handle_call({:set_frame_rate, frame_rate}, _from, self) do
    {:reply, :ok, _set_frame_rate(self, frame_rate)}
  end

  @impl true
  def handle_call({:display_565, image_data}, _from, self) do
    {:reply, :ok, _display_565(self, image_data)}
  end

  @impl true
  def handle_call({:display_666, image_data}, _from, self) do
    {:reply, :ok, _display_666(self, image_data)}
  end

  @impl true
  def handle_call({:display, image_data, source_color}, _from, self) do
    {:reply, :ok, _display(self, image_data, source_color)}
  end

  @impl true
  def handle_call({:set_touch_callback, callback}, _from, self) do
    {:reply, :ok, _set_touch_callback(self, callback)}
  end

  @impl true
  def handle_call({:command, cmd, opts}, _from, self) do
    {:reply, :ok, _command(self, cmd, opts)}
  end

  @impl true
  def handle_call({:data, data}, _from, self) do
    {:reply, :ok, _data(self, data)}
  end

  @impl true
  def handle_call({:send, bytes, is_data}, _from, self) do
    {:reply, :ok, _send(self, bytes, is_data)}
  end

  defp _init_spi(_port, nil, _speed_hz), do: {:ok, nil}

  defp _init_spi(port, cs, speed_hz) when cs >= 0 do
    Circuits.SPI.open("spidev#{port}.#{cs}", speed_hz: speed_hz)
  end

  defp _init_spi(_port, _cs, _speed_hz), do: nil

  defp _init_touch_irq(nil), do: {:ok, nil}

  defp _init_touch_irq(pin) do
    GenServer.start_link(GPIOIRQDevice, pin)
  end

  defp _init_reset(nil), do: nil

  defp _init_reset(rst) when rst >= 0 do
    {:ok, gpio} = Circuits.GPIO.open(rst, :output)
    gpio
  end

  defp _init_reset(_), do: nil

  defp _get_channel_order(%ILI9486{pix_fmt: :rgb565}), do: kMAD_RGB()
  defp _get_channel_order(%ILI9486{pix_fmt: :bgr565}), do: kMAD_BGR()
  defp _get_channel_order(%ILI9486{pix_fmt: :rgb666}), do: kMAD_RGB()
  defp _get_channel_order(%ILI9486{pix_fmt: :bgr666}), do: kMAD_BGR()

  defp _get_pix_fmt(%ILI9486{pix_fmt: :rgb565}), do: k16BIT_PIX()
  defp _get_pix_fmt(%ILI9486{pix_fmt: :bgr565}), do: k16BIT_PIX()
  defp _get_pix_fmt(%ILI9486{pix_fmt: :rgb666}), do: k18BIT_PIX()
  defp _get_pix_fmt(%ILI9486{pix_fmt: :bgr666}), do: k18BIT_PIX()

  defp _mad_mode(self = %ILI9486{rotation: 0, mad_mode: :right_down}) do
    self
    |> _get_channel_order()
    |> bor(kMAD_X_RIGHT())
    |> bor(kMAD_Y_DOWN())
  end

  defp _mad_mode(self = %ILI9486{rotation: 90, mad_mode: :right_down}) do
    self
    |> _get_channel_order()
    |> bor(kMAD_X_LEFT())
    |> bor(kMAD_Y_DOWN())
    |> bor(kMAD_VERTICAL())
  end

  defp _mad_mode(self = %ILI9486{rotation: 180, mad_mode: :right_down}) do
    self
    |> _get_channel_order()
    |> bor(kMAD_X_LEFT())
    |> bor(kMAD_Y_UP())
  end

  defp _mad_mode(self = %ILI9486{rotation: 270, mad_mode: :right_down}) do
    self
    |> _get_channel_order()
    |> bor(kMAD_X_RIGHT())
    |> bor(kMAD_Y_UP())
    |> bor(kMAD_VERTICAL())
  end

  defp _mad_mode(self = %ILI9486{rotation: 0, mad_mode: :right_up}) do
    self
    |> _get_channel_order()
    |> bor(kMAD_X_RIGHT())
    |> bor(kMAD_Y_UP())
  end

  defp _mad_mode(self = %ILI9486{rotation: 90, mad_mode: :right_up}) do
    self
    |> _get_channel_order()
    |> bor(kMAD_X_RIGHT())
    |> bor(kMAD_Y_DOWN())
    |> bor(kMAD_VERTICAL())
  end

  defp _mad_mode(self = %ILI9486{rotation: 180, mad_mode: :right_up}) do
    self
    |> _get_channel_order()
    |> bor(kMAD_X_LEFT())
    |> bor(kMAD_Y_DOWN())
  end

  defp _mad_mode(self = %ILI9486{rotation: 270, mad_mode: :right_up}) do
    self
    |> _get_channel_order()
    |> bor(kMAD_X_LEFT())
    |> bor(kMAD_Y_UP())
    |> bor(kMAD_VERTICAL())
  end

  defp _mad_mode(self = %ILI9486{rotation: 0, mad_mode: :rgb_mode}) do
    self
    |> _get_channel_order()
    |> bor(kMAD_X_LEFT())
    |> bor(kMAD_Y_DOWN())
  end

  defp _mad_mode(self = %ILI9486{rotation: 90, mad_mode: :rgb_mode}) do
    self
    |> _get_channel_order()
    |> bor(kMAD_X_RIGHT())
    |> bor(kMAD_Y_DOWN())
  end

  defp _mad_mode(self = %ILI9486{rotation: 180, mad_mode: :rgb_mode}) do
    self
    |> _get_channel_order()
    |> bor(kMAD_X_RIGHT())
    |> bor(kMAD_Y_UP())
  end

  defp _mad_mode(self = %ILI9486{rotation: 270, mad_mode: :rgb_mode}) do
    self
    |> _get_channel_order()
    |> bor(kMAD_X_LEFT())
    |> bor(kMAD_Y_UP())
  end

  defp _init(self = %ILI9486{frame_rate: frame_rate}, false) do
    self
    # software reset
    |> _command(kSWRESET(), delay: 120)
    # RGB mode off
    |> _command(kRGB_INTERFACE(), cmd_data: 0x00)
    # turn off sleep mode
    |> _command(kSLPOUT(), delay: 200)
    # interface format
    |> _command(kPIXFMT(), cmd_data: _get_pix_fmt(self))
    |> _command(kMADCTL(), cmd_data: _mad_mode(self))
    |> _command(kPWCTR3(), cmd_data: 0x44)
    |> _command(kVMCTR1())
    |> _data(0x00)
    |> _data(0x00)
    |> _data(0x00)
    |> _data(0x00)
    |> _command(kGMCTRP1())
    |> _data(0x0F)
    |> _data(0x1F)
    |> _data(0x1C)
    |> _data(0x0C)
    |> _data(0x0F)
    |> _data(0x08)
    |> _data(0x48)
    |> _data(0x98)
    |> _data(0x37)
    |> _data(0x0A)
    |> _data(0x13)
    |> _data(0x04)
    |> _data(0x11)
    |> _data(0x0D)
    |> _data(0x00)
    |> _command(kGMCTRN1())
    |> _data(0x0F)
    |> _data(0x32)
    |> _data(0x2E)
    |> _data(0x0B)
    |> _data(0x0D)
    |> _data(0x05)
    |> _data(0x47)
    |> _data(0x75)
    |> _data(0x37)
    |> _data(0x06)
    |> _data(0x10)
    |> _data(0x03)
    |> _data(0x24)
    |> _data(0x20)
    |> _data(0x00)
    |> _command(kDGCTR1())
    |> _data(0x0F)
    |> _data(0x32)
    |> _data(0x2E)
    |> _data(0x0B)
    |> _data(0x0D)
    |> _data(0x05)
    |> _data(0x47)
    |> _data(0x75)
    |> _data(0x37)
    |> _data(0x06)
    |> _data(0x10)
    |> _data(0x03)
    |> _data(0x24)
    |> _data(0x20)
    |> _data(0x00)
    |> _set_display_mode(:normal)
    |> _command(kINVOFF())
    |> _command(kSLPOUT(), delay: 200)
    |> _command(kDISPON())
    |> _set_frame_rate(frame_rate)
  end

  defp _init(self = %ILI9486{frame_rate: frame_rate}, true) do
    self
    # software reset
    |> _command(kSWRESET(), delay: 120)
    # RGB mode off
    |> _command(kRGB_INTERFACE(), cmd_data: 0x00)
    # turn off sleep mode
    |> _command(kSLPOUT(), delay: 250)
    # interface format
    |> _command(kPIXFMT(), cmd_data: _get_pix_fmt(self))
    |> _command(kPWCTR3(), cmd_data: 0x44)
    |> _command(kVMCTR1(), cmd_data: [0x00, 0x00, 0x00, 0x00])
    |> _command(kGMCTRP1())
    |> _data(0x0F)
    |> _data(0x1F)
    |> _data(0x1C)
    |> _data(0x0C)
    |> _data(0x0F)
    |> _data(0x08)
    |> _data(0x48)
    |> _data(0x98)
    |> _data(0x37)
    |> _data(0x0A)
    |> _data(0x13)
    |> _data(0x04)
    |> _data(0x11)
    |> _data(0x0D)
    |> _data(0x00)
    |> _command(kGMCTRN1())
    |> _data(0x0F)
    |> _data(0x32)
    |> _data(0x2E)
    |> _data(0x0B)
    |> _data(0x0D)
    |> _data(0x05)
    |> _data(0x47)
    |> _data(0x75)
    |> _data(0x37)
    |> _data(0x06)
    |> _data(0x10)
    |> _data(0x03)
    |> _data(0x24)
    |> _data(0x20)
    |> _data(0x00)
    |> _command(kDGCTR1())
    |> _data(0x0F)
    |> _data(0x32)
    |> _data(0x2E)
    |> _data(0x0B)
    |> _data(0x0D)
    |> _data(0x05)
    |> _data(0x47)
    |> _data(0x75)
    |> _data(0x37)
    |> _data(0x06)
    |> _data(0x10)
    |> _data(0x03)
    |> _data(0x24)
    |> _data(0x20)
    |> _data(0x00)
    |> _set_display_mode(:normal)
    |> _command(kINVOFF())
    |> _command(kDISPON(), delay: 100)
    |> _command(kMADCTL(), cmd_data: _mad_mode(self))
    |> _set_frame_rate(frame_rate)
  end

  defp _set_window(self = %ILI9486{opts: board}, opts = [x0: 0, y0: 0, x1: nil, y2: nil]) do
    width = board[:width]
    height = board[:height]
    offset_top = board[:offset_top]
    offset_left = board[:offset_left]
    x0 = opts[:x0]
    x1 = opts[:x1]
    x1 = if x1 == nil, do: width - 1
    y0 = opts[:y0]
    y1 = opts[:y1]
    y1 = if y1 == nil, do: height - 1
    y0 = y0 + offset_top
    y1 = y1 + offset_top
    x0 = x0 + offset_left
    x1 = x1 + offset_left

    self
    |> _command(kCASET())
    |> _data(bsr(x0, 8))
    |> _data(band(x0, 0xFF))
    |> _data(bsr(x1, 8))
    |> _data(band(x1, 0xFF))
    |> _command(kPASET())
    |> _data(bsr(y0, 8))
    |> _data(band(y0, 0xFF))
    |> _data(bsr(y1, 8))
    |> _data(band(y1, 0xFF))
    |> _command(kRAMWR())
  end

  defp _to_565(image_data, source_color, target_color)
       when is_binary(image_data) do
    image_data
    |> CvtColor.cvt(source_color, target_color)
    |> :binary.bin_to_list()
  end

  defp _to_666(image_data, :bgr888, :bgr666)
       when is_binary(image_data) do
    image_data
    |> :binary.bin_to_list()
  end

  defp _to_666(image_data, source_color, target_color)
       when is_binary(image_data) do
    image_data
    |> CvtColor.cvt(source_color, target_color)
    |> :binary.bin_to_list()
  end

  @doc functions: :constants
  def kNOP, do: 0x00
  @doc functions: :constants
  def kSWRESET, do: 0x01

  @doc functions: :constants
  def kRDDID, do: 0x04
  @doc functions: :constants
  def kRDDST, do: 0x09
  @doc functions: :constants
  def kRDMODE, do: 0x0A
  @doc functions: :constants
  def kRDMADCTL, do: 0x0B
  @doc functions: :constants
  def kRDPIXFMT, do: 0x0C
  @doc functions: :constants
  def kRDIMGFMT, do: 0x0D
  @doc functions: :constants
  def kRDSELFDIAG, do: 0x0F

  @doc functions: :constants
  def kSLPIN, do: 0x10
  @doc functions: :constants
  def kSLPOUT, do: 0x11
  @doc functions: :constants
  def kPTLON, do: 0x12
  @doc functions: :constants
  def kNORON, do: 0x13

  @doc functions: :constants
  def kINVOFF, do: 0x20
  @doc functions: :constants
  def kINVON, do: 0x21
  @doc functions: :constants
  def kGAMMASET, do: 0x26
  @doc functions: :constants
  def kDISPOFF, do: 0x28
  @doc functions: :constants
  def kDISPON, do: 0x29

  @doc functions: :constants
  def kCASET, do: 0x2A
  @doc functions: :constants
  def kPASET, do: 0x2B
  @doc functions: :constants
  def kRAMWR, do: 0x2C
  @doc functions: :constants
  def kRAMRD, do: 0x2E

  @doc functions: :constants
  def kPTLAR, do: 0x30
  @doc functions: :constants
  def kVSCRDEF, do: 0x33
  @doc functions: :constants
  def kMADCTL, do: 0x36
  @doc functions: :constants
  # Vertical Scrolling Start Address
  def kVSCRSADD, do: 0x37
  @doc functions: :constants
  def kIDLEOFF, do: 0x38
  @doc functions: :constants
  def kIDLEON, do: 0x39
  @doc functions: :constants
  # COLMOD: Pixel Format Set
  def kPIXFMT, do: 0x3A

  @doc functions: :constants
  # RGB Interface Signal Control
  def kRGB_INTERFACE, do: 0xB0
  @doc functions: :constants
  def kFRMCTR1, do: 0xB1
  @doc functions: :constants
  def kFRMCTR2, do: 0xB2
  @doc functions: :constants
  def kFRMCTR3, do: 0xB3
  @doc functions: :constants
  def kINVCTR, do: 0xB4
  # Display Function Control
  @doc functions: :constants
  def kDFUNCTR, do: 0xB6

  @doc functions: :constants
  def kPWCTR1, do: 0xC0
  @doc functions: :constants
  def kPWCTR2, do: 0xC1
  @doc functions: :constants
  def kPWCTR3, do: 0xC2
  @doc functions: :constants
  def kPWCTR4, do: 0xC3
  @doc functions: :constants
  def kPWCTR5, do: 0xC4
  @doc functions: :constants
  def kVMCTR1, do: 0xC5
  @doc functions: :constants
  def kVMCTR2, do: 0xC7

  @doc functions: :constants
  def kRDID1, do: 0xDA
  @doc functions: :constants
  def kRDID2, do: 0xDB
  @doc functions: :constants
  def kRDID3, do: 0xDC
  @doc functions: :constants
  def kRDID4, do: 0xDD

  @doc functions: :constants
  def kGMCTRP1, do: 0xE0
  @doc functions: :constants
  def kGMCTRN1, do: 0xE1
  @doc functions: :constants
  def kDGCTR1, do: 0xE2
  @doc functions: :constants
  def kDGCTR2, do: 0xE3

  @doc functions: :constants
  def kMAD_RGB, do: 0x08
  @doc functions: :constants
  def kMAD_BGR, do: 0x00
  @doc functions: :constants
  def k18BIT_PIX, do: 0x66
  @doc functions: :constants
  def k16BIT_PIX, do: 0x55

  @doc functions: :constants
  def kMAD_VERTICAL, do: 0x20
  @doc functions: :constants
  def kMAD_X_LEFT, do: 0x00
  @doc functions: :constants
  def kMAD_X_RIGHT, do: 0x40
  @doc functions: :constants
  def kMAD_Y_UP, do: 0x80
  @doc functions: :constants
  def kMAD_Y_DOWN, do: 0x00

  @doc functions: :constants
  def kHISPEEDF1, do: 0xF1
  @doc functions: :constants
  def kHISPEEDF2, do: 0xF2
  @doc functions: :constants
  def kHISPEEDF8, do: 0xF8
  @doc functions: :constants
  def kHISPEEDF9, do: 0xF9
end
