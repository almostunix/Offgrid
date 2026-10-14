# MQTT Fixtures for Victron Cerbo GX

These fixture files represent MQTT messages from a Victron Cerbo GX device with a fake portal ID `c0ffee000001`.

Topic names follow Victron's [dbus/MQTT documentation](https://www.victronenergy.com/live/vebus:product_template:0:documentation) and are marked "to verify against the docs".

## History

History topics provide aggregated data over time periods. Topic names to verify against Victron's dbus documentation:

- `N/{portalId}/solarcharger/{deviceId}/History/Daily/{n}/{field}` - Daily history for solar charger (n=0 is today, n=29 is 29 days ago)
  - Yield: kWh (energy produced that day)
  - MaxPower: W (maximum power output)
  - MaxPvVoltage: V (maximum PV voltage)
  - TimeInBulk: s (time spent in bulk charging mode)

- `N/{portalId}/battery/{deviceId}/History/{field}` - Battery history statistics
  - ChargeCycles: count (number of full charge/discharge cycles)
  - DeepestDischarge: % (deepest discharge level reached)
  - AverageDischarge: % (average discharge level)
  - DischargedEnergy: Wh (total energy discharged)
  - ChargedEnergy: Wh (total energy charged)
  - TotalAhDrawn: Ah (total ampere-hours drawn)
  - MinimumVoltage: V (minimum voltage recorded)
  - MaximumVoltage: V (maximum voltage recorded)

## File Structure

- `system.json` - System-level data (battery SoC, power, time to go)
- `battery.json` - Battery monitor data (voltage, current, power, SoC)
- `battery_history.json` - Battery monitor history data (charge cycles, energy, voltage extremes)
- `solarcharger.json` - MPPT solar charger data (PV voltage, yield, power)
- `solarcharger_history.json` - MPPT solar charger history data (daily yield, max power, etc.)
- `vebus.json` - VE.Bus inverter/charger data (AC power, mode, state)
- `full_publish_completed.json` - Completion marker for full publish sequence

## Units

- Voltage: V
- Current: A  
- Power: W
- State of Charge: %
- Time to Go: s
- Energy: Wh/Ah
- Time: s
- Charge Cycles: count
- Ah: Ampere-hours

## Format

Each file contains:
```json
{"portalId": "c0ffee000001", "messages": [{"topic": "N/c0ffee000001/...", "payload": {"value": ...}}]}
```

The payload always contains a `value` key with the numeric or string value. Units are documented here, not in the payload.
