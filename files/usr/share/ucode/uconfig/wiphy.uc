'use strict';

import * as fs from 'fs';
import * as uci from 'uci';
import * as nl from 'nl80211';

let cursor = uci ? uci.cursor() : null;
let paths = {};
let board = json(fs.readfile('/etc/board.json'));

export let phys = [];

function lookup_phys() {
	for (let phy, data in board?.wlan) {
		if (!data.info)
			continue;
		data.info.phy = phy;
		data.info.path = data.path;
		push(phys, data.info);
	}
}

/**
 * Convert a wireless channel to a wireless frequency
 *
 * @param {string} wireless band
 * @param {number} channel
 *
 * @returns {?number}
 * Returns the coverted wireless frequency for this specific
 * channel.
 */
export function channel_to_freq(band, channel) {
	if (band == '2G' && channel >= 1 && channel <= 13)
		return 2407 + channel * 5;
	else if (band == '2G' && channel == 14)
		return 2484;
	else if (band == '5G' && channel >= 7 && channel <= 177)
		return 5000 + channel * 5;
	else if (band == '5G' && channel >= 183 && channel <= 196)
		return 4000 + channel * 5;
	else if (band == '60G' && channel >= 1 && channel <= 6)
		return 56160 + channel * 2160;

	return null;
};

/**
 * Convert the unique sysfs path describing a wireless PHY to
 * the corresponding UCI section name
 *
 * @param {string} path
 *
 * @returns {string|false}
 * Returns the UCI section name of a specific PHY
 */
export function phy_to_section(path) {
	let sid = null;

	cursor.load("wireless");
	cursor.foreach("wireless", "wifi-device", (s) => {
		if (s.path == path && s.scanning != 1) {
			sid = s['.name'];

			return false;
		}
	});

	return sid;
};

/**
 * Get a list of all wireless PHYs for a specific name/band
 *
 * @param {string} name
 *
 * @returns {object[]}
 * Returns an array of wireless PHYs
 */
export function lookup(name) {
	let ret = [];

	for (let idx, phy in phys)
		if (phy.phy == name || phy.bands[name]) {
			let sid = phy_to_section(phy.path);
			if (sid)
				push(ret, { ...phy, section: sid });
		}

	return ret;
};

lookup_phys();
