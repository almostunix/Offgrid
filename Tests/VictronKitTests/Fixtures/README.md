# MQTT Fixtures for Victron Cerbo GX

These fixture files represent MQTT messages from a Victron Cerbo GX device with a fake portal ID `c0ffee000001`.

Topic names follow Victron's [dbus/MQTT documentation](https://www.victronenergy.com/live/vebus:product_template:0:documentation) and are marked "to verify against the docs".

## File Structure

- `system.json` - System-level data (battery SoC, power, time to go)
- `battery.json` - Battery monitor data (voltage, current, power, SoC)
- `solarcharger.json` - MPPT solar charger data (PV voltage, yield, power)
- `vebus.json` - VE.Bus inverter/charger data (AC power, mode, state)
- `full_publish_completed.json` - Completion marker for full publish sequence

## Units

- Voltage: V
- Current: A  
- Power: W
- State of Charge: %
- Time to Go: s
- Energy: Wh/Ah

## Format

Each file contains:
```json
{"portalId": "c0ffee000001", "messages": [{"topic": "N/c0ffee000001/...", "payload": {"value": ...}}]}
```

The payload always contains a `value` key with the numeric or string value. Units are documented here, not in the payload.
