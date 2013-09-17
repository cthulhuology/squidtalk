

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
	active boolean
);

create or replace function create_user( _domain text, _email text, _name text ) returns boolean
as $$
	
$$ language plpgsql;

create or replace function login_user( _domain text, _email text, _token text, _expires timestamp ) returns boolean as $$

$$ language plpgsql;

create or replace function logout_user( _domain text, _email text ) returns boolean as $$

$$ language plpgsql;

create or replace function disable_user( _domain text, _email text ) returns boolean as $$

$$ language plpgsql;

create or replace function active_user( _domain text, _email text ) returns boolean as $$

$$ language plpgsql;

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

create or replace function create_acl( _domain text, _bucket text, _permissions json ) returns boolean as $$

$$ language plpgsql;

create or replace function 

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
-- values are stored in time order, and marked active false
-- when they are superceeded
create table keyvalues (
	domain text,
	bucket text,
	name text,
	value json,
	created timestamp,
	active boolean
);



