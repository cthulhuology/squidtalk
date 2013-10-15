
drop schema if exists squidtalk cascade;
create schema squidtalk;
-- This table squidtalk.maps user accounts to the individual domains
-- It also serves as the list of names for the acls
drop table if exists squidtalk.users;
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
	end if;
	insert into squidtalk.users ( domain, email, name, created, active ) 
		values ( _domain, _email, _name, now(), true);	
	return found;	
end
$$ language plpgsql;

create or replace function squidtalk.login_user( _domain text, _email text, _token text, _expires timestamp ) returns boolean as $$
begin
	update squidtalk.users set authtoken = _token, expires = _expires, lastseen = now()
		where domain = _domain and email = _email and active;
	return found;
end
$$ language plpgsql;

create or replace function squidtalk.logout_user( _domain text, _email text ) returns boolean as $$
begin
	update squidtalk.users set authtoken = '', expires = now()
		where domain = _domain and email = _email and active;
	return found;
end
$$ language plpgsql;

-- disables the user for the given domain.  if the user is the owner of the domain
-- the entire domain and all if its buckets and data are also disabled for safey
create or replace function squidtalk.disable_user( _domain text, _email text ) returns boolean as $$
begin
	update squidtalk.users set active = false 
		where domain = _domain and email = _email and active;
	select active from squidtalk.domains 
		where name = _domain and owner = _email and active;
	if found then
		select squidtalk.disable_domain(_domain,_email);
	end if;
	return found;
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
drop table if exists squidtalk.acls;
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
	end if;
	insert into squidtalk.acls ( domain, bucket, permissions, created, active)
		values ( _domain, _bucket, _permissions, now(), true);
	return found;
end
$$ language plpgsql;

create or replace function squidtalk.apply_acl( _domain text, _bucket text, _user text, _capability text ) returns boolean as $$
declare
	act boolean;
begin
	-- user must be a member of the domain for an acl check
	-- no anonymous users
	select active into act from squidtalk.users 
		where domain = _domain and email = _user;
	if not found or not act then
		return false;
	end if;
	-- conceptually this is what we want the behavior to be
	-- but I have no idea if this works in practice!
	select _user << permissions->(_capability) into act from squidtalk.acls
		where domain = _domain and bucket = _bucket and active;
	if not found or not act then
		return false;
	end if;
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
	end if;
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
	end if;
	update squidtalk.acls set permissions = _permissions
		where domain = _domain and bucket = _bucket and active;
	return found;	
end
$$ language plpgsql;


-- This table squidtalk.contains the list of domains
-- and keeps track of the admin for each domain
drop table if exists squidtalk.domains;
create table squidtalk.domains (
	name text,
	owner text,
	created timestamp,
	active boolean
);

create or replace function squidtalk.create_domain( _domain text, _user text ) returns boolean as $$
declare 
	domain text;
begin
	select name into domain from squidtalk.domains where name = _domain and active;
	if found then
		return false;
	end if;
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
	end if;
	-- NB: This disables all of the buckets and data associated with
	-- the domain.  The data is retained but is inaccessible!
	update squidtalk.domains set active = false where name = _domain;
	update squidtalk.buckets set active = false where domain = _domain;
	update squidtalk.value set active = false where domain = _domain;
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
	end if;
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
	end if;
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
	return query select name from squidtalk.domains where owner = _user and active;
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
drop table if exists squidtalk.buckets;
create table squidtalk.buckets (
	domain text,
	name text,
	owner text,
	created timestamp,
	active boolean	
);

create or replace function squidtalk.create_bucket( _domain text, _bucket text, _user text ) returns boolean as $$
declare
	act boolean;
begin
	-- verify user has create power on the domain level
	select squidtalk.apply_acl(_domain,_domain,_user,'create') into act;
	if not act then
		return false;
	end if;
	-- verify that the bucket doesn't already exist in this domain
	select name from squidtalk.buckets
		where domain = _domain and name = _bucket and active;
	if found then
		return false;
	end if;
	insert into squidtalk.buckets (domain, name, owner, created, active)
		values ( _domain, _bucket, _user, now(), true );
	-- create the default acl where the owner can do anything
	insert into squidtalk.acls ( domain, bucket, permissions, created, active)
		values ( _domain, _bucket, 
			('{ "create": ["' || _user || '"],' ||
			'"read": ["' || _user || '"],' ||
			'"update": ["' || _user || '"],' ||
			'"delete": ["' || _user || '"] }')::json ,
			now(), true );
	return true;
end	
$$ language plpgsql;

create or replace function squidtalk.disable_bucket( _domain text, _bucket text, _user text ) returns boolean as $$
declare
	act boolean;
begin
	-- user must have update capability on the top level domain, not bucket!!!
	-- if _bucket is domain then it doesn't allow you to wack the domain
	select squidtalk.apply_acl(_domain,_domain,_user, "update") into act;
	if not act or domain = _bucket then
		return false;
	end if;
	-- NB: this disables all data associated with the bucket as well!
	-- the data is still there, it just can't be accessed
	update squidtalk.buckets set active = false
		where domain = _domain and name = _bucket;
	update squidtalk.value set active = false
		where domain = _domain and bucket = _bucket;
	update squidtalk.acls set active = false
		where domain = _domain and bucket = _bucket;
	return found;
end
$$ language plpgsql;

create or replace function squidtalk.delete_bucket( _domain text, _bucket text, _user text ) returns boolean as $$
declare
	act boolean;
