'use strict';

import {
	ERROR_INVALID_PARAMS,
	ERROR_INTERNAL,
	response_success,
	response_error
} from 'jsonrpc';

import * as ubus from 'ubus';

function devices_list() {
	let devices = ubus.call('uconfig-ui', 'devices');
	if (!devices)
		return { error: 'Failed to retrieve device information' };
	return devices;
}

function device_set_name(mac, name) {
	if (!mac)
		return { error: 'Missing MAC address' };

	let result = ubus.call('uconfig-ui', 'device_set_name', { mac, name });
	if (!result)
		return { error: 'Failed to set device name' };

	if (result.error)
		return { error: result.error };

	return result;
}

function device_set_ignore(mac, ignore) {
	if (!mac)
		return { error: 'Missing MAC address' };

	let result = ubus.call('uconfig-ui', 'device_set_ignore', { mac, ignore });
	if (!result)
		return { error: 'Failed to set ignore flag' };

	if (result.error)
		return { error: result.error };

	return result;
}

function device_delete(mac) {
	if (!mac)
		return { error: 'Missing MAC address' };

	let result = ubus.call('uconfig-ui', 'device_delete', { mac });
	if (!result)
		return { error: 'Failed to delete device' };

	if (result.error)
		return { error: result.error };

	return result;
}

export function handle(send_response, id, params) {
	if (type(params) != 'object' || !params.action)
		return send_response(response_error(id, ERROR_INVALID_PARAMS, 'Invalid params'));

	let result;

	if (params.action == 'list')
		result = devices_list();
	else if (params.action == 'set-name')
		result = device_set_name(params.mac, params.name);
	else if (params.action == 'ignore')
		result = device_set_ignore(params.mac, params.ignore);
	else if (params.action == 'delete')
		result = device_delete(params.mac);
	else
		return send_response(response_error(id, ERROR_INVALID_PARAMS, 'Invalid action'));

	if (result.error)
		return send_response(response_error(id, ERROR_INTERNAL, result.error));

	send_response(response_success(id, result));
};
