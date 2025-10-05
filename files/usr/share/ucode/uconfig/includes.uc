'use strict';

import * as fs from 'fs';

let include_sources = {};

function source_path_resolve(source) {
	let parts = split(source, ':');
	if (length(parts) != 2)
		return null;

	let prefix = parts[0];
	let name = parts[1];

	if (prefix == 'ucoord')
		return `/etc/ucoord/configs/${name}.json`;
	if (prefix == 'local')
		return `/etc/uconfig/${name}.json`;

	return null;
}

function source_load(name, source, logs) {
	let path = source_path_resolve(source);
	if (!path) {
		if (logs)
			push(logs, `Include source '${name}' has invalid source format: ${source}`);
		return null;
	}

	let content = fs.readfile(path);
	if (!content) {
		if (logs)
			push(logs, `Include source '${name}' not found: ${path}`);
		return null;
	}

	let data = json(content);
	if (!data) {
		if (logs)
			push(logs, `Include source '${name}' invalid JSON: ${path}`);
		return null;
	}

	if (!data.uuid) {
		if (logs)
			push(logs, `Include source '${name}' missing required uuid property`);
		return null;
	}

	return data;
}

function path_resolve(data, path) {
	let parts = split(path, '.');
	let current = data;

	for (let part in parts) {
		if (type(current) != 'object')
			return null;
		current = current[part];
	}

	return current;
}

function deep_merge(target, source) {
	if (type(source) != 'object')
		return source;
	if (type(target) != 'object')
		target = {};

	for (let key, value in source) {
		if (type(value) == 'object' && type(target[key]) == 'object')
			target[key] = deep_merge(target[key], value);
		else
			target[key] = value;
	}

	return target;
}

function object_process(obj) {
	if (type(obj) != 'object')
		return obj;

	let includes = obj.include;
	if (type(includes) == 'array') {
		delete obj.include;

		for (let include_path in includes) {
			let parts = split(include_path, '.', 2);
			let source_name = parts[0];
			let data_path = parts[1];

			let source_data = include_sources[source_name];
			if (!source_data)
				continue;

			let snippet = data_path ? path_resolve(source_data, data_path) : source_data;
			if (snippet)
				obj = deep_merge(obj, snippet);
		}
	}

	for (let key, value in obj) {
		if (type(value) == 'object')
			obj[key] = object_process(value);
	}

	return obj;
}

export function process(config, logs) {
	include_sources = {};
	let includes_map = config.includes;
	let failed = false;

	if (type(includes_map) == 'object') {
		for (let name, source in includes_map) {
			let data = source_load(name, source, logs);
			if (data)
				include_sources[name] = data;
			else
				failed = true;
		}
		delete config.includes;
	}

	if (failed)
		return null;

	return object_process(config);
};
