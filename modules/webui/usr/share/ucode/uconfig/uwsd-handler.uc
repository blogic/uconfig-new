'use strict';

import {
	ERROR_METHOD_NOT_FOUND,
	ERROR_INVALID_PARAMS,
	ERROR_INTERNAL,
	ERROR_LOGIN_REQUIRED,
	ERROR_INVALID_PASSWORD,
	parse_request,
	response_success,
	response_error
} from 'uwsd.jsonrpc';

import { login, change_password } from 'uwsd.auth';
import * as config from 'uwsd.config';
import { request_handle as upload_request_handle, body_handle as upload_body_handle } from 'uwsd.upload';
import { token_generate_for_type, file_validate, file_apply, validation_event_send } from 'uwsd.system';
import * as status from 'uwsd.status';
import * as wizard from 'uwsd.wizard';
import * as tailscale from 'uwsd.tailscale';
import * as devices from 'uwsd.devices';
import * as storage from 'uwsd.storage';
import * as uloop from 'uloop';
import * as ubus from 'ubus';

global.connections = {};
global.shutdown = false;
global.uploaded_files = {};
global.wizard_mode = !wizard.is_configured();

function send_response(connection, response) {
	let data = sprintf('%.J', response);
	connection.send(data);
}

function send_event(connection, event_name, params) {
	let event = {
		jsonrpc: '2.0',
		method: event_name
	};
	if (params)
		event.params = params;
	let data = sprintf('%.J', event);
	connection.send(data);
}

function broadcast_event(event_name, params) {
	for (let name, conn in global.connections)
		send_event(conn, event_name, params);
}

function shutdown_handler(connection, id, event_name, callback) {
	send_response(connection, response_success(id, { success: true }));

	global.shutdown = true;

	for (let name, conn in global.connections) {
		send_event(conn, event_name);
		conn.close(1000, 'Server shutting down');
	}

	uloop.timer(2000, callback);
}

function handle_ping(connection, id, params) {
	send_response(connection, response_success(id, { success: true }));
}

function handle_login(connection, id, params) {
	if (type(params) != 'object' || !params.password)
		return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid params'));

	let result = login(params.password);
	if (!result)
		return send_response(connection, response_error(id, ERROR_INVALID_PASSWORD, 'Invalid password'));

	connection.data().authenticated = true;
	send_response(connection, response_success(id, result));
}

function handle_logout(connection, id, params) {
	connection.data().authenticated = false;
	send_response(connection, response_success(id, { success: true }));
}

function handle_config_load(connection, id, params) {
	let result = config.load();
	if (result.error)
		return send_response(connection, response_error(id, ERROR_INTERNAL, result.error));

	send_response(connection, response_success(id, result));
}

function handle_config_save(connection, id, params) {
	if (type(params) != 'object' || !params.config)
		return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid params'));

	let store_result = config.store(params.config);
	if (store_result.error) {
		config.cleanup();
		return send_response(connection, response_error(id, ERROR_INTERNAL, store_result.error));
	}

	let validate_result = config.validate();
	if (!validate_result.success) {
		broadcast_event('config-apply-failed', { error: validate_result.error, exit_code: validate_result.exit_code });
		config.cleanup();
		return send_response(connection, response_error(id, ERROR_INTERNAL, validate_result.error, { exit_code: validate_result.exit_code }));
	}

	broadcast_event('config-apply-start');

	let apply_result = config.apply();
	config.cleanup();

	if (!apply_result.success) {
		broadcast_event('config-apply-failed', { error: apply_result.error, exit_code: apply_result.exit_code });
		return send_response(connection, response_error(id, ERROR_INTERNAL, apply_result.error, { exit_code: apply_result.exit_code }));
	}

	broadcast_event('config-apply-success');
	send_response(connection, response_success(id, { success: true }));
}

function handle_change_password(connection, id, params) {
	if (type(params) != 'object' || !params.password)
		return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid params'));

	let result = change_password(params.password);
	if (result.error)
		return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid params', { reason: result.error }));

	send_response(connection, response_success(id, result));
}