begin
	-- user must have delete capability on the top level domain, not bucket!!!
	select squidtalk.apply_acl(_domain,_domain,_user, "delete") into act;
	if not act then
		return false;
	end if;
	-- NB: this deletes all buckets of the same name on the domain
	-- and all of the data contained therein.
	delete from squidtalk.acls where domain = _domain and bucket = _bucket;
	delete from squidtalk.buckets where domain = _domain and name = _bucket;
	delete from squidtalk.value where domain = _domain and bucket = _bucket;
	return true;
end
$$ language plpgsql;


-- purges all of the inactive values for a given bucket, requires the user has delete permissions on the bucket
create or replace function squidtalk.purge_bucket( _domain text, _bucket text, _user text) returns boolean as $$
declare 
	act boolean;
begin
	select squidtalk.apply_acl(_domain,_bucket,_user, "delete") into act;
	if not act then
		return false;
	end if;
	delete from squildtalk.value where domain = _domain and bucket = _bucket and not active;
	return found;
end
$$ language plpgsql;


-- updates the acl assocaited with the bucket
create or replace function squidtalk.update_bucket( _domain text, _bucket text, _user text, _permissions text ) returns boolean as $$
declare
	act boolean;	
begin
	select squidtalk.apply_acl(_domain,_domain,_user, "update") into act;
	if not act then
		return false;
	end if;
	update squidtalk.acls set permissions = _permissions where domain = _domain and bucket = _bucket;
	return found;
end
$$ language plpgsql;

create or replace function squidtalk.list_buckets( _domain text, _user text ) returns setof text as $$
declare
	act boolean;
begin
	select squidtalk.apply_acl(_domain,_domain,_user, "read") into act;
	if not act then
		return;
	end if;
	return query select name from squidtalk.buckets where domain = _domain;
end
$$ language plpgsql;

-- This table squidtalk.contains the key/value pairs for each bucket
-- values are stored in time order and marked active false
-- when they are superceeded
drop table if exists squidtalk.value;
create table squidtalk.value (
	domain text,
	bucket text,
	name text,
	value json,
	created timestamp,
	active boolean
);

-- creates a new value if and only if the user has permissions and it doesn't already exist
-- this uses per bucket acls
create or replace function squidtalk.create_value( _domain text, _bucket text, _user text, _name text, _value json ) returns boolean as $$
declare
	act boolean;
begin	
	select squidtalk.apply_acl(_domain,_bucket,_user,"create") into act;
	if not act then
		return false;
	end if;
	select name from squidtalk.value where domain = _domain and bucket = _bucket and name = _name and active;
	if found then
		return false;
	end if;
	insert into squidtalk.value ( domain, bucket, name, value, created, active ) values ( _domain, _bucket, _user, _name, _value, now(), true);
	return found;
end
$$ language plpgsql;


-- update value does not replace the existing value but deactiveates it and creates a new value.
-- this allows for a record of changes to a given value over time.  This also allows an app to create
-- a value and only grant update capability to an untrusted interface with rollback and audits
create or replace function squidtalk.update_value( _domain text, _bucket text, _user text, _name text, _value json ) returns boolean as $$
declare
	act boolean;
begin
	select squidtalk.apply_acl(_domain,_bucket,_user,"update") into act;
	if not act then
		return false;
	end if;
	update squidtalk.value set active = false  where domain = _domain and bucket = _bucket and name = _name and active;
	insert into squidtalk.value ( domain, bucket, name, value, created, active ) values ( _domain, _bucket, _user, _name, _value, now(), true);
	return found;
end
$$ language plpgsql;

-- disables the current value, this leaves no active value so you can create it again but it can also be futher updated.
create or replace function squidtalk.disable_value(_domain text, _bucket text, _user text, _name text ) returns boolean as $$ 
declare
	act boolean;
begin
	select squidtalk.apply_acl(_domain,_bucket,_user,"update") into act;
	if not act then
		return false;
	end if;
	update squidtalk.value set active = false where domain = _domain and bucket = _bucket and name = _name and active;
	return found;
end
$$ language plpgsql;

-- permanently deletes the value and all of it's history, it cannot be recovered once it is deleted
create or replace function squidtalk.delete_value( _domain text, _bucket text, _user text, _name text ) returns boolean as $$
declare
	act boolean;
begin
	select squidtalk.apply_acl(_domain,_bucket,_user,"delete") into act;
	if not act then
		return false;
	end if;
	delete from squidtalk.value where domain = _domain and bucket = _bucket and name = _name;
	return found;
end
$$ language plpgsql;

-- purges all of the disabled values for a given key, leaving only the current active data
create or replace function squidtalk.purge_value( _domain text, _bucket text, _user text, _name text ) returns boolean as $$
declare
	act boolean;
begin
	select squidtalk.apply_acl(_domain,_bucket,_user,"delete") into act;
	if not act then
		return false;
	end if;
	delete from squidtalk.value where domain = _domain and bucket = _bucket and name = _name and not active;
	return found;
end
$$ language plpgsql;

-- gets the value associated with the given key 
create or replace function squidtalk.read_value( _domain text, _bucket text, _user text, _name text ) returns setof json as $$
declare
	act boolean;
begin
	select squidtalk.apply_acl(_domain,_bucket,_user,"read") into act;
	if not act then
		return;
	end if;
	return query select value from squidtalk.value where domain = _domain and bucket = _bucket and name = _name and active;
end
$$ language plpgsql;

-- gets a list of keys for a given bucket
create or replace function squidtalk.list_value(_domain text, _bucket text, _user text) returns setof text as $$
declare
	act boolean;
begin
	select squidtalk.apply_acl(_domain,_bucket,_user,"read") into act;
	if not act then
		return;
	end if;
	return query select name from squidtalk.value where domain = _domain  and bucket = _bucket and active;
end
$$ language plpgsql;

