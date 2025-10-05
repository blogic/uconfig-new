'use strict';

import * as libuci from 'uci';
export let uci = libuci ? libuci.cursor() : null;

if (!uci)
	die('ERROR: failed to load UCI cursor');
