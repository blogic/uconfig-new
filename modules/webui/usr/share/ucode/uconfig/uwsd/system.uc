'use strict';

import { token_generate } from 'uconfig.uwsd.upload';
import * as fs from 'fs';

const SYSUPGRADE_MAX_SIZE = 50 * 1024 * 1024;
const CONFIG_RESTORE_MAX_SIZE = 10 * 1024 * 1024;
const TOKEN_EXPIRY_SECONDS = 600;

export function token_generate_for_type(type) {
	if (type == 'sysupgrade')
		return token_generate(type, SYSUPGRADE_MAX_SIZE, TOKEN_EXPIRY_SECONDS);
	else if (type == 'config-restore')
		return token_generate(type, CONFIG_RESTORE_MAX_SIZE, TOKEN_EXPIRY_SECONDS);
	else
		return { error: 'Unknown upload type' };
};

export function sysupgrade_validate(file_path) {
	let exit_code = system(`sysupgrade --test ${file_path} 2>&1`);

	if (exit_code == 0)
		return { success: true };
	else
		return { success: false, error: `Firmware validation failed (exit code: ${exit_code})` };
};

export function sysupgrade_apply(file_path, keep_config, shutdown_handler) {
	let flags = keep_config ? '' : '-n';
	shutdown_handler('upgrading', () => {
		system(`sysupgrade ${flags} ${file_path}`);
	});
};

export function config_restore_validate(file_path) {
	try {
		let content = fs.readfile(file_path);
		let config = json(content);

		if (!config)
			return { success: false, error: 'Invalid JSON format' };

		return { success: true };
	} catch(e) {
		return { success: false, error: `Validation failed: ${e}` };
	}
};

export function config_restore_apply(file_path, shutdown_handler) {
	shutdown_handler('config-restore', () => {
		system(`uconfig-apply ${file_path}`);
		system('reboot');
	});
};

export function file_validate(file_path, type) {
	if (type == 'sysupgrade')
		return sysupgrade_validate(file_path);
	else if (type == 'config-restore')
		return config_restore_validate(file_path);
	else
		return { success: false, error: 'Unknown file type' };
};

export function file_apply(file_path, type, options, shutdown_handler) {
	if (type == 'sysupgrade')
		return sysupgrade_apply(file_path, options.keep_config || false, shutdown_handler);
	else if (type == 'config-restore')
		return config_restore_apply(file_path, shutdown_handler);
	else
		return { error: 'Unknown file type' };
};

export function validation_event_send(connections, type, success, file_id, error) {
	let event_name = success ? `${type}-validation-success` : `${type}-validation-failed`;
	let event = {
		jsonrpc: '2.0',
		method: event_name
	};

	if (success)
		event.params = { file_id: file_id };
	else
		event.params = { error: error };

	let data = sprintf('%.J', event);

	for (let name, conn in connections)
		conn.send(data);
};
