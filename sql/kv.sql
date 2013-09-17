

-- This table squidtalk.maps user accounts to the individual domains
-- It also serves as the list of names for the acls
create table squidtalk.users (
	domain text,
	email text,
	name text,
	created timestamp,
	lastseen timestamp,
	authtoken text,
	expires timestamp,
	active boolean
);

create or replace function squidtalk.create_user( _domain text, _email text, _name text ) returns boolean
as $$
	
$$ language plpgsql;

create or replace function squidtalk.login_user( _domain text, _email text, _token text, _expires timestamp ) returns boolean as $$

$$ language plpgsql;

create or replace function squidtalk.logout_user( _domain text, _email text ) returns boolean as $$

$$ language plpgsql;

create or replace function squidtalk.disable_user( _domain text, _email text ) returns boolean as $$

$$ language plpgsql;

create or replace function squidtalk.active_user( _domain text, _email text ) returns boolean as $$

$$ language plpgsql;

-- This table squidtalk.contains the access control lists for each
-- of the domains.  Permissions is a loosely structured
-- json object of the form:
--
--	{ "permission" : [ "email@address" ], }
--
create table squidtalk.acls (
	domain text,
	bucket text,
	permissions json,
	created timestamp,
	active boolean	
);

create or replace function squidtalk.create_acl( _domain text, _bucket text, _permissions json ) returns boolean as $$

$$ language plpgsql;

create or replace function squidtalk.apply_acl( _domain text, _bucket text, _user text, _capability ) returns boolean as $$

$$ language plpgsql;

create or replace function squidtalk.disable_acl( _domain text, bucket text, _user text ) returns boolean as $$

$$ language plpgsql;

create or replace function squidtalk.update_acl( _domain text, _bucket text, _user text, _permissions json ) returns boolean as $$

$$ language plpgsql;



-- This table squidtalk.contains the list of domains
-- and keeps track of the admin for each domain
create table squidtalk.domains (
	name text,
	owner text,
	created timestamp,
	active boolean
);

create or replace function squidtalk.create_domain( _domain text, _user text ) returns boolean as $$

$$ language plpgsql;

create or replace function squidtalk.disable_domain( _domain text, _user text ) returns boolean as $$

$$ language plpgsql;

create or replace function squidtalk.update_domain( _domain text, _user text, _permissions json ) returns boolean as $$

$$ language plpgsql;

create or replace function squidtalk.delete_domain( _domain text, _user text ) returns boolean as $$

$$ language plpgsql;

create or replace function squidtalk.list_domains( _user text ) returns setof text as $$

$$ language plpgsql;


-- This table squidtalk.contains a list of buckets per domain
-- and keeps track of the admin on each domain's bucket
create table squidtalk.buckets (
	domain text,
	name text,
	owner text,
	created timestamp,
	active boolean	
);

create or replace function squidtalk.create_bucket( _domain text, _bucket text, _user text ) returns boolean as $$

$$ language plpgsql;

create or replace function squidtalk.disable_bucket( _domain text, _bucket text, _user text ) returns boolean as $$

$$ language plpgsql;

create or replace function squidtalk.delete_bucket( _domain text, _bucket text, _user text ) returns boolean as $$

$$ langusge plpgsql;


create or replace function squidtalk.update_bucket( _domain text, _bucket text, _user text, _permissions text ) returns boolean as $$

$$ languge plpgsql;

create or replace function squidtalk.list_buckets( _domain text, _user text ) returns setof text as $$

$$ language plpgsql;

-- This table squidtalk.contains the key/value pairs for each bucket
-- values are stored in time order, and marked active false
-- when they are superceeded
create table squidtalk.value (
	domain text,
	bucket text,
	name text,
	value json,
	created timestamp,
	active boolean
);

create or replace function squidtalk.create_value( _domain text, _bucket text, _user text, _name text, _value json ) returns boolean as $$

$$ language plgpsql;

create or replace function squidtalk.update_value( _domain text, _bucket text, _user text, _name text, _value json ) returns boolean as $$

$$ languge plpgsql;

create or replace function squidtalk.disable_value(_domain text, _bucket text, _user text, _name text) ) returns boolean as $$ 

create or replace function squidtalk.delete_value( _domain text, _bucket text, _user text, _name text ) returns boolean as $$

$$ language plpgsql;

create or replace function squidtalk.list_value( _domain text, _bucket text, _user text, _name text ) returns setof json as $$

$$ language plpgsql;