function handle_system_info(connection, id, params) {
	let info = ubus.call('system', 'info');
	let board = ubus.call('system', 'board');

	if (!info || !board)
		return send_response(connection, response_error(id, ERROR_INTERNAL, 'Failed to retrieve system information'));

	let result = {
		uptime: info.uptime,
		localtime: info.localtime,
		load: info.load,
		memory: info.memory,
		root: info.root,
		tmp: info.tmp,
		swap: info.swap,
		kernel: board.kernel,
		hostname: board.hostname,
		system: board.system,
		model: board.model,
		board_name: board.board_name,
		rootfs_type: board.rootfs_type,
		release: board.release
	};

	send_response(connection, response_success(id, result));
}

function handle_reboot(connection, id, params) {
	shutdown_handler(connection, id, 'rebooting', () => {
		system('reboot');
	});
}

function handle_factory_reset(connection, id, params) {
	shutdown_handler(connection, id, 'factory-reset', () => {
		system('factoryreset -y -r');
	});
}

function handle_sysupgrade(connection, id, params) {
	if (type(params) != 'object' || !params.action)
		return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid params'));

	if (params.action == 'token') {
		let result = token_generate_for_type('sysupgrade');
		return send_response(connection, response_success(id, result));
	}

	if (params.action == 'apply') {
		if (!params.file_id || !global.uploaded_files[params.file_id])
			return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid or missing file_id'));

		let file_path = global.uploaded_files[params.file_id];
		file_apply(file_path, 'sysupgrade', { keep_config: params.keep_config }, (event_name, callback) => {
			shutdown_handler(connection, id, event_name, callback);
		});
		return;
	}

	return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid action'));
}

function handle_config_restore(connection, id, params) {
	if (type(params) != 'object' || !params.action)
		return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid params'));

	if (params.action == 'token') {
		let result = token_generate_for_type('config-restore');
		return send_response(connection, response_success(id, result));
	}

	if (params.action == 'apply') {
		if (!params.file_id || !global.uploaded_files[params.file_id])
			return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid or missing file_id'));

		let file_path = global.uploaded_files[params.file_id];
		file_apply(file_path, 'config-restore', {}, (event_name, callback) => {
			shutdown_handler(connection, id, event_name, callback);
		});
		return;
	}

	return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid action'));
}

function handle_devices(connection, id, params) {
	devices.handle((response) => send_response(connection, response), id, params);
}

function handle_radios(connection, id, params) {
	let radios = ubus.call('uconfig-ui', 'radios');

	if (!radios)
		return send_response(connection, response_error(id, ERROR_INTERNAL, 'Failed to retrieve radio information'));

	send_response(connection, response_success(id, radios));
}

function handle_traffic(connection, id, params) {
	let traffic = ubus.call('uconfig-ui', 'traffic');

	if (!traffic)
		return send_response(connection, response_error(id, ERROR_INTERNAL, 'Failed to retrieve traffic information'));

	send_response(connection, response_success(id, traffic));
}

function handle_status(connection, id, params) {
	let result = status.get();

	if (!result)
		return send_response(connection, response_error(id, ERROR_INTERNAL, 'Failed to retrieve status information'));

	send_response(connection, response_success(id, result));
}

function handle_setup_wizard(connection, id, params) {
	if (type(params) != 'object')
		return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid params'));

	let result = wizard.wizard_apply_wrapper(params);
	if (result.error)
		return send_response(connection, response_error(id, ERROR_INTERNAL, result.error, result.exit_code ? { exit_code: result.exit_code } : {}));

	global.wizard_mode = false;
	send_response(connection, response_success(id, { success: true }));

	uloop.timer(200, () => {
		send_event(connection, 'login-required');
	});
}

function handle_tailscale(connection, id, params) {
	tailscale.handle((response) => send_response(connection, response), id, params);
}

function handle_storage(connection, id, params) {
	storage.handle((response) => send_response(connection, response), id, params);
}

