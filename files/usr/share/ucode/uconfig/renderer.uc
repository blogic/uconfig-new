"use strict";

global.topdir = sourcepath(0, true);

import * as fs from 'fs';
global.fs = fs;

import { uci } from 'uconfig.uci';
import * as ubus from 'ubus';
import * as board_json from 'uconfig.board_json';
global.board_json = board_json;

import * as ethernet from 'uconfig.ethernet';
import * as routing_table from 'uconfig.routing_table';
import * as shell from 'uconfig.shell';
import * as wiphy from 'uconfig.wiphy';
import * as ipcalc from 'uconfig.ipcalc';
import * as port from 'uconfig.port';

import { readjson } from 'uconfig.files';

import {
	b,
	s,
	uci_set_string,
	uci_set_boolean,
	uci_set_number,
	uci_set_raw,
	uci_list_string,
	uci_list_number,
	uci_section,
	uci_named_section,
	uci_set,
	uci_list,
	uci_output,
	uci_comment
} from 'uconfig.uci_helpers';

function tryinclude(path, scope) {
	if (!match(path, /^[A-Za-z0-9_\/-]+\.uc$/)) {
		warn("Refusing to handle invalid include path '%s'", path);
		return;
	}

	let parent_path = sourcepath(1, true);

	assert(parent_path, "Unable to determine calling template path");

	try {
		include(parent_path + "/" + path, scope);
	}
	catch (e) {
		warn("Unable to include path '%s': %s\n%s", path, e, e.stacktrace[0].context);
	}
}

let serial = uci.get("uconfig", "config", "serial");

export function generate(state, logs, scope) {
	logs = logs || [];

	ethernet.init();
	ipcalc.init();
	routing_table.init();
	port.init();

	return render('templates/toplevel.uc', {
		b,
		s,
		uci_set_string,
		uci_set_boolean,
		uci_set_number,
		uci_set_raw,
		uci_list_string,
		uci_list_number,
		uci_section,
		uci_named_section,
		uci_set,
		uci_list,
		uci_output,
		uci_comment,
		tryinclude,
		readjson,
		state,

		location: '/',
		serial,
		board: board_json.board,

		uci,
		ubus,
		ethernet,
		ipcalc,
		routing_table,
		shell,
		wiphy,
		port,

		...scope,

		warn: (fmt, ...args) => push(logs, sprintf("[W] (In %s) ", location || '/') + sprintf(fmt, ...args)),

		error: (fmt, ...args) => push(logs, sprintf("[E] (In %s) ", location || '/') + sprintf(fmt, ...args)),

		info: (fmt, ...args) => push(logs, sprintf("[!] (In %s) ", location || '/') + sprintf(fmt, ...args))
	});
};
