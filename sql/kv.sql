

-- This table maps user accounts to the individual domains
-- It also serves as the list of names for the acls
create table users (
	domain text,
	email text,
	name text,
	created timestamp,
	lastseen timestamp,
	authtoken text,
	expires timestamp,
	active boolean,
);

-- This table contains the access control lists for each
-- of the domains.  Permissions is a loosely structured
-- json object of the form:
--
--	{ "permission" : [ "email@address" ], }
--
create table acls (
	domain text,
	bucket text,
	permissions json,
	created timestamp,
	active boolean	
);

-- This table contains the list of domains
-- and keeps track of the admin for each domain
create table domains (
	name text,
	owner text,
	created timestamp,
	active boolean
);

-- This table contains a list of buckets per domain
-- and keeps track of the admin on each domain's bucket
create table buckets (
	domain text,
	name text,
	owner text,
	created timestamp,
	active boolean	
);

-- This table contains the key/value pairs for each bucket
create table keyvalues (
	domain text,
	bucket text,
	name text,
	value json,
	created timestamp,
	active boolean
);
