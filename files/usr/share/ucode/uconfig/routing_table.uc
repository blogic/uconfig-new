/**
 * @class uconfig.routing_table
 * @classdesc
 *
 * The routing table utility class allows querying system routing tables.
 * Allocates routing table IDs from 1000-65535 to avoid conflicts with
 * system tables (0-255). The allocation is sequential and does not reuse
 * freed table IDs within a single configuration generation.
 */

/** @lends uconfig.routing_table.prototype */

'use strict';

const MIN_TABLE_ID = 1000;  // Start above standard system tables (0-255)
const MAX_TABLE_ID = 65535; // Conservative limit for policy routing

let used_tables = {};
let next = MIN_TABLE_ID;

/**
 * Allocate a route table index for the given ID
 *
 * @param {string} id  The ID to lookup or reserve
 * @returns {number} The table number allocated for the given ID
 * @throws {Error} If routing table allocation limit is exceeded
 */
export function get(id) {
	if (!used_tables[id]) {
		if (next > MAX_TABLE_ID)
			die(`Routing table allocation limit exceeded (max ${MAX_TABLE_ID})`);
		used_tables[id] = next++;
	}
	return used_tables[id];
};

export function init() {
	used_tables = {};
	next = MIN_TABLE_ID;
};
