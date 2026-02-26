#!/usr/bin/ucode

'use strict';

import * as fs from 'fs';
import { uci } from 'uconfig.uci';
import { phys as wiphy_phys } from 'uconfig.wiphy';

let channel_mode_priority = ['EHT', 'HE', 'VHT', 'HT'];

function best_channel_mode(modes) {
	for (let prio in channel_mode_priority)
		for (let m in modes)
			if (substr(m, 0, length(prio)) == prio)
				return prio;
	return null;
}

function radios_discover() {
	let radios = {};
	let seen = {};

	for (let phy in wiphy_phys) {
		for (let band_name, band_info in phy.bands) {
			if (seen[band_name])
				continue;
			seen[band_name] = true;

			let mode = best_channel_mode(band_info.modes);
			if (!mode)
				continue;

			let radio = { 'channel-mode': mode };

			if (band_name == '2G') {
				radio['channel-width'] = 20;
			} else if (band_name == '5G') {
				radio['channel-width'] = 80;
				radio.channel = 36;
			} else if (band_name == '6G') {
				radio['channel-width'] = 160;
			}

			radios[band_name] = radio;
		}
	}

	return radios;
}

let config_file = 'initial.json';
if (fs.stat('/etc/init.d/uconfig-ui'))
	config_file = 'webui.json';

let initial = fs.readfile('/etc/uconfig/examples/' + config_file);
initial = json(initial);

initial.uuid = time();
initial.unit ??= {
	hostname: uci.get('system', '@system[-1]', 'hostname'),
};
initial.radios = radios_discover();

let path = '/etc/uconfig/configs/uconfig.cfg.' + initial.uuid;
fs.writefile(path, sprintf('%.J', initial));
fs.symlink(path, '/etc/uconfig/configs/uconfig.active');
