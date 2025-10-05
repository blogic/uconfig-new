'use strict';

import {
	ERROR_INVALID_PARAMS,
	ERROR_INTERNAL,
	response_success,
	response_error
} from 'uconfig.uwsd.jsonrpc';

import { ubus } from 'uconfig.libubus';

let global_connections = null;
let pending_notifications = {};
let notification_id_counter = 0;

function notify_cb(req) {
	if (!req.data)
		return req.reply({});

	let notification_id = notification_id_counter++;
	pending_notifications[notification_id] = req;

	if (global_connections) {
		for (let name, conn in global_connections) {
			let event = {
				jsonrpc: '2.0',
				method: 'usnitch-blocked'
			};
			event.params = {
				...req.data,
				notification_id
			};
			let data = sprintf('%.J', event);
			conn.send(data);
		}
	}
}

function remove_cb(object_id) {
}

let subscriber = ubus.subscriber(notify_cb, remove_cb);
subscriber.subscribe('usnitch');

function list() {
	let result = {
		rules: [],
		devices: {},
		global_rules: [],
		device_port_rules: []
	};

	let rules = ubus.call('usnitch', 'rule_list', {});
	if (rules && rules.rules)
		result.rules = rules.rules;

	let devices = ubus.call('usnitch', 'device_list', {});
	if (devices && devices.devices)
		result.devices = devices.devices;

	let global_rules = ubus.call('usnitch', 'global_rule_list', {});
	if (global_rules && global_rules.rules)
		result.global_rules = global_rules.rules;

	let device_port_rules = ubus.call('usnitch', 'device_port_rule_list', {});
	if (device_port_rules && device_port_rules.rules)
		result.device_port_rules = device_port_rules.rules;

	return result;
}

function device_add(mac, allow) {
	if (!mac)
		return { error: 'Missing MAC address' };

	let result = ubus.call('usnitch', 'device_add', { mac, allow });
	if (!result)
		return { error: 'Failed to add device' };

	if (result.error)
		return { error: result.error };

	return result;
}

function device_delete(mac) {
	if (!mac)
		return { error: 'Missing MAC address' };

	let result = ubus.call('usnitch', 'device_delete', { mac });
	if (!result)
		return { error: 'Failed to delete device' };

	if (result.error)
		return { error: result.error };

	return result;
}

function rule_add(mac, ip, fqdn, port, proto, allow, expires) {
	if (!mac)
		return { error: 'Missing MAC address' };
	if (!ip && !fqdn)
		return { error: 'Must specify either ip or fqdn' };
	if (!port)
		return { error: 'Missing port' };
	if (!proto)
		return { error: 'Missing protocol' };

	let params = { mac, port, proto, allow };
	if (ip)
		params.ip = ip;
	if (fqdn)
		params.fqdn = fqdn;
	if (expires != null)
		params.expires = expires;

	let result = ubus.call('usnitch', 'rule_add', params);
	if (!result)
		return { error: 'Failed to add rule' };

	if (result.error)
		return { error: result.error };

	return result;
}

function rule_delete(mac, ip, port, proto) {
	if (!mac)
		return { error: 'Missing MAC address' };
	if (!ip)
		return { error: 'Missing IP address' };
	if (!port)
		return { error: 'Missing port' };
	if (!proto)
		return { error: 'Missing protocol' };

	let result = ubus.call('usnitch', 'rule_delete', { mac, ip, port, proto });
	if (!result)
		return { error: 'Failed to delete rule' };

	if (result.error)
		return { error: result.error };

	return result;
}

function global_rule_add(port, proto, allow) {
	if (!port)
		return { error: 'Missing port' };
	if (!proto)
		return { error: 'Missing protocol' };

	let result = ubus.call('usnitch', 'global_rule_add', { port, proto, allow });
	if (!result)
		return { error: 'Failed to add global rule' };

	if (result.error)
		return { error: result.error };

	return result;
}

function global_rule_delete(port, proto) {
	if (!port)
		return { error: 'Missing port' };
	if (!proto)
		return { error: 'Missing protocol' };

	let result = ubus.call('usnitch', 'global_rule_delete', { port, proto });
	if (!result)
		return { error: 'Failed to delete global rule' };

	if (result.error)
		return { error: result.error };

	return result;
}

function device_port_rule_add(mac, port, proto, allow) {
	if (!mac)
		return { error: 'Missing MAC address' };
	if (!port)
		return { error: 'Missing port' };
	if (!proto)
		return { error: 'Missing protocol' };

	let result = ubus.call('usnitch', 'device_port_rule_add', { mac, port, proto, allow });
	if (!result)
		return { error: 'Failed to add device port rule' };

	if (result.error)
		return { error: result.error };

	return result;
}

function device_port_rule_delete(mac, port, proto) {
	if (!mac)
		return { error: 'Missing MAC address' };
	if (!port)
		return { error: 'Missing port' };
	if (!proto)
		return { error: 'Missing protocol' };

	let result = ubus.call('usnitch', 'device_port_rule_delete', { mac, port, proto });
	if (!result)
		return { error: 'Failed to delete device port rule' };

	if (result.error)
		return { error: result.error };

	return result;
}

function respond(notification_id, action, timeout) {
	if (notification_id == null)
		return { error: 'Missing notification_id' };
	if (!action)
		return { error: 'Missing action' };

	let req = pending_notifications[notification_id];
	if (!req)
		return { error: 'Notification not found or already responded' };

	let response = { action };
	if (timeout != null)
		response.timeout = timeout;

	req.reply(response);
	delete pending_notifications[notification_id];

	return { success: true };
}

export function connections_set(conns) {
	global_connections = conns;
};

export function handle(send_response, id, params) {
	if (type(params) != 'object' || !params.action)
		return send_response(response_error(id, ERROR_INVALID_PARAMS, 'Invalid params'));

	let result;

	if (params.action == 'list')
		result = list();
	else if (params.action == 'device_add')
		result = device_add(params.mac, params.allow);
	else if (params.action == 'device_delete')
		result = device_delete(params.mac);
	else if (params.action == 'rule_add')
		result = rule_add(params.mac, params.ip, params.fqdn, params.port, params.proto, params.allow, params.expires);
	else if (params.action == 'rule_delete')
		result = rule_delete(params.mac, params.ip, params.port, params.proto);
	else if (params.action == 'global_rule_add')
		result = global_rule_add(params.port, params.proto, params.allow);
	else if (params.action == 'global_rule_delete')
		result = global_rule_delete(params.port, params.proto);
	else if (params.action == 'device_port_rule_add')
		result = device_port_rule_add(params.mac, params.port, params.proto, params.allow);
	else if (params.action == 'device_port_rule_delete')
		result = device_port_rule_delete(params.mac, params.port, params.proto);
	else if (params.action == 'respond')
		result = respond(params.notification_id, params.action_type, params.timeout);
	else
		return send_response(response_error(id, ERROR_INVALID_PARAMS, 'Invalid action'));

	if (result.error)
		return send_response(response_error(id, ERROR_INTERNAL, result.error));

	send_response(response_success(id, result));
};
