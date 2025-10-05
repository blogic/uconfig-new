'use strict';

import * as libubus from 'ubus';
export let ubus = libubus ? libubus.connect() : null;

if (!ubus)
	die('ERROR: failed to load UBUS context');
