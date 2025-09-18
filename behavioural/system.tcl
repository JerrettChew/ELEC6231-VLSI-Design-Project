
# system.tcl

simvision {

  # Open new waveform window
  
    window new WaveWindow -name "Waves for Example Sports Altimeter Design"
    waveform using "Waves for Example Sports Altimeter Design"

  # add Clock and nReset to wave window
  
    waveform  add -signals  system.Clock
    waveform  add -signals  system.nReset

  # add pressure to wave window as sampled analogue signal
  
    set id [ waveform  add -signals  system.SENSOR.pressure ]
    waveform format $id -trace analogSampleAndHold
    waveform axis range $id -min 850 -max 1150 -scale linear


  # add remaining altimeter I/O to wave window
  
    waveform  add -signals  system.nMode
    waveform  add -signals  system.nTrip
    waveform  add -signals  system.SCL
    waveform  add -signals  system.SDA
    waveform  add -signals  system.RS
    waveform  add -signals  system.RnW
    waveform  add -signals  system.E
    waveform  add -signals  system.DB
    waveform  add -signals  system.mode_index

    
}

# =========================================================================
# Probe

  # Any signals included in register window but not in waveform window
  # should be probed
  
# =========================================================================
