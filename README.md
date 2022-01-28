# ILI9486-Elixir

ILI9486 driver for Elixir.

Tested on 
- Waveshare 3.5" SPI LCD RPi LCD (A) (480x320). 16MHz
- Waveshare 3.5" SPI LCD RPi LCD (C) (480x320). 125MHz

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

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ili9486_elixir` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ili9486_elixir, "~> 0.1.3"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/ili9486_elixir](https://hexdocs.pm/ili9486_elixir).
