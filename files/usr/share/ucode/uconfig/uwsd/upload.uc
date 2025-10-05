'use strict';

import * as fs from 'fs';

global.upload_tokens = global.upload_tokens || {};

export function token_generate(type, max_size, expires_seconds) {
	let token = uwsd.uuid();
	let now = time();

	global.upload_tokens[token] = {
		type: type,
		max_size: max_size,
		created: now,
		expires: now + expires_seconds,
		used: false
	};

	for (let old_token, data in global.upload_tokens) {
		if (data.expires < now)
			delete global.upload_tokens[old_token];
	}

	return {
		token: token,
		upload_url: `/upload/${token}`,
		max_size: max_size,
		expires_in: expires_seconds
	};
};

export function token_validate(token) {
	let now = time();

	if (!global.upload_tokens || !global.upload_tokens[token])
		return { valid: false, error: 'Invalid or expired upload token' };

	let token_data = global.upload_tokens[token];

	if (token_data.expires < now) {
		delete global.upload_tokens[token];
		return { valid: false, error: 'Upload token has expired' };
	}

	if (token_data.used)
		return { valid: false, error: 'Upload token already used' };

	return { valid: true, data: token_data };
};

export function token_mark_used(token) {
	if (global.upload_tokens && global.upload_tokens[token])
		global.upload_tokens[token].used = true;
};

export function upload_path_get(token_type, token) {
	let timestamp = time();

	if (token_type == 'sysupgrade')
		return `/tmp/sysupgrade.${timestamp}`;
	else if (token_type == 'config-restore')
		return `/tmp/uconfig.backup.${timestamp}`;
	else
		return `/tmp/upload.${token}`;
};

export function file_delete(file_path) {
	try {
		fs.unlink(file_path);
		return true;
	} catch(e) {
		return false;
	}
};

export function request_handle(request, method, uri) {
	printf("[UPLOAD] request_handle: method=%s uri=%s\n", method, uri);
	let upload_match = match(uri, /^\/upload\/([a-f0-9-]+)$/);
	if (method != 'PUT' || !upload_match) {
		printf("[UPLOAD] request_handle: not a PUT upload request, returning false\n");
		return false;
	}

	let token = upload_match[1];
	printf("[UPLOAD] request_handle: token=%s\n", token);
	let validation = token_validate(token);

	if (!validation.valid) {
		printf("[UPLOAD] request_handle: token validation failed: %s\n", validation.error);
		return request.reply({
			'Status': '403 Forbidden',
			'Content-Type': 'text/plain'
		}, validation.error);
	}

	let token_data = validation.data;
	let filesize = request.header('Content-Length');
	printf("[UPLOAD] request_handle: Content-Length=%s\n", filesize);

	if (filesize == null) {
		printf("[UPLOAD] request_handle: missing Content-Length header\n");
		return request.reply({
			'Status': '411 Length Required',
			'Content-Type': 'text/plain'
		}, 'The request must specify a Content-Length');
	}

	if (!match(filesize, /^[0-9]+$/)) {
		printf("[UPLOAD] request_handle: invalid Content-Length format\n");
		return request.reply({
			'Status': '400 Bad Request',
			'Content-Type': 'text/plain'
		}, 'Invalid Content-Length value in request');
	}

	if (+filesize > token_data.max_size) {
		printf("[UPLOAD] request_handle: file too large: %d > %d\n", +filesize, token_data.max_size);
		return request.reply({
			'Status': '413 Payload Too Large',
			'Content-Type': 'text/plain'
		}, sprintf('File size exceeds limit of %d bytes', token_data.max_size));
	}

	token_mark_used(token);

	let file_path = upload_path_get(token_data.type, token);
	printf("[UPLOAD] request_handle: opening file for write: %s\n", file_path);
	let file_handle = fs.open(file_path, 'w');

	if (!file_handle) {
		printf("[UPLOAD] request_handle: failed to open file for writing\n");
		return request.reply({
			'Status': '500 Internal Server Error',
			'Content-Type': 'text/plain'
		}, 'Failed to create upload file');
	}

	let file_id = uwsd.uuid();
	printf("[UPLOAD] request_handle: setup complete, file_id=%s, storing to file handle\n", file_id);

	request.data({
		token: token,
		token_type: token_data.type,
		file_id: file_id,
		file_path: file_path,
		file_handle: file_handle,
		filesize: +filesize,
		upload_start: time()
	});

	request.store(file_handle);
	printf("[UPLOAD] request_handle: returning true\n");
	return true;
};

export function body_handle(request, data, file_validate_fn, validation_event_send_fn, uploaded_files) {
	let upload_match = match(request.uri(), /^\/upload\/([a-f0-9-]+)$/);
	if (request.method() != 'PUT' || !upload_match) {
		printf("[UPLOAD] body_handle: not a PUT upload request, returning false\n");
		return false;
	}

	printf("[UPLOAD] body_handle: data length=%d\n", length(data));
	if (data != '')
		return true;

	printf("[UPLOAD] body_handle: upload complete, validating\n");
	let ctx = request.data();
	let upload_duration = time() - ctx.upload_start;
	ctx.file_handle.close();
	printf("[UPLOAD] body_handle: file closed, duration=%d seconds\n", upload_duration);

	let validation = file_validate_fn(ctx.file_path, ctx.token_type);
	printf("[UPLOAD] body_handle: validation result: success=%s\n", validation.success);

	if (!validation.success) {
		printf("[UPLOAD] body_handle: validation failed: %s\n", validation.error);
		file_delete(ctx.file_path);
		validation_event_send_fn(ctx.token_type, false, null, validation.error);

		return request.reply({
			'Status': '400 Bad Request',
			'Content-Type': 'application/json'
		}, {
			status: 'validation_failed',
			error: validation.error
		});
	}

	printf("[UPLOAD] body_handle: validation success, file_id=%s\n", ctx.file_id);
	uploaded_files[ctx.file_id] = ctx.file_path;
	validation_event_send_fn(ctx.token_type, true, ctx.file_id, null);

	printf("[UPLOAD] body_handle: sending 201 Created response\n");
	return request.reply({
		'Status': '201 Created',
		'Content-Type': 'application/json'
	}, {
		token: ctx.token,
		file_id: ctx.file_id,
		file_path: ctx.file_path,
		filesize: ctx.filesize,
		upload_duration: upload_duration,
		token_type: ctx.token_type,
		status: 'upload_complete'
	});
};
