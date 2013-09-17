

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

create or replace function apply_acl( _domain text, _bucket text, _user text, _capability ) returns boolean as $$

$$ language plpgsql;

create or replace function disable_acl( _domain text, bucket text, _user text ) returns boolean as $$

$$ language plpgsql;

create or replace function update_acl( _domain text, _bucket text, _user text, _permissions json ) returns boolean as $$

$$ language plpgsql;



-- This table contains the list of domains
-- and keeps track of the admin for each domain
create table domains (
	name text,
	owner text,
	created timestamp,
	active boolean
);

create or replace function create_domain( _domain text, _user text ) returns boolean as $$

$$ language plpgsql;

create or replace function disable_domain( _domain text, _user text ) returns boolean as $$

$$ language plpgsql;

create or replace function update_domain( _domain text, _user text, _permissions json ) returns boolean as $$

$$ language plpgsql;

create or replace function delete_domain( _domain text, _user text ) returns boolean as $$

$$ language plpgsql;

create or replace function list_domains( _user text ) returns setof text as $$

$$ language plpgsql;


-- This table contains a list of buckets per domain
-- and keeps track of the admin on each domain's bucket
create table buckets (
	domain text,
	name text,
	owner text,
	created timestamp,
	active boolean	
);

create or replace function create_bucket( _domain text, _bucket text, _user text ) returns boolean as $$

$$ language plpgsql;

create or replace function disable_bucket( _domain text, _bucket text, _user text ) returns boolean as $$

$$ language plpgsql;

create or replace function delete_bucket( _domain text, _bucket text, _user text ) returns boolean as $$

$$ langusge plpgsql;


create or replace function update_bucket( _domain text, _bucket text, _user text, _permissions text ) returns boolean as $$

$$ languge plpgsql;

create or replace function list_buckets( _domain text, _user text ) returns setof text as $$

$$ language plpgsql;

-- This table contains the key/value pairs for each bucket
-- values are stored in time order, and marked active false
-- when they are superceeded
create table value (
	domain text,
	bucket text,
	name text,
	value json,
	created timestamp,
	active boolean
);

create or replace function create_value( _domain text, _bucket text, _user text, _name text, _value json ) returns boolean as $$

$$ language plgpsql;

create or replace function update_value( _domain text, _bucket text, _user text, _name text, _value json ) returns boolean as $$

$$ languge plpgsql;

create or replace function disable_value(_domain text, _bucket text, _user text, _name text) ) returns boolean as $$ 

create or replace function delete_value( _domain text, _bucket text, _user text, _name text ) returns boolean as $$

$$ language plpgsql;

create or replace function list_value( _domain text, _bucket text, _user text, _name text ) returns setof json as $$

$$ language plpgsql;


