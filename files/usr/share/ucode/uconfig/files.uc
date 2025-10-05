/**
 * @class uconfig.files
 * @classdesc
 *
 * The files utility class manages non-uci file attachments which are
 * produced during schema rendering.
 */

/** @lends uconfig.files.prototype */

'use strict';

import * as fs from 'fs';

export let files = {};

/**
 * The base directory for file attachments.
 *
 * @readonly
 */
let basedir = '/tmp/uconfig';

/**
 * Escape the given string.
 *
 * Escape any slash and tilde characters in the given string to allow
 * using it as part of a JSON pointer expression.
 *
 * @param {string} s  The string to escape
 * @returns {string}  The escaped string
 */
function escape(s) {
	return replace(s, /[~\/]/g, m => (m == '~' ? '~0' : '~1'));
}

/**
 * Add a named file attachment.
 *
 * Stores the given content in a file at the given path. Expands the
 * path relative to the `basedir` if it is not absolute.
 *
 * @param {string} path  The file path
 * @param {*} content    The content to store
 */
export function add_named(path, content) {
	if (index(path, '/') != 0)
		path = basedir + '/' + path;

	files[path] = content;
};

/**
 * Add an anonymous file attachment.
 *
 * Stores the given content in a file with a random name derived from
 * the given location pointer and name hint.
 *
 * @param {string} location  The current location within the state we're traversing
 * @param {string} name      The name hint
 * @param {*} content        The content to store
 *
 * @returns {string}
 * Returns the generated random file path.
 */
export function add_anonymous(location, name, content) {
	let path = basedir + '/' + escape(location) + '/' + escape(name);

	files[path] = content;

	return path;
};

/**
 * Recursively create the parent directories of the given path.
 *
 * Recursively creates the parent directory structure of the given
 * path and places any error messages in the given logs array.
 *
 * @param {array} logs   The array to store log messages into
 * @param {string} path  The path to create directories for
 * @return {boolean}
 * Returns `true` if the parent directories were successfully created
 * or did already exist, returns `false` in case an error occurred.
 */
function mkdir_path(logs, path) {
	assert(index(path, '/') == 0, "Expecting absolute path");

	let segments = split(path, '/'),
	    tmppath = shift(segments);

	for (let i = 0; i < length(segments) - 1; i++) {
		tmppath += '/' + segments[i];

		let s = fs.stat(tmppath);

		if (s != null && s.type == 'directory')
			continue;

		if (fs.mkdir(tmppath))
			continue;

		push(logs, sprintf("[E] Unable to mkdir() path '%s': %s", tmppath, fs.error()));

		return false;
	}

	return true;
}

/**
 * Write the staged file attachement contents to the filesystem.
 *
 * Writes the staged attachment contents that were gathered during state
 * rendering to the file system and places any encountered errors into
 * the logs array.
 *
 * @param {array} logs  The array to store error messages into
 * @return {boolean}
 * Returns `true` if all attachments were written succefully, returns
 * `false` if one or more attachments could not be written.
 */
export function generate(logs) {
	let success = true;

	for (let path, content in files) {
		if (!mkdir_path(logs, path)) {
			success = false;
			continue;
		}

		let f = fs.open(path, "w");

		if (f) {
			f.write(content);
			f.close();
		}
		else {
			push(logs, sprintf("[E] Unable to open() path '%s' for writing: %s", path, fs.error()));
			success = false;
		}
	}

	return success;
};

export function readjson(path) {
	let raw = fs.readfile(path);
	if (!raw)
		return {};
	return json(raw) || {};
};

export function read(path) {
	try {
		let file = fs.open(path, 'r');
		let dict = json(file.read('all'));
		file.close();
		return dict;
	} catch(e) {
		die(`ERROR: failed to load ${path}\n`);
	}
};

export function write(path, data) {
	let file = fs.open(path, 'w');
	if (!file)
		die(`ERROR: failed to open ${path} for writing\n`);
	file.write(data);
	file.close();
};

export function popen(cmd, data) {
	let apply = fs.popen(cmd, 'w');
	if (!apply)
		die(`ERROR: failed to popen ${cmd}\n`);
	apply.write(data);
	apply.close();
};

export function init() {
	files = {};
};
