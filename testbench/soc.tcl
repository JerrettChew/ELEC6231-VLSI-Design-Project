# SimVision command script soc.tcl

simvision {

  # Open new waveform window

    window new WaveWindow  -name  "Waves for SoC Example (ASIC version)"
    waveform  using  "Waves for SoC Example (ASIC version)"

  # Add Waves

    waveform  add  -signals  soc_stim.HCLK
    waveform  add  -signals  soc_stim.HRESETn
    waveform  add  -signals  soc_stim.RS
    waveform  add  -signals  soc_stim.RnW
    waveform  add  -signals  soc_stim.E
    waveform  add  -signals  soc_stim.DB
    waveform  add  -signals  soc_stim.SCL
    waveform  add  -signals  soc_stim.SDA_out
    waveform  add  -signals  soc_stim.SDA_in
    waveform  add  -signals  soc_stim.LOCKUP
    waveform  add  -signals  soc_stim.dut.HADDR
    waveform  add  -signals  soc_stim.dut.HRDATA
    waveform  add  -signals  soc_stim.dut.HWDATA
    waveform  add  -signals  soc_stim.dut.HWRITE
    waveform  add  -signals  soc_stim.dut.HSEL_ROM
    waveform  add  -signals  soc_stim.dut.HSEL_RAM
    waveform  add  -signals  soc_stim.dut.HSEL_BUTTON
    waveform  add  -signals  soc_stim.dut.HSEL_LCD
    waveform  add  -signals  soc_stim.dut.HSEL_I2C

}

