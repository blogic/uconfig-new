'use strict';

/* open the capab file */
let file = fs.open("/etc/uconfig/capabilities.json", "r");

/* export the content */
export let capabilities = file ? json(file.read("all")) : null;
file.close();

/* TODO: add capabilities reader */

/* die if capabilities failed to validate */
if (!capabilities)
	die("ERROR: Unable to load capabilities");
