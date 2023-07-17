# Monitor home water usage in Home Assistant using RTL-SDR 

An work-in-progress solution for monitoring water usage in Home Assistant using an RTL-SDR and a Raspberry Pi. 
This functionally captures the reading of my Neptune E-Coder R900i water meter in Saint Paul, MN and should work and should work for every home in this city. YMMV in other locations or with other meters.

Using a [Nooelec RTL-SDR v5](https://www.amazon.com/gp/product/B01GDN1T4S?psc=1) and a [Raspberry Pi](https://rpilocator.com/), one can wirelessly capture the same unencrypted water meter readings that the city uses for billing. 

## Prerequisites
- I have this running on [Debian](https://raspi.debian.net/) on a Raspberry Pi 4B. The compute demands of this are minimal and this could certainly run on less powerful hardware.
- Build rtl-sdr from source. I found this to be a bit tricky, [these instructions](https://gist.github.com/floehopper/99a0c8931f9d779b0998) helped. 
- Install Go. I had issues with the `apt` package and found that [downloading and installing the binary directly](https://www.jeremymorgan.com/tutorials/raspberry-pi/install-go-raspberry-pi/) worked best.
- Install `stdout_httpd` and `rtlamr`
  - `go install github.com/abaker/stdout_httpd@latest`
  - `go install github.com/bemasher/rtlamr@latest`
 
## Listen for broadcasted events
With `rtl-tcp` running, have `rtlamr` listen for message type `r900` on frequency `912 Mhz`. Filter out the noise of your neighbor's meters by using the serial number displayed on top of the meter, below the display. 
```bash
./go/bin/rtlamr -msgtype=r900 -centerfreq=912000000 -filterid=WATER_METER_SERIAL_NUMBER
```

Once you are successfully reading the meter, edit `watermeter.sh` to include your serial number. If you are not seeing a reading, you can force a updated reading by turning on the faucet. New readings are normally broadcast roughly once per minute.

The script will automatically run the required software, and publish the required information in JSON on port 8080.
Example output: 
```json
{
  "Time": "2023-07-17T01:21:13.591313046+01:00",
  "Offset": 0,
  "Length": 0,
  "Type": "R900",
  "ID": WATER_METER_SERIAL_NUMBER,
  "Unkn1": 163,
  "NoUse": 0,
  "BackFlow": 0,
  "Consumption": 6162823,
  "Unkn3": 0,
  "Leak": 1,
  "LeakNow": 0
}
```

## Run automatically 
The script can be set to run automatically at startup or after a crash (RTL-SDR adapter can be somewhat unreliable) by following the instructions commented in [watermeter.service](https://github.com/gunnaraas/watermeter/blob/main/watermeter.service)

## Configuration in Home Assistant 
Once configured, the readings can be input in Home Assistant using a REST integration. 

Add the following to your `configuration.yaml`: 
```yaml
  - platform: rest
    name: Water Meter (gal)
    resource: http://IP_ADDRESS_OF_RASPBERRYPI:8080
    force_update: true
    value_template: "{{ value_json.Consumption | float / 100 * 7.48 | round }}"
    unit_of_measurement: "gal"
    device_class: water
    state_class: total_increasing
    json_attributes:
      - Time
      - BackFlow
      - Consumption
      - Leak
      - LeakNow
```

Note that the R900i meter reports readings in cubic yards. The `Consumption` variable also leaves out the decimal place. For example, the output in the example above is actually `61,628.23 yd^3`. This is adjusted with `value_template: ... float / 100 ...` 

This isn't a super useful unit for me to measure day-to-day water usage in, so I convert it to gallons in `value_template`. Update accordingly based on your preferred units.

After a restart, the water meter entity should begin populating. Water meter can be read added to the Energy tab for a nice visualization of your resource usage: 
![](https://files.catbox.moe/5z10f2.png)

## Future improvements
There's a lot of room for improvement in this patchwork solution. Ideally I'd like to get this containerized and packaged as a Home Assistant Add-On when capacity allows, or otherwise get this more cleanly scripted for easier setup in the future. Feedback, contributions, and future interations are welcomed and encouraged. 