let handlers = {
	'ping': { handler: handle_ping, auth_required: true },
	'login': { handler: handle_login, auth_required: false },
	'setup-wizard': { handler: handle_setup_wizard, auth_required: false },
	'logout': { handler: handle_logout, auth_required: true },
	'config-load': { handler: handle_config_load, auth_required: true },
	'config-save': { handler: handle_config_save, auth_required: true },
	'change-password': { handler: handle_change_password, auth_required: true },
	'system-info': { handler: handle_system_info, auth_required: true },
	'devices': { handler: handle_devices, auth_required: true },
	'radios': { handler: handle_radios, auth_required: true },
	'traffic': { handler: handle_traffic, auth_required: true },
	'status': { handler: handle_status, auth_required: true },
	'tailscale': { handler: handle_tailscale, auth_required: true },
	'storage': { handler: handle_storage, auth_required: true },
	'reboot': { handler: handle_reboot, auth_required: true },
	'factory-reset': { handler: handle_factory_reset, auth_required: true },
	'sysupgrade': { handler: handle_sysupgrade, auth_required: true },
	'config-restore': { handler: handle_config_restore, auth_required: true }
};

function route_method(connection, request) {
	let method = handlers[request.method];
	if (!method)
		return send_response(connection, response_error(request.id, ERROR_METHOD_NOT_FOUND, 'Method not found'));

	if (global.wizard_mode && request.method != 'setup-wizard')
		return send_response(connection, response_error(request.id, ERROR_INTERNAL, 'Setup wizard must be completed first'));

	if (method.auth_required && !connection.data().authenticated)
		return send_response(connection, response_error(request.id, ERROR_LOGIN_REQUIRED, 'login-required'));

	method.handler(connection, request.id, request.params);
}

function connection_name(connection) {
	let info = connection.info();
	return `${info.peer_address}:${info.peer_port}`;
}

export function onConnect(connection, protocols) {
	if (global.shutdown)
		return connection.close(1001, 'Server shutting down');

	if (!('ui' in protocols))
		return connection.close(1003, 'Unsupported protocol requested');

	let ctx = {
		authenticated: false,
		msg: ''
	};
	connection.data(ctx);

	let name = connection_name(connection);
	global.connections[name] = connection;

	uloop.timer(200, () => {
		if (global.wizard_mode)
			send_event(connection, 'setup-required');
		else
			send_event(connection, 'login-required');
	});

	return connection.accept('ui');
};

export function onClose(connection, code, reason) {
	let name = connection_name(connection);
	delete global.connections[name];
};

export function onData(connection, data, final) {
	let ctx = connection.data();
	if (!ctx)
		return connection.close(1009, 'Message too big');

	if (length(ctx.msg) + length(data) > 32 * 1024)
		return connection.close(1009, 'Message too big');

	ctx.msg = ctx.msg + data;
	if (!final)
		return;

	let request = parse_request(ctx.msg);
	ctx.msg = '';

	if (request.error)
		return send_response(connection, response_error(request.id, request.error, request.message));

	route_method(connection, request);
};

export function onRequest(request, method, uri) {
	printf("[HANDLER] onRequest: method=%s uri=%s\n", method, uri);
	let upload_result = upload_request_handle(request, method, uri);
	printf("[HANDLER] onRequest: upload_result=%s\n", upload_result);
	if (upload_result)
		return upload_result;

	printf("[HANDLER] onRequest: returning 404\n");
	return request.reply({
		'Status': '404 Not Found',
		'Content-Type': 'text/plain'
	}, 'Not Found');
};

export function onBody(request, data) {
	printf("[HANDLER] onBody: data length=%d\n", length(data));
	let validation_event_send_wrapper = (type, success, file_id, error) => {
		validation_event_send(global.connections, type, success, file_id, error);
	};

	let body_result = upload_body_handle(request, data, file_validate, validation_event_send_wrapper, global.uploaded_files);
	printf("[HANDLER] onBody: body_result=%s\n", body_result);
	return body_result;
};
