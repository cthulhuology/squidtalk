
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
declare
	act boolean;
begin
	select active into act from squidtalk.users 
		where domain = _domain and email = _email;
	if found and act then
		return true;
	end;
	insert into squidtalk.users ( domain, email, name, created, active )
		values ( _domain, _email, _name, now(), true);	
	return FOUND;	
end
$$ language plpgsql;

create or replace function squidtalk.login_user( _domain text, _email text, _token text, _expires timestamp ) returns boolean as $$
begin
	update squidtalk.users set authtoken = _token, expires = _expires, lastseen = now()
		where domain = _domain and email = _email and active;
	return FOUND;
end
$$ language plpgsql;

create or replace function squidtalk.logout_user( _domain text, _email text ) returns boolean as $$
begin
	update squidtalk.users set authtoken = '', expires = now(), 
		where domain = _domain and email = _email and active;
	return FOUND;
end
$$ language plpgsql;

create or replace function squidtalk.disable_user( _domain text, _email text ) returns boolean as $$
begin
	update squidtalk.users set active = false 
		where domain = _domain and email = _email and active;
	return FOUND;
end
$$ language plpgsql;

create or replace function squidtalk.active_user( _domain text, _email text ) returns boolean as $$
declare
	retval boolean;
begin
	select active into retval from squidtalk.users
		where domain = _domain and email = _email;
	return retval;
end
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
begin
	select active from squildtalk.acls 
		where domain = _domain and bucket = _bucket;
	if found then
		return false;
	end;
	insert into squidtalk.acls ( domain, bucket, permissions, created, active)
		values ( _domain, _bucket, _permissions, now(), true);
	return found;
end
$$ language plpgsql;

create or replace function squidtalk.apply_acl( _domain text, _bucket text, _user text, _capability ) returns boolean as $$
declare
	act boolean;
begin
	-- user must be a member of the domain for an acl check
	-- no anonymous users
	select active into act from squidtalk.users 
		where domain = _domain and email = _user;
	if not found or not act then
		return false;
	end;
	-- conceptually this is what we want the behavior to be
	-- but I have no idea if this works in practice!
	select _user << permissions->(_capability) into act from squidtalk.acls
		where domain = _domain and bucket = _bucket and active;
	if not found or not act then
		return false;
	end;
	return true;
end
$$ language plpgsql;

create or replace function squidtalk.disable_acl( _domain text, bucket text, _user text ) returns boolean as $$
declare 
	act boolean;
begin
	select squidtalk.apply_acl(_domain,_domain,_user,'update') into act;
	if not act then
		return false;
	end;
	update squidtalk.acls set active = false
		where domain = _domain and bucket = _bucket;	 	
	return found;
end
$$ language plpgsql;

create or replace function squidtalk.update_acl( _domain text, _bucket text, _user text, _permissions json ) returns boolean as $$
declare
	act boolean;
begin
	select squidtalk.apply_acl( _domain, _bucket, _user, 'update') into act;
	if not act or domain = _bucket then
		return false;
	end;
	update squidtalk.acls set permissions = _permissions
		where domain = _domain and bucket = _bucket, and active;
	return found;	
end
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
begin
	select name from squidtalk.domains where name = _domain and active;
	if found then
		return false;
	end;
	insert into squidtalk.domains ( name, owner, created, active )
		values ( _domain, _user, now(), true );
	-- create the default acl where the owner can do anything
	insert into squidtalk.acls ( domain, bucket, permissions, created, active)
		values ( _domain, _domain, 
			('{ "create": ["' || _user || '"],' ||
			'"read": ["' || _user || '"],' ||
			'"update": ["' || _user || '"],' ||
			'"delete": ["' || _user || '"] }')::json ,
			now(), true );
	return found;
end
$$ language plpgsql;

create or replace function squidtalk.disable_domain( _domain text, _user text ) returns boolean as $$
declare
	act boolean;
begin
	-- only the owner of the active domain can disable it
	select active into act from squidtalk.domain 
		where name = _domain and owner = _user;
	if not found or not act then
		return false;
	end;
	update squidtalk.domains set active = false where name = _domain;
	return found;	
end
$$ language plpgsql;

create or replace function squidtalk.update_domain( _domain text, _user text, _permissions json ) returns boolean as $$
declare
	act boolean;
begin
	-- only the owner of the active domain can update the base acl
	select active into act from squidtalk.domain 
		where name = _domain and owner = _user;
	if not found or not act then
		return false;
	end;
	update squidtalk.acls set permissions = _permissions 
		where domain = _domain and bucket = _domain and active;
	return found;
end
$$ language plpgsql;

create or replace function squidtalk.delete_domain( _domain text, _user text ) returns boolean as $$
declare
	act boolean;
begin
	-- only the owner can delete the entire domain	
	select active into act from squidtalk.domains
		where name = _domain and owner = _user;
	if not found or not act then
		return false;
	end;
	-- NB: this deletes all data associated with the domain!!!!
	-- once you do this you can not recover.
	delete from squidtalk.domains where name = _domain and owner = _user;
	delete from squidtalk.acls where domain = _domain;
	delete from squidtalk.buckets where domain = _domain;
	delete from squidtalk.value where domain = _domain;
	delete from squidtalk.users where domain = _domain;
	return true;
end
$$ language plpgsql;


-- returns a list of domains owned by the given user
create or replace function squidtalk.list_domains( _user text ) returns setof text as $$
begin
	return query select name from domains where owner = _user and active;
end
$$ language plpgsql;

-- returns a list of user names for the given domain
create or replace function squidtalk.list_users( _domain text) returns setof text as $$
begin
	return query select name from squidtalk.users where domain = _domain;
end
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


