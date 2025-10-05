'use strict';

import * as fs from 'fs';

const ACTIVE_CONFIG = '/etc/uconfig/configs/uconfig.active';
const TEMP_CONFIG = '/tmp/uconfig.new';
const UCONFIG_APPLY = '/usr/bin/uconfig_apply';

export function load() {
	let data = fs.readfile(ACTIVE_CONFIG);
	if (!data)
		return { error: 'Configuration file not found' };

	let config = json(data);
	if (!config)
		return { error: 'Failed to parse configuration file' };

	return config;
};

export function store(config_json) {
	if (type(config_json) != 'object')
		return { error: 'Configuration must be an object' };

	let data = sprintf('%.J\n', config_json);
	let result = fs.writefile(TEMP_CONFIG, data);
	if (!result)
		return { error: 'Failed to write configuration file' };

	return { success: true };
};

export function validate() {
	let exit_code = system(`${UCONFIG_APPLY} -t ${TEMP_CONFIG}`);
	if (exit_code != 0)
		return { success: false, error: 'Configuration validation failed', exit_code: exit_code };

	return { success: true };
};

export function apply() {
	let exit_code = system(`${UCONFIG_APPLY} ${TEMP_CONFIG}`);
	if (exit_code != 0)
		return { success: false, error: 'Configuration apply failed', exit_code: exit_code };

	return { success: true };
};

export function cleanup() {
	try {
		//fs.unlink(TEMP_CONFIG);
	} catch(e) {
	}
};

export function save(config_json) {
	if (type(config_json) != 'object')
		return { error: 'Configuration must be an object' };

	let data = sprintf('%.J\n', config_json);
	let result = fs.writefile(TEMP_CONFIG, data);
	if (!result)
		return { error: 'Failed to write configuration file' };

	let exit_code = system(`${UCONFIG_APPLY} ${TEMP_CONFIG}`);
	if (exit_code != 0)
		return { error: 'Configuration validation failed', exit_code: exit_code };

	return { success: true };
};
